#!/usr/bin/env bash
# RAMET step 3 — post-process intermediate exports into <Arma3>/ramet_output/{world}/.
#
# Native bash reimplementation of 03_postprocess.bat — runs directly on Linux, WSL, or
# Git Bash, no cmd.exe involved. Runs entirely in Docker — no host install of
# tippecanoe / pmtiles / cwebp / etc.
#   * ocap-rt render :  uses ocap_renderterrain_process.sh (its own Docker image)
#   * RAMET orchestrate : uses the `ramet-postprocess` image built from tools/Dockerfile
#
# Flags:
#   --skip-ocap    Skip the ocap-rt Docker render (use when tiles already rendered)

set -euo pipefail

SKIP_OCAP=0
for arg in "$@"; do
    case "$arg" in
        --skip-ocap) SKIP_OCAP=1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARMA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERR] docker not on PATH — install Docker." >&2
    exit 1
fi

# -------- 1) ocap-rt Docker render --------
OCAP_SH=""
if [[ -f "$ARMA_ROOT/@root_amet/ocap_renderterrain_process.sh" ]]; then
    OCAP_SH="$ARMA_ROOT/@root_amet/ocap_renderterrain_process.sh"
elif [[ -f "$RAMET_ROOT/subprojects/ocap-renderterrain/ocap_renderterrain_process.sh" ]]; then
    OCAP_SH="$RAMET_ROOT/subprojects/ocap-renderterrain/ocap_renderterrain_process.sh"
else
    echo "[WARN] ocap_renderterrain_process.sh not found — skipping Docker render."
fi

# -------- Read render_worlds.txt → comma-separated list for ocap-rt --------
RENDER_WORLDS_FILE="$SCRIPT_DIR/render_worlds.txt"
RENDER_WORLDS=""
if [[ -f "$RENDER_WORLDS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -z "$line" ]] && continue
        if [[ -n "$RENDER_WORLDS" ]]; then
            RENDER_WORLDS="$RENDER_WORLDS,$line"
        else
            RENDER_WORLDS="$line"
        fi
    done < "$RENDER_WORLDS_FILE"
fi
if [[ -n "$RENDER_WORLDS" ]]; then
    echo "[render_worlds.txt] Filtering render to: $RENDER_WORLDS"
else
    echo "[render_worlds.txt] Empty or missing — rendering all worlds."
fi

if [[ "$SKIP_OCAP" -eq 1 ]]; then
    echo "[SKIP] ocap-rt render skipped - --skip-ocap passed."
elif [[ -n "$OCAP_SH" ]]; then
    echo "=== ocap-rt Docker render ==="
    if ! "$OCAP_SH" "$RENDER_WORLDS"; then
        echo "[WARN] Docker render exited with errors - continuing."
    fi
fi

# -------- 2) RAMET orchestrate image (build once, reuse forever) --------
echo "=== building ramet-postprocess image (cached after first build) ==="
docker build -t ramet-postprocess:latest -f "$RAMET_ROOT/tools/Dockerfile" "$RAMET_ROOT"

# -------- 3) Run orchestrate inside the image, mounting Arma 3 root --------
ORCHESTRATE_WORLDS=(--all)
if [[ -n "$RENDER_WORLDS" ]]; then
    ORCHESTRATE_WORLDS=()
    IFS=',' read -ra WORLD_ARR <<< "$RENDER_WORLDS"
    for w in "${WORLD_ARR[@]}"; do
        ORCHESTRATE_WORLDS+=(--world "$w")
    done
fi

echo "=== orchestrate (merge + pmtiles + slice + optimize + verify) ==="
docker run --rm \
    -v "$ARMA_ROOT":/work \
    -e RAMET_ARMA_ROOT=/work \
    -e PYTHONUNBUFFERED=1 \
    ramet-postprocess:latest "${ORCHESTRATE_WORLDS[@]}" --workers 2 --optimize-workers 4

echo "=== done. Output at \"$ARMA_ROOT/ramet_output\". Run 04_deploy.sh to push to planner. ==="
