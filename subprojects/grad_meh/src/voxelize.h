#pragma once

#include <cstdint>
#include <vector>

// A blocky stand-in for a detailed mesh: the occupied cells of a regular grid,
// with their outer faces merged into as few quads as possible.
struct VoxelMesh
{
    std::vector<float> vertices;
    std::vector<uint32_t> indices;
    // Edge length of one voxel in metres, 0 when nothing was built.
    float voxelSize = 0.0f;
};

// Builds the proxy for one triangulated mesh. Vertices are xyz triplets and
// indices are triangles; the result uses the same coordinate space.
//
// This is deliberately free of any Arma/rvff types so it can be tested on its
// own. The approach follows AdriansArmaDeWrp's Voxelizer: mark the voxels hit
// by every vertex and by a dense sampling of every triangle, drop the faces
// buried between two marked voxels, then greedy-merge what is left.
VoxelMesh buildVoxelMesh(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                         float targetVoxelSize);
