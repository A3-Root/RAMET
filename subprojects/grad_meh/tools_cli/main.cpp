// ramet_models — builds the planner's map-independent model library.
//
// The terrain exporter runs inside Arma as an Intercept plugin and gets its
// list of models from a world's WRP. Mission-placed content (vehicles, units,
// Zeus-placed buildings from any mod) is not in any WRP, so the planner has no
// geometry for it and falls back to bounding boxes.
//
// This tool reads the same ODOL p3d files straight out of the modpack's PBOs,
// with no Arma running, and writes one library the planner can serve for every
// map. Output is append-only so a crashed run resumes where it stopped.

#include "pbo_index.h"

#include "../src/model_extract.h"
#include "../src/objects3d.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <nlohmann/json.hpp>
#include <plog/Appenders/ColorConsoleAppender.h>
#include <plog/Formatters/TxtFormatter.h>
#include <plog/Init.h>
#include <plog/Log.h>

namespace fs = std::filesystem;
namespace nl = nlohmann;

namespace {

constexpr const char* LIBRARY_SCHEMA = "ramet-models-1";

// Paths holding gear rather than anything you would see on a map. The extent
// filter catches most of it; these are the cheap wins, applied before any
// bytes are read.
const std::vector<std::string> DEFAULT_EXCLUDES = {
    "\\weapons\\", "\\weapons_f\\", "\\magazines\\", "\\ammo\\",     "\\optics\\",
    "\\headgear\\", "\\vests\\",    "\\backpacks\\", "\\uniforms\\", "\\proxies\\",
};

struct Options
{
    std::vector<std::string> modRoots;
    std::vector<std::string> excludes;
    std::string manifestPath;
    std::string libraryDir;
    size_t limit = 0;
    // Upper bound on the voxel edge; large buildings land here.
    float voxelSize = VOXEL_TARGET_SIZE;
    // Lower bound, so a tiny prop does not explode into thousands of cells.
    float minVoxelSize = 0.08f;
    // Cells wanted along a model's longest axis. The terrain exporter can use
    // one fixed 0.5 m edge because terrain models are buildings; this library
    // also holds crates and rifle-sized props, and at 0.5 m a 1.5 m crate
    // voxelises to two or three quads — a blob, not a shape.
    float voxelDivisions = 32.0f;
    size_t meshBudget = 20000;
    float minExtent = 1.0f;
    bool noDefaultExcludes = false;
};

// Voxel edge for one model: fine enough to keep its silhouette, clamped so the
// cell count stays sane at both ends.
float voxelTargetFor(float extent, const Options& options)
{
    if (!(extent > 0.0f)) {
        return options.voxelSize;
    }
    const float wanted = extent / options.voxelDivisions;
    return std::max(options.minVoxelSize, std::min(options.voxelSize, wanted));
}

void printUsage()
{
    std::cout << "ramet_models — build the planner's model library from modpack PBOs\n\n"
              << "  ramet_models scan  --mod-root <dir> [--mod-root <dir>...] --out <manifest.jsonl>\n"
              << "                     [--exclude <substring>...] [--no-default-excludes]\n"
              << "  ramet_models build --manifest <manifest.jsonl> --library <dir>\n"
              << "                     [--limit <n>] [--mesh-budget <tris>] [--min-extent <m>]\n"
              << "                     [--voxel-size <m>] [--min-voxel-size <m>] [--voxel-divisions <n>]\n\n"
              << "build appends to <dir>/library.bin, library.jsonl and library.attempts.jsonl,\n"
              << "and is safe to re-run: finished and already-failed models are skipped.\n";
}

std::string toLowerAscii(std::string value)
{
    for (auto& c : value) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return value;
}

bool isExcluded(const std::string& logicalPath, const std::vector<std::string>& excludes)
{
    // Leading separator so a top-level directory matches "\weapons\" too.
    const std::string probe = "\\" + logicalPath;
    for (const auto& needle : excludes) {
        if (probe.find(needle) != std::string::npos) {
            return true;
        }
    }
    return false;
}

bool hasMlodMagic(const std::vector<uint8_t>& data)
{
    return data.size() >= 4 && data[0] == 'M' && data[1] == 'L' && data[2] == 'O' && data[3] == 'D';
}

float maxExtent(const Model3D& model)
{
    float extent = 0.0f;
    for (int axis = 0; axis < 3; axis++) {
        extent = std::max(extent, model.bboxMax[axis] - model.bboxMin[axis]);
    }
    return extent;
}

// --- append-only output -----------------------------------------------------

class LibraryWriter
{
public:
    explicit LibraryWriter(const fs::path& dir)
        : m_binPath(dir / "library.bin")
        , m_indexPath(dir / "library.jsonl")
        , m_attemptsPath(dir / "library.attempts.jsonl")
    {
        fs::create_directories(dir);
        m_bin.open(m_binPath, std::ios::binary | std::ios::app);
        m_index.open(m_indexPath, std::ios::app);
        m_attempts.open(m_attemptsPath, std::ios::app);
        std::error_code ec;
        const auto existing = fs::file_size(m_binPath, ec);
        m_offset = ec ? 0 : existing;
    }

    bool ok() const { return m_bin.good() && m_index.good() && m_attempts.good(); }

    // Written before the model is touched, so a hard crash leaves a start with
    // no terminal record and the path can be quarantined on the next run.
    void beginAttempt(const std::string& path)
    {
        nl::json line;
        line["path"] = path;
        line["state"] = "start";
        m_attempts << line.dump() << '\n';
        m_attempts.flush();
    }

    void finishAttempt(const std::string& path, const std::string& state, const std::string& detail = {})
    {
        nl::json line;
        line["path"] = path;
        line["state"] = state;
        if (!detail.empty()) {
            line["detail"] = detail;
        }
        m_attempts << line.dump() << '\n';
        m_attempts.flush();
    }

    void write(const Model3D& model, const PboModelEntry& entry, const ExtractResult& extracted)
    {
        nl::json record;
        record["path"] = model.path;
        record["pbo"] = entry.pboPath;
        record["mapType"] = model.mapType;
        record["bboxMin"] = model.bboxMin;
        record["bboxMax"] = model.bboxMax;
        record["voxelSize"] = model.voxelSize;
        record["meshFromGeometry"] = extracted.meshFromGeometry;
        record["meshDecimated"] = extracted.meshDecimated;
        record["meshCellSize"] = extracted.meshCellSize;

        record["voxelVertexOffset"] = m_offset;
        record["voxelVertexCount"] = model.voxelVertices.size() / 3;
        append(model.voxelVertices);
        record["voxelIndexOffset"] = m_offset;
        record["voxelIndexCount"] = model.voxelIndices.size();
        append(model.voxelIndices);

        record["vertexOffset"] = m_offset;
        record["vertexCount"] = model.vertices.size() / 3;
        append(model.vertices);
        record["indexOffset"] = m_offset;
        record["indexCount"] = model.indices.size();
        append(model.indices);

        m_index << record.dump() << '\n';
        // Flushed per model: the driver restarts this process after a panic and
        // must see everything that completed.
        m_bin.flush();
        m_index.flush();
    }

private:
    template <typename T>
    void append(const std::vector<T>& values)
    {
        if (values.empty()) {
            return;
        }
        const auto bytes = values.size() * sizeof(T);
        m_bin.write(reinterpret_cast<const char*>(values.data()), static_cast<std::streamsize>(bytes));
        m_offset += bytes;
    }

    fs::path m_binPath;
    fs::path m_indexPath;
    fs::path m_attemptsPath;
    std::ofstream m_bin;
    std::ofstream m_index;
    std::ofstream m_attempts;
    uint64_t m_offset = 0;
};

std::vector<nl::json> readJsonLines(const fs::path& path)
{
    std::vector<nl::json> lines;
    std::ifstream in(path);
    if (!in.is_open()) {
        return lines;
    }
    std::string text;
    while (std::getline(in, text)) {
        if (text.empty()) {
            continue;
        }
        try {
            lines.push_back(nl::json::parse(text));
        } catch (const nl::json::exception&) {
            // A torn final line is the expected shape of a crash; drop it.
        }
    }
    return lines;
}

// --- commands --------------------------------------------------------------

int runScan(const Options& options)
{
    if (options.modRoots.empty() || options.manifestPath.empty()) {
        printUsage();
        return 2;
    }

    auto excludes = options.excludes;
    if (!options.noDefaultExcludes) {
        excludes.insert(excludes.end(), DEFAULT_EXCLUDES.begin(), DEFAULT_EXCLUDES.end());
    }

    std::vector<std::string> badArchives;
    std::cout << "scanning " << options.modRoots.size() << " mod root(s) for PBOs...\n";
    auto models = indexModels(options.modRoots, badArchives);
    std::cout << "found " << models.size() << " p3d entries\n";

    // The same model ships in several PBOs often enough to matter; keep the first.
    std::unordered_set<std::string> seen;
    size_t excluded = 0;
    size_t duplicates = 0;
    size_t kept = 0;

    std::ofstream out(options.manifestPath);
    if (!out.is_open()) {
        std::cerr << "cannot write manifest: " << options.manifestPath << "\n";
        return 1;
    }

    for (const auto& model : models) {
        if (isExcluded(model.logicalPath, excludes)) {
            excluded++;
            continue;
        }
        if (!seen.insert(model.logicalPath).second) {
            duplicates++;
            continue;
        }
        nl::json line;
        line["path"] = model.logicalPath;
        line["entry"] = model.entryPath;
        line["pbo"] = model.pboPath;
        line["size"] = model.size;
        out << line.dump() << '\n';
        kept++;
    }
    out.close();

    std::cout << "manifest: " << kept << " models (" << excluded << " excluded by path, " << duplicates
              << " duplicates)\n";
    for (const auto& bad : badArchives) {
        std::cout << "  unreadable: " << bad << "\n";
    }
    return 0;
}

int runBuild(const Options& options)
{
    if (options.manifestPath.empty() || options.libraryDir.empty()) {
        printUsage();
        return 2;
    }

    const auto manifest = readJsonLines(options.manifestPath);
    if (manifest.empty()) {
        std::cerr << "manifest is empty or unreadable: " << options.manifestPath << "\n";
        return 1;
    }

    const fs::path libraryDir = options.libraryDir;

    // Replay the journal: a path with a terminal state is finished, a path with
    // only a start crashed the previous run and must not be retried.
    std::unordered_map<std::string, std::string> states;
    for (const auto& line : readJsonLines(libraryDir / "library.attempts.jsonl")) {
        const auto path = line.value("path", std::string{});
        const auto state = line.value("state", std::string{});
        if (path.empty() || state.empty()) {
            continue;
        }
        if (state == "start") {
            if (states.find(path) == states.end()) {
                states[path] = "start";
            }
        } else {
            states[path] = state;
        }
    }

    LibraryWriter writer(libraryDir);
    if (!writer.ok()) {
        std::cerr << "cannot open library output in " << libraryDir.string() << "\n";
        return 1;
    }

    size_t quarantined = 0;
    for (auto& entry : states) {
        if (entry.second == "start") {
            writer.finishAttempt(entry.first, "error", "aborted a previous run");
            entry.second = "error";
            quarantined++;
        }
    }
    if (quarantined > 0) {
        std::cout << "quarantined " << quarantined << " model(s) that crashed a previous run\n";
    }

    ExtractOptions extractOptions;
    extractOptions.meshBudget = options.meshBudget;
    // Voxels are built after extraction, once the model's extent is known.
    extractOptions.buildVoxels = false;

    size_t done = 0;
    size_t written = 0;
    size_t skipped = 0;
    size_t failed = 0;

    for (const auto& line : manifest) {
        if (options.limit > 0 && done >= options.limit) {
            std::cout << "reached --limit " << options.limit << ", stopping\n";
            break;
        }

        PboModelEntry entry;
        entry.logicalPath = line.value("path", std::string{});
        entry.entryPath = line.value("entry", std::string{});
        entry.pboPath = line.value("pbo", std::string{});
        if (entry.logicalPath.empty() || entry.pboPath.empty()) {
            continue;
        }
        if (states.find(entry.logicalPath) != states.end()) {
            continue;
        }

        done++;
        writer.beginAttempt(entry.logicalPath);

        try {
            std::vector<uint8_t> bytes;
            if (!readEntry(entry.pboPath, entry.entryPath, bytes)) {
                writer.finishAttempt(entry.logicalPath, "error", "entry missing or empty");
                failed++;
                continue;
            }
            if (hasMlodMagic(bytes)) {
                writer.finishAttempt(entry.logicalPath, "skipped", "MLOD");
                skipped++;
                continue;
            }

            // The &CxxVector<u8> overload takes a plain std::vector, so the
            // bytes do not have to be copied into a rust::Vec first.
            auto reader = arma_file_formats::cxx::create_odol_lazy_reader(bytes);

            Model3D model;
            model.path = entry.logicalPath;
            const auto extracted = extractModel(model, *reader, extractOptions);

            if (model.indices.empty()) {
                writer.finishAttempt(entry.logicalPath, "skipped", "no usable mesh");
                skipped++;
                continue;
            }
            const auto extent = maxExtent(model);
            if (extent < options.minExtent) {
                writer.finishAttempt(entry.logicalPath, "skipped", "smaller than --min-extent");
                skipped++;
                continue;
            }

            setModel3DVoxels(model, voxelTargetFor(extent, options));

            writer.write(model, entry, extracted);
            writer.finishAttempt(entry.logicalPath, "ok");
            written++;

            if (written % 250 == 0) {
                std::cout << "  " << written << " models written\n";
            }
        } catch (const rust::Error& ex) {
            writer.finishAttempt(entry.logicalPath, "error", ex.what());
            failed++;
        } catch (const std::exception& ex) {
            writer.finishAttempt(entry.logicalPath, "error", ex.what());
            failed++;
        }
    }

    std::cout << "build: " << written << " written, " << skipped << " skipped, " << failed << " failed\n";

    nl::json meta;
    meta["schema"] = LIBRARY_SCHEMA;
    meta["voxelMaxSize"] = options.voxelSize;
    meta["voxelMinSize"] = options.minVoxelSize;
    meta["voxelDivisions"] = options.voxelDivisions;
    meta["meshTriangleBudget"] = options.meshBudget;
    meta["minExtent"] = options.minExtent;
    std::ofstream metaOut(libraryDir / "library.meta.json");
    metaOut << meta.dump(2);
    metaOut.close();

    // Non-zero only when nothing could be done at all; individual failures are
    // recorded, not fatal, so the driver can keep going.
    return 0;
}

bool nextValue(int argc, char** argv, int& i, std::string& out)
{
    if (i + 1 >= argc) {
        return false;
    }
    out = argv[++i];
    return true;
}

} // namespace

int main(int argc, char** argv)
{
    static plog::ColorConsoleAppender<plog::TxtFormatter> consoleAppender;
    plog::init(plog::warning, &consoleAppender);

    if (argc < 2) {
        printUsage();
        return 2;
    }

    const std::string command = argv[1];
    if (command == "--help" || command == "-h" || command == "help") {
        printUsage();
        return 0;
    }

    Options options;

    for (int i = 2; i < argc; i++) {
        const std::string arg = argv[i];
        std::string value;
        if (arg == "--mod-root" && nextValue(argc, argv, i, value)) {
            options.modRoots.push_back(value);
        } else if (arg == "--exclude" && nextValue(argc, argv, i, value)) {
            options.excludes.push_back(toLowerAscii(value));
        } else if (arg == "--no-default-excludes") {
            options.noDefaultExcludes = true;
        } else if ((arg == "--out" || arg == "--manifest") && nextValue(argc, argv, i, value)) {
            // scan writes the manifest, build reads it.
            options.manifestPath = value;
        } else if (arg == "--library" && nextValue(argc, argv, i, value)) {
            options.libraryDir = value;
        } else if (arg == "--limit" && nextValue(argc, argv, i, value)) {
            options.limit = static_cast<size_t>(std::stoull(value));
        } else if (arg == "--voxel-size" && nextValue(argc, argv, i, value)) {
            options.voxelSize = std::stof(value);
        } else if (arg == "--min-voxel-size" && nextValue(argc, argv, i, value)) {
            options.minVoxelSize = std::stof(value);
        } else if (arg == "--voxel-divisions" && nextValue(argc, argv, i, value)) {
            options.voxelDivisions = std::stof(value);
        } else if (arg == "--mesh-budget" && nextValue(argc, argv, i, value)) {
            options.meshBudget = static_cast<size_t>(std::stoull(value));
        } else if (arg == "--min-extent" && nextValue(argc, argv, i, value)) {
            options.minExtent = std::stof(value);
        } else if (arg == "--help" || arg == "-h") {
            printUsage();
            return 0;
        } else {
            std::cerr << "unknown or incomplete option: " << arg << "\n";
            printUsage();
            return 2;
        }
    }

    try {
        if (command == "scan") {
            return runScan(options);
        }
        if (command == "build") {
            return runBuild(options);
        }
    } catch (const std::exception& ex) {
        std::cerr << "fatal: " << ex.what() << "\n";
        return 1;
    }

    std::cerr << "unknown command: " << command << "\n";
    printUsage();
    return 2;
}
