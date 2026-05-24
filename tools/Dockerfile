# RAMET post-processing image.
# Bundles every CLI orchestrate.py reaches for so the operator only needs Docker:
#   - tippecanoe (vector tile build)
#   - pmtiles CLI (mbtiles -> pmtiles convert)
#   - cwebp / pngquant / oxipng (raster optimization)
#   - Python 3.12 + lxml / pillow / pyyaml (slice_svg + orchestrate)
#
# Build:  docker build -t ramet-postprocess:latest -f tools/Dockerfile .
# Run:    docker run --rm -v <Arma3>:/work -e RAMET_ARMA_ROOT=/work \
#                    ramet-postprocess:latest --all
#
# The image's ENTRYPOINT is orchestrate.py — anything after the image name
# is passed straight through (e.g. --world altis, --skip-pmtiles).

FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Native CLIs available in Debian repos: tippecanoe, webp, pngquant, oxipng.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tar build-essential git \
        tippecanoe webp pngquant oxipng \
    && rm -rf /var/lib/apt/lists/*

# pmtiles CLI — install Protomaps go-pmtiles binary release for linux/amd64.
ARG PMTILES_VERSION=1.22.2
RUN curl -fsSL -o /tmp/pmtiles.tar.gz \
        "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/pmtiles.tar.gz -C /usr/local/bin pmtiles \
    && chmod +x /usr/local/bin/pmtiles \
    && rm /tmp/pmtiles.tar.gz \
    && pmtiles version

WORKDIR /app

# Python deps first (cache layer)
COPY tools/requirements.txt /app/tools/requirements.txt
RUN pip install -r /app/tools/requirements.txt

# Then the actual tool code
COPY tools /app/tools

ENTRYPOINT ["python", "/app/tools/orchestrate.py"]
CMD ["--all"]
