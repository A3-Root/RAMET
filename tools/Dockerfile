# RAMET post-processing image.
# Bundles every CLI orchestrate.py reaches for so the operator only needs Docker:
#   - tippecanoe (vector tile build, built from source — felt/tippecanoe)
#   - pmtiles CLI (mbtiles -> pmtiles convert, GitHub release binary)
#   - oxipng (PNG optimiser, built from source via cargo — multi-stage)
#   - cwebp / pngquant (raster optimization, apt)
#   - Python 3.12 + lxml / pillow / numpy / pyyaml
#
# Build:  docker build -t ramet-postprocess:latest -f tools/Dockerfile .
# Run:    docker run --rm -v <Arma3>:/work -e RAMET_ARMA_ROOT=/work \
#                    ramet-postprocess:latest --all
#
# The image's ENTRYPOINT is orchestrate.py — anything after the image name
# is passed straight through (e.g. --world altis, --skip-pmtiles).

# ---- Stage 1: build oxipng ----
FROM rust:slim-bookworm AS oxipng-builder

RUN git clone https://github.com/oxipng/oxipng.git /tmp/oxipng \
    && cd /tmp/oxipng \
    && cargo build --release

# ---- Stage 2: main runtime image ----
FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# System deps + tippecanoe build deps.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tar build-essential git \
        libsqlite3-dev zlib1g-dev \
        webp pngquant \
    && rm -rf /var/lib/apt/lists/*

# tippecanoe — build from source (felt/tippecanoe, no bookworm package).
RUN git clone https://github.com/felt/tippecanoe.git /tmp/tippecanoe \
    && make -C /tmp/tippecanoe -j$(nproc) \
    && make -C /tmp/tippecanoe install \
    && rm -rf /tmp/tippecanoe \
    && tippecanoe --version

# oxipng — copy binary from builder stage.
COPY --from=oxipng-builder /tmp/oxipng/target/release/oxipng /usr/local/bin/oxipng

# pmtiles CLI — Protomaps go-pmtiles binary release for linux/amd64.
ARG PMTILES_VERSION=1.22.2
RUN curl -fsSL -o /tmp/pmtiles.tar.gz \
        "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/pmtiles.tar.gz -C /usr/local/bin pmtiles \
    && chmod +x /usr/local/bin/pmtiles \
    && rm /tmp/pmtiles.tar.gz \
    && pmtiles version

WORKDIR /app

# Python deps first (cache layer).
COPY tools/requirements.txt /app/tools/requirements.txt
RUN pip install -r /app/tools/requirements.txt

# Tool code.
COPY tools /app/tools

ENTRYPOINT ["python", "/app/tools/orchestrate.py"]
CMD ["--all"]
