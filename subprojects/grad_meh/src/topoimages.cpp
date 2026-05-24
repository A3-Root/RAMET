// Topo image generation has been moved to tools/render_topo.py (Docker post-processing).
// grad_meh exports dem.asc.gz; the Docker step renders all topo variants from it.

#include "topoimages.h"

void writeTopoImages(arma_file_formats::cxx::OprwCxx& /*wrp*/, fs::path& /*basePathTopo*/) {}

void writeBakedTopoImages(arma_file_formats::cxx::OprwCxx& /*wrp*/, fs::path& /*basePathBakedTopo*/) {}

void writeTopoImageSet(arma_file_formats::cxx::OprwCxx& /*wrp*/, fs::path& /*basePathTopo*/, fs::path& /*basePathTopoDark*/) {}

void writeBakedTopoImageSet(arma_file_formats::cxx::OprwCxx& /*wrp*/, fs::path& /*basePathBakedTopo*/, fs::path& /*basePathBakedTopoDark*/) {}
