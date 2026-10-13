#pragma once

#include <cstdint>
#include <vector>

// A coarser stand-in for a dense mesh, produced by welding vertices onto a grid.
struct DecimatedMesh
{
    std::vector<float> vertices;
    std::vector<uint32_t> indices;
    // Edge length of the clustering cell in metres, 0 when nothing was changed.
    float cellSize = 0.0f;
};

// Reduces a triangulated mesh to at most targetTriangles triangles.
//
// Arma's ODOL files do carry authored coarser LODs, but the reader we use can
// only reach the first resolution of a given kind, which for GraphicalLod is
// always the most detailed one. So the triangle budget is met here instead:
// vertices are snapped to a regular grid and welded, triangles that collapse
// onto a point or a line are dropped, and the cell is enlarged until the
// result fits. Deliberately free of any Arma/rvff types so it can be tested on
// its own, exactly like buildVoxelMesh.
//
// Returns the input unchanged (cellSize 0) when it already fits, when
// targetTriangles is not positive, or when no cell size could meet the budget.
DecimatedMesh decimateMesh(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                           size_t targetTriangles);
