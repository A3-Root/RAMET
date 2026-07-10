#!/usr/bin/env bash
# Cross-compile ocap_exporter's Go/Intercept extension to Windows DLLs from a Linux host.
# Mirrors build.bat (GOARCH 386/amd64), using MinGW-w64 as the cross-linker — the produced
# .dll is loaded by Intercept inside Arma 3 (native or under Proton), same as if built on
# Windows. Requires: go, mingw-w64 (x86_64-w64-mingw32-gcc, i686-w64-mingw32-gcc).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

require_cmd() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERR] '$cmd' not found on PATH. $hint" >&2
        exit 1
    fi
}

require_cmd go "Install a Go 1.16+ toolchain."
require_cmd x86_64-w64-mingw32-gcc "Install mingw-w64 (e.g. 'sudo apt install mingw-w64')."
require_cmd i686-w64-mingw32-gcc "Install mingw-w64 (e.g. 'sudo apt install mingw-w64')."

echo "=== cross-compiling ocap_exporter_x64.dll (amd64) ==="
GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc \
    go build -o ocap_exporter_x64.dll -buildmode=c-shared .

echo "=== cross-compiling ocap_exporter.dll (386) ==="
GOOS=windows GOARCH=386 CGO_ENABLED=1 CC=i686-w64-mingw32-gcc \
    go build -o ocap_exporter.dll -buildmode=c-shared .

echo "=== done: ocap_exporter_x64.dll, ocap_exporter.dll ==="
