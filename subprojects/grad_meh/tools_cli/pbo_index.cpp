#include "pbo_index.h"

#include <algorithm>
#include <cctype>
#include <filesystem>

#include <rust/cxx.h>
#include <rust-lib/lib.h>

namespace fs = std::filesystem;

namespace {

std::string toLowerAscii(std::string value)
{
    for (auto& c : value) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return value;
}

std::string normalisePath(std::string value)
{
    std::replace(value.begin(), value.end(), '/', '\\');
    value = toLowerAscii(std::move(value));
    while (!value.empty() && value.front() == '\\') {
        value.erase(value.begin());
    }
    return value;
}

bool endsWithP3d(const std::string& value)
{
    static const std::string suffix = ".p3d";
    if (value.size() <= suffix.size()) {
        return false;
    }
    return toLowerAscii(value.substr(value.size() - suffix.size())) == suffix;
}

} // namespace

std::vector<PboModelEntry> indexModels(const std::vector<std::string>& modRoots,
                                       std::vector<std::string>& badArchives)
{
    std::vector<PboModelEntry> models;

    for (const auto& root : modRoots) {
        std::error_code ec;
        if (!fs::exists(root, ec) || ec) {
            badArchives.push_back(root + " (not found)");
            continue;
        }

        fs::recursive_directory_iterator it(root, fs::directory_options::skip_permission_denied, ec);
        if (ec) {
            badArchives.push_back(root + " (" + ec.message() + ")");
            continue;
        }

        for (const auto& dirEntry : it) {
            if (!dirEntry.is_regular_file(ec) || ec) {
                continue;
            }
            const auto path = dirEntry.path();
            if (toLowerAscii(path.extension().string()) != ".pbo") {
                continue;
            }

            try {
                auto reader = arma_file_formats::cxx::create_pbo_reader_path(path.string());
                // get_prefix already lower-cases and appends a trailing backslash.
                const auto prefix = static_cast<std::string>(reader->get_prefix());
                const auto pbo = reader->get_pbo();

                for (const auto& entry : pbo.entries) {
                    auto filename = static_cast<std::string>(entry.filename);
                    if (!endsWithP3d(filename)) {
                        continue;
                    }

                    PboModelEntry model;
                    // Keep the archive's own spelling for the lookup; the stored
                    // entry table is keyed by it.
                    model.entryPath = filename;
                    model.logicalPath = normalisePath(prefix + filename);
                    model.pboPath = path.string();
                    model.size = entry.size;
                    models.push_back(std::move(model));
                }
            } catch (const rust::Error& ex) {
                badArchives.push_back(path.string() + " (" + ex.what() + ")");
            } catch (const std::exception& ex) {
                badArchives.push_back(path.string() + " (" + ex.what() + ")");
            }
        }
    }

    return models;
}

bool readEntry(const std::string& pboPath, const std::string& entryPath, std::vector<uint8_t>& out)
{
    out.clear();
    auto reader = arma_file_formats::cxx::create_pbo_reader_path(pboPath);
    const auto data = reader->get_entry_data(entryPath);
    if (data.empty()) {
        return false;
    }
    out.assign(data.begin(), data.end());
    return true;
}
