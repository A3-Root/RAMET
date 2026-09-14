#include "objects3d.h"

#include <fstream>

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

void setModel3DMesh(Model3D& model, const arma_file_formats::cxx::LodCxx& geometryLod)
{
    model.vertices.clear();
    model.indices.clear();
    model.vertices.reserve(geometryLod.vertices.size() * 3);
    for (const auto& v : geometryLod.vertices) {
        model.vertices.push_back(v.x);
        model.vertices.push_back(v.y);
        model.vertices.push_back(v.z);
    }
    const auto vertexCount = static_cast<uint32_t>(geometryLod.vertices.size());
    for (const auto& face : geometryLod.faces) {
        const auto& idx = face.vertex_indices;
        if (idx.size() < 3) {
            continue;
        }
        // Faces are convex polygons (triangles or quads); fan-triangulate.
        for (size_t i = 1; i + 1 < idx.size(); i++) {
            if (idx[0] >= vertexCount || idx[i] >= vertexCount || idx[i + 1] >= vertexCount) {
                continue;
            }
            model.indices.push_back(idx[0]);
            model.indices.push_back(idx[i]);
            model.indices.push_back(idx[i + 1]);
        }
    }
    if (model.indices.empty()) {
        model.vertices.clear();
    }
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
    meta["schema"] = "ramet-3d-raw-1";
    meta["objectRecordBytes"] = 52;
    meta["objectCount"] = written;
    meta["models"] = modelsJson;
    std::ofstream metaOut(basePath3d / "models.json");
    metaOut << meta.dump();
    metaOut.close();

    PLOG_INFO << "3D data: " << models.size() << " models, " << written << " objects written to " << basePath3d.string();
}
