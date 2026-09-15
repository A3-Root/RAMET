#!/usr/bin/env bash
# RAMET step 4 — copy <Arma3>/RAMET_Output/processed/ into a user-supplied planner map_tiles/ directory.
# Native bash reimplementation — host Python only (deploy_to_planner.py is stdlib-only,
# no Docker needed). Works on Linux, WSL, and Git Bash.
# Raster tiles are packed into {world}/tiles.sqlite; pass --loose to copy loose tiles/ instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARMA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERR] python3 not on PATH — install Python 3.10+." >&2
    exit 1
fi

echo "=== deploy via host Python ==="
export RAMET_ARMA_ROOT="$ARMA_ROOT"
python3 "$RAMET_ROOT/tools/deploy_to_planner.py" "$@"
