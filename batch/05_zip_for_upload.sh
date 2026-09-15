#!/usr/bin/env bash
# RAMET — pack <Arma3>/RAMET_Output/processed/{world}/ into per-world zips for SFTP upload
# to a remote planner. Pass --bundle to emit a single RAMET_Output_bundle.zip.
# Native bash reimplementation — host Python only (deploy_to_planner.py --zip is
# stdlib-only). Works on Linux, WSL, and Git Bash.
# Raster tiles are packed into {world}/tiles.sqlite inside each zip; pass --loose to zip loose tiles/ instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARMA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERR] python3 not on PATH — install Python 3.10+." >&2
    exit 1
fi

export RAMET_ARMA_ROOT="$ARMA_ROOT"
python3 "$RAMET_ROOT/tools/deploy_to_planner.py" --zip "$@"

echo
echo "Zips ready under \"$ARMA_ROOT/RAMET_Output/_zips/\""
