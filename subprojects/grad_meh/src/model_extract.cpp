#include "model_extract.h"

#include "decimate.h"

#include <cctype>

namespace {

// objects3d.cpp and this file are also compiled into the standalone model
// library tool, which does not link boost — so no to_lower_copy here.
std::string toLowerAscii(const std::string& value)
{
    std::string out = value;
    for (auto& c : out) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return out;
}

} // namespace

ExtractResult extractModel(Model3D& model, arma_file_formats::cxx::OdolLazyReaderCxx& reader,
                           const ExtractOptions& options)
{
    using namespace arma_file_formats::cxx;

    ExtractResult result;

    const auto odol = reader.get_odol();
    setModel3DBounds(model, odol);

    for (const auto& res : odol.resolutions) {
        if (res.res == ResolutionEnumCxx::Geometry) {
            result.hasGeometryLod = true;
        } else if (res.res == ResolutionEnumCxx::Memory) {
            result.hasMemoryLod = true;
        } else if (res.res == ResolutionEnumCxx::GraphicalLod) {
            result.hasVisualLod = true;
        }
    }

    // The 3D view wants the shape players actually see. read_lod returns the
    // first resolution of the requested kind, which for GraphicalLod is the
    // most detailed visual LOD. The Geometry LOD is only a collision hull —
    // usable as a fallback, but boxy.
    if (result.hasVisualLod) {
        const auto visualLod = reader.read_lod(ResolutionEnumCxx::GraphicalLod);
        setModel3DMesh(model, visualLod);
    }

    if (result.hasGeometryLod) {
        result.geometryLod = reader.read_lod(ResolutionEnumCxx::Geometry);
        if (model.indices.empty()) {
            setModel3DMesh(model, result.geometryLod);
            result.meshFromGeometry = true;
        }

        for (const auto& prop : result.geometryLod.named_properties) {
            if (static_cast<std::string>(prop.property) == "map") {
                result.hasMapType = true;
                result.rawMapType = static_cast<std::string>(prop.value);
                model.mapType = toLowerAscii(result.rawMapType);
                break;
            }
        }
    }

    if (options.meshBudget > 0 && model.indices.size() / 3 > options.meshBudget) {
        auto reduced = decimateMesh(model.vertices, model.indices, options.meshBudget);
        if (reduced.cellSize > 0.0f && !reduced.indices.empty()) {
            model.vertices = std::move(reduced.vertices);
            model.indices = std::move(reduced.indices);
            result.meshDecimated = true;
            result.meshCellSize = reduced.cellSize;
        }
    }

    if (options.buildVoxels) {
        setModel3DVoxels(model, options.voxelTarget);
    }

    return result;
}
