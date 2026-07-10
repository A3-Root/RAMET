#!/usr/bin/env bash
# Bash port of ocap_renderterrain_process.bat — builds and runs the ocap-renderterrain
# Docker image against exported source data. Same env vars, same mount layout, same
# positional world-filter argument, so it's a drop-in for batch/03_postprocess.sh.

set -euo pipefail

MOD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER_CONTEXT="$MOD_ROOT/ocap_renderterrain"

if [[ ! -f "$RENDER_CONTEXT/Dockerfile" ]]; then
    echo "Docker context not found: $RENDER_CONTEXT" >&2
    exit 1
fi

MOD_PARENT="$(cd "$MOD_ROOT/.." && pwd)"

ARMA_ROOT=""
if [[ -d "$MOD_PARENT/ocap_exporter" ]]; then
    ARMA_ROOT="$MOD_PARENT"
elif [[ -d "$PWD/ocap_exporter" ]]; then
    ARMA_ROOT="$PWD"
elif [[ -d "$MOD_ROOT/ocap_exporter" ]]; then
    ARMA_ROOT="$MOD_ROOT"
fi

if [[ -z "$ARMA_ROOT" ]]; then
    echo "Could not find exported source data." >&2
    echo "Checked:" >&2
    echo "  $MOD_PARENT/ocap_exporter" >&2
    echo "  $PWD/ocap_exporter" >&2
    echo "  $MOD_ROOT/ocap_exporter" >&2
    echo "Run this from your Arma 3 root, or place @ocap_renderterrain inside the Arma 3 root after exporting terrain source data." >&2
    exit 1
fi

INPUT_DIR="$ARMA_ROOT/ocap_exporter"
OUTPUT_DIR="$ARMA_ROOT/ocap_renderterrain_output"
WORLDS="${1:-}"
OCAP_RENDER_DOCKER_MEMORY="${OCAP_RENDER_DOCKER_MEMORY:-48g}"

mkdir -p "$OUTPUT_DIR"

echo "Building Docker image from \"$RENDER_CONTEXT\"..."
docker build -t ocap-renderterrain:latest "$RENDER_CONTEXT"

docker rm -f ocap-renderterrain-manual >/dev/null 2>&1 || true

echo "Processing source data from \"$INPUT_DIR\"..."
echo "Writing rendered output to \"$OUTPUT_DIR\"..."
if [[ -z "$WORLDS" ]]; then
    docker run --rm --name ocap-renderterrain-manual \
        --mount type=bind,src="$INPUT_DIR",target=/app/input \
        --mount type=bind,src="$OUTPUT_DIR",target=/app/output \
        --env OCAP_RENDER_MAX_SIZE=32768 \
        --memory="$OCAP_RENDER_DOCKER_MEMORY" \
        ocap-renderterrain:latest
else
    docker run --rm --name ocap-renderterrain-manual \
        --mount type=bind,src="$INPUT_DIR",target=/app/input \
        --mount type=bind,src="$OUTPUT_DIR",target=/app/output \
        --env "OCAP_RENDER_WORLDS=$WORLDS" \
        --env OCAP_RENDER_MAX_SIZE=32768 \
        --memory="$OCAP_RENDER_DOCKER_MEMORY" \
        ocap-renderterrain:latest
fi
