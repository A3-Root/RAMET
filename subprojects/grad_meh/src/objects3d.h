#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

#include <rust/cxx.h>
#include <rust-lib/lib.h>

// Compact per-model data used by the 3D planner view.
struct Model3D
{
    std::string path;
    // Value of the model's "map" named property (house, tree, bush, rock, ...), lower case.
    std::string mapType;
    // Visual bounding box in model space (x right, y up, z forward).
    std::array<float, 3> bboxMin = {0.0f, 0.0f, 0.0f};
    std::array<float, 3> bboxMax = {0.0f, 0.0f, 0.0f};
    // Visual LOD mesh in model space: xyz triplets and triangle indices.
    std::vector<float> vertices;
    std::vector<uint32_t> indices;
    // Blocky proxy built from the mesh above, in the same model space.
    std::vector<float> voxelVertices;
    std::vector<uint32_t> voxelIndices;
    // Edge length of one voxel in metres, 0 when no proxy was built.
    float voxelSize = 0.0f;
};

// Target edge length of one voxel, in metres.
constexpr float VOXEL_TARGET_SIZE = 0.5f;

// Copies the visual bounding box of an ODOL model.
void setModel3DBounds(Model3D& model, const arma_file_formats::cxx::ODOLCxx& odol);

// Copies and triangulates the faces of a LOD.
void setModel3DMesh(Model3D& model, const arma_file_formats::cxx::LodCxx& lod);

// Builds the blocky proxy for one model from its triangulated mesh.
void setModel3DVoxels(Model3D& model, float targetVoxelSize = VOXEL_TARGET_SIZE);

// Builds the proxies of every model, spread over the available cores.
void buildModel3DVoxels(std::vector<Model3D>& models, float targetVoxelSize = VOXEL_TARGET_SIZE);

// Writes models.json, models.bin and objects.bin into basePath3d.
//   models.bin:  per model, float32 vertices followed by uint32 indices for the visual mesh,
//                then the same pair for the voxel proxy (all offsets in models.json)
//   objects.bin: per object, uint32 model index + float32[12] transform (_0,_1,_2 axes, _3 position)
void write3dData(const arma_file_formats::cxx::OprwCxx& wrp, const std::vector<Model3D>& models,
                 const std::filesystem::path& basePath3d);
