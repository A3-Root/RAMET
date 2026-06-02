# RAMET post-processing image.
# Bundles every CLI orchestrate.py reaches for so the operator only needs Docker:
#   - tippecanoe (vector tile build, built from source — felt/tippecanoe)
#   - pmtiles CLI (mbtiles -> pmtiles convert, GitHub release binary)
#   - oxipng (PNG optimiser, pre-built musl binary)
#   - cwebp / pngquant (raster optimization, apt — fallback for topo tiles)
#   - Python 3.12 + lxml / pillow / numpy / pyyaml
#
# Build:  docker build -t ramet-postprocess:latest -f tools/Dockerfile .
# Run:    docker run --rm -v <Arma3>:/work -e RAMET_ARMA_ROOT=/work \
#                    ramet-postprocess:latest --all

# ---- Stage 1: build tippecanoe ----
FROM debian:bookworm-slim AS tippecanoe-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates \
        libsqlite3-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/felt/tippecanoe.git /tmp/tippecanoe \
    && make -C /tmp/tippecanoe -j$(nproc) \
    && strip /tmp/tippecanoe/tippecanoe /tmp/tippecanoe/tile-join \
    && make -C /tmp/tippecanoe install

# ---- Runtime image ----
FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Runtime deps only — no compiler, no -dev packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tar \
        libsqlite3-0 zlib1g \
        webp pngquant \
    && rm -rf /var/lib/apt/lists/*

# tippecanoe binary from builder stage (no build tools in final image).
COPY --from=tippecanoe-builder /usr/local/bin/tippecanoe /usr/local/bin/tippecanoe
COPY --from=tippecanoe-builder /usr/local/bin/tile-join  /usr/local/bin/tile-join
RUN tippecanoe --version

# oxipng — pre-built musl binary (statically linked).
ARG OXIPNG_VERSION=10.1.1
RUN curl -fsSL -o /tmp/oxipng.tar.gz \
        "https://github.com/oxipng/oxipng/releases/download/v${OXIPNG_VERSION}/oxipng-${OXIPNG_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && tar -xzf /tmp/oxipng.tar.gz -C /usr/local/bin --strip-components=1 \
    && chmod +x /usr/local/bin/oxipng \
    && rm /tmp/oxipng.tar.gz \
    && oxipng --version

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

# Cap glibc per-thread malloc arenas and trim aggressively. render_sat/topo churn
# many large transient PIL/numpy buffers (resize, alpha_composite); the default
# per-CPU arenas retain freed blocks, inflating RSS high-water far above live
# data. On a many-thread host this alone cuts measured peak markedly and keeps a
# 65536² world's peak under the 48 GB Docker budget. (Placed late so it does not
# invalidate the apt/pip build-cache layers above.)
ENV MALLOC_ARENA_MAX=2 \
    MALLOC_TRIM_THRESHOLD_=134217728

# Tool code.
COPY tools /app/tools

ENTRYPOINT ["python", "/app/tools/orchestrate.py"]
CMD ["--all"]
