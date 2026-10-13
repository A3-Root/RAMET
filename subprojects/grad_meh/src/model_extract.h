#pragma once

#include "objects3d.h"

#include <cstddef>
#include <string>

#include <rust/cxx.h>
#include <rust-lib/lib.h>

struct ExtractOptions
{
    // Edge length passed to the voxeliser; only used when buildVoxels is set.
    float voxelTarget = VOXEL_TARGET_SIZE;
    // Largest visual mesh to keep, in triangles. 0 keeps the mesh as read.
    size_t meshBudget = 0;
    // Build the voxel proxy here. The terrain export leaves this off and
    // voxelises every model at once afterwards (buildModel3DVoxels).
    bool buildVoxels = false;
};

struct ExtractResult
{
    bool hasVisualLod = false;
    bool hasGeometryLod = false;
    bool hasMemoryLod = false;
    // The visual LOD was missing or triangulated to nothing, so the collision
    // hull was used for the mesh instead.
    bool meshFromGeometry = false;
    bool meshDecimated = false;
    float meshCellSize = 0.0f;
    // The Geometry LOD's "map" named property, original case. Present says
    // whether the property existed at all, which is not the same as an empty value.
    bool hasMapType = false;
    std::string rawMapType;
    // Valid only when hasGeometryLod. The 2D exporter draws from this.
    arma_file_formats::cxx::LodCxx geometryLod = {};
};

// Reads one already-open ODOL into a Model3D: visual bounds, the most detailed
// visual LOD as the mesh (falling back to the Geometry LOD), the "map" named
// property, and optionally a triangle budget and a voxel proxy.
//
// Only reads a LOD kind the resolution table actually lists: the reader's
// read_lod ends in a Rust panic when the requested kind is absent, which cannot
// be caught on the C++ side.
ExtractResult extractModel(Model3D& model, arma_file_formats::cxx::OdolLazyReaderCxx& reader,
                           const ExtractOptions& options = {});
