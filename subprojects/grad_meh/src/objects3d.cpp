#include "objects3d.h"

#include "voxelize.h"

#include <algorithm>
#include <atomic>
#include <fstream>
#include <thread>
#include <utility>

#include <nlohmann/json.hpp>
#include <plog/Log.h>

namespace fs = std::filesystem;
namespace nl = nlohmann;

void setModel3DBounds(Model3D& model, const arma_file_formats::cxx::ODOLCxx& odol)
{
    const auto& info = odol.model_info;
    model.bboxMin = {info.bbox_min_visual.x, info.bbox_min_visual.y, info.bbox_min_visual.z};
    model.bboxMax = {info.bbox_max_visual.x, info.bbox_max_visual.y, info.bbox_max_visual.z};
}

namespace {

// Bytes one face occupies in the LOD's face block: a 4-byte type field followed
// by one uint32 per corner. Sections address faces by byte offset into that
// block, not by face number, so walking the faces in order is the only way to
// map a section back to the faces it owns. Verified against every section of a
// character (6801 triangles, 108816 bytes), a tree (6 quads, 120 bytes) and a
// building with both (200 triangles + 104 quads, 5280 bytes).
size_t faceBytes(const arma_file_formats::cxx::LodFaceCxx& face)
{
    return 4 + face.vertex_indices.size() * 4;
}

// Byte ranges of the sections that only hold proxy placeholders.
//
// A proxy (a head, a weapon, a crew position, a wheel) is stored as a single 2 m
// placeholder triangle that the engine swaps for another model at runtime. The
// LOD groups them all into their own section, which every proxy points at, and
// that section carries no texture or material. Drawn as-is the placeholders are
// loose triangles sticking out of soldiers and vehicles, and they inflate the
// model's bounding box past the shape players see — an A3 character measures
// 4.6 m across with its 17 proxies in, against 1.6 m without them, which also
// threw off how far the planner lifted it off the ground.
std::vector<std::pair<uint32_t, uint32_t>> proxyFaceRanges(
    const arma_file_formats::cxx::LodCxx& lod)
{
    std::vector<std::pair<uint32_t, uint32_t>> out;
    const auto sectionCount = static_cast<int32_t>(lod.sections.size());
    for (const auto& proxy : lod.proxies) {
        if (proxy.section_index < 0 || proxy.section_index >= sectionCount) {
            continue;
        }
        const auto& section = lod.sections[static_cast<size_t>(proxy.section_index)];
        // Only a section that textures nothing is a pure placeholder section; a
        // proxy pointing into a real one must not take the geometry with it.
        if (section.common_texture_index >= 0 || section.material_index >= 0) {
            continue;
        }
        const std::pair<uint32_t, uint32_t> range{section.face_lower_index,
                                                  section.face_upper_index};
        if (std::find(out.begin(), out.end(), range) == out.end()) {
            out.push_back(range);
        }
    }
    return out;
}

bool inRanges(const std::vector<std::pair<uint32_t, uint32_t>>& ranges, size_t offset)
{
    for (const auto& range : ranges) {
        if (offset >= range.first && offset < range.second) {
            return true;
        }
    }
    return false;
}

} // namespace

void setModel3DMesh(Model3D& model, const arma_file_formats::cxx::LodCxx& geometryLod)
{
    model.vertices.clear();
    model.indices.clear();

    const auto vertexCount = static_cast<uint32_t>(geometryLod.vertices.size());
    const auto proxyRanges = proxyFaceRanges(geometryLod);
    size_t faceOffset = 0;

    // Keep only the vertices the surviving faces actually use, so the vertex
    // array, the index array and the bounding box all describe one shape.
    std::vector<uint32_t> remap(vertexCount, UINT32_MAX);
    const auto emit = [&](uint32_t source) {
        if (remap[source] == UINT32_MAX) {
            remap[source] = static_cast<uint32_t>(model.vertices.size() / 3);
            const auto& v = geometryLod.vertices[source];
            model.vertices.push_back(v.x);
            model.vertices.push_back(v.y);
            model.vertices.push_back(v.z);
        }
        model.indices.push_back(remap[source]);
    };

    for (const auto& face : geometryLod.faces) {
        const auto& idx = face.vertex_indices;
        const auto offset = faceOffset;
        faceOffset += faceBytes(face);
        if (idx.size() < 3) {
            continue;
        }
        if (inRanges(proxyRanges, offset)) {
            continue;
        }
        // Faces are convex polygons (triangles or quads); fan-triangulate.
        for (size_t i = 1; i + 1 < idx.size(); i++) {
            if (idx[0] >= vertexCount || idx[i] >= vertexCount || idx[i + 1] >= vertexCount) {
                continue;
            }
            emit(idx[0]);
            emit(idx[i]);
            emit(idx[i + 1]);
        }
    }
    if (model.indices.empty()) {
        model.vertices.clear();
        return;
    }
    setModel3DBoundsFromMesh(model);
}

void setModel3DBoundsFromMesh(Model3D& model)
{
    if (model.vertices.size() < 3) {
        return;
    }
    std::array<float, 3> lo = {model.vertices[0], model.vertices[1], model.vertices[2]};
    std::array<float, 3> hi = lo;
    for (size_t i = 0; i + 2 < model.vertices.size(); i += 3) {
        for (size_t a = 0; a < 3; a++) {
            lo[a] = std::min(lo[a], model.vertices[i + a]);
            hi[a] = std::max(hi[a], model.vertices[i + a]);
        }
    }
    model.bboxMin = lo;
    model.bboxMax = hi;
}

void setModel3DVoxels(Model3D& model, float targetVoxelSize)
{
    auto voxels = buildVoxelMesh(model.vertices, model.indices, targetVoxelSize);
    model.voxelVertices = std::move(voxels.vertices);
    model.voxelIndices = std::move(voxels.indices);
    model.voxelSize = voxels.voxelSize;
}

void buildModel3DVoxels(std::vector<Model3D>& models, float targetVoxelSize)
{
    if (models.empty()) {
        return;
    }

    unsigned int workers = std::thread::hardware_concurrency();
    if (workers == 0) {
        workers = 1;
    }
    workers = std::min<unsigned int>(workers, static_cast<unsigned int>(models.size()));

    std::atomic<size_t> next{0};
    const auto work = [&]() {
        for (;;) {
            const size_t i = next.fetch_add(1);
            if (i >= models.size()) {
                return;
            }
            setModel3DVoxels(models[i], targetVoxelSize);
        }
    };

    std::vector<std::thread> threads;
    threads.reserve(workers - 1);
    for (unsigned int i = 1; i < workers; i++) {
        threads.emplace_back(work);
    }
    work();
    for (auto& thread : threads) {
        thread.join();
    }

    size_t built = 0;
    for (const auto& model : models) {
        if (!model.voxelIndices.empty()) {
            built++;
        }
    }
    PLOG_INFO << "3D data: voxel proxies built for " << built << " of " << models.size() << " models";
}

void write3dData(const arma_file_formats::cxx::OprwCxx& wrp, const std::vector<Model3D>& models,
                 const fs::path& basePath3d)
{
    if (!fs::exists(basePath3d)) {
        fs::create_directories(basePath3d);
    }

    std::ofstream modelsBin(basePath3d / "models.bin", std::ios::binary);
    nl::json modelsJson = nl::json::array();
    uint64_t offset = 0;
    for (const auto& model : models) {
        nl::json entry;
        entry["path"] = model.path;
        entry["mapType"] = model.mapType;
        entry["bboxMin"] = model.bboxMin;
        entry["bboxMax"] = model.bboxMax;
        entry["vertexOffset"] = offset;
        entry["vertexCount"] = model.vertices.size() / 3;
        modelsBin.write(reinterpret_cast<const char*>(model.vertices.data()),
                        static_cast<std::streamsize>(model.vertices.size() * sizeof(float)));
        offset += model.vertices.size() * sizeof(float);
        entry["indexOffset"] = offset;
        entry["indexCount"] = model.indices.size();
        modelsBin.write(reinterpret_cast<const char*>(model.indices.data()),
                        static_cast<std::streamsize>(model.indices.size() * sizeof(uint32_t)));
        offset += model.indices.size() * sizeof(uint32_t);
        entry["voxelSize"] = model.voxelSize;
        entry["voxelVertexOffset"] = offset;
        entry["voxelVertexCount"] = model.voxelVertices.size() / 3;
        modelsBin.write(reinterpret_cast<const char*>(model.voxelVertices.data()),
                        static_cast<std::streamsize>(model.voxelVertices.size() * sizeof(float)));
        offset += model.voxelVertices.size() * sizeof(float);
        entry["voxelIndexOffset"] = offset;
        entry["voxelIndexCount"] = model.voxelIndices.size();
        modelsBin.write(reinterpret_cast<const char*>(model.voxelIndices.data()),
                        static_cast<std::streamsize>(model.voxelIndices.size() * sizeof(uint32_t)));
        offset += model.voxelIndices.size() * sizeof(uint32_t);
        modelsJson.push_back(entry);
    }
    modelsBin.close();

    std::ofstream objectsBin(basePath3d / "objects.bin", std::ios::binary);
    uint64_t written = 0;
    for (const auto& object : wrp.objects) {
        if (object.model_index >= models.size()) {
            continue;
        }
        const auto& m = object.transform_matrx;
        const uint32_t modelIndex = object.model_index;
        const float transform[12] = {
            m._0.x, m._0.y, m._0.z,
            m._1.x, m._1.y, m._1.z,
            m._2.x, m._2.y, m._2.z,
            m._3.x, m._3.y, m._3.z,
        };
        objectsBin.write(reinterpret_cast<const char*>(&modelIndex), sizeof(modelIndex));
        objectsBin.write(reinterpret_cast<const char*>(transform), sizeof(transform));
        written++;
    }
    objectsBin.close();

    nl::json meta;
    meta["schema"] = "ramet-3d-raw-2";
    meta["voxelTargetSize"] = VOXEL_TARGET_SIZE;
    meta["objectRecordBytes"] = 52;
    meta["objectCount"] = written;
    meta["models"] = modelsJson;
    std::ofstream metaOut(basePath3d / "models.json");
    metaOut << meta.dump();
    metaOut.close();

    PLOG_INFO << "3D data: " << models.size() << " models, " << written << " objects written to " << basePath3d.string();
}
