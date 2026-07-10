#!/usr/bin/env bash
# RAMET release wrapper for Linux.
#
# Packages the repo with HEMTT and keeps the same release output layout as
# release.ps1. grad_meh and arma3MapExporter DLL builds require a Windows
# toolchain (MSVC/NativeAOT) and are always treated as prebuilt artifacts here
# — Proton loads the same Windows .dll unmodified, there is no Linux-native
# equivalent to build. ocap_exporter (Go) genuinely cross-compiles from Linux
# via MinGW-w64 (see subprojects/ocap-renderterrain/ocap-exporter/build.sh) and
# is rebuilt automatically when the toolchain is present. Pass
# --skip-subprojects to package existing outputs only.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

CHECK_ARGS=(check -p -Lc14 -e)
SKIP_SUBPROJECTS=0
CLEAN=1
REBUILD_GRAD_MEH_DLL=1

usage() {
    cat <<'EOF'
Usage: ./release.sh [--skip-subprojects] [--clean] [--rebuild-grad-meh-dll]

  --skip-subprojects       Skip the ocap_exporter DLL cross-build and package existing outputs.
  --clean                  Force the default clean pass on.
  --no-clean               Skip the default clean pass.
  --rebuild-grad-meh-dll   No-op on Linux (kept for CLI parity with release.ps1) — grad_meh
                           always requires the Windows toolchain and is never rebuilt here.
  --no-rebuild-grad-meh-dll
                           Same as above; accepted but has no effect on Linux.

grad_meh_x64.dll and MapExportExtension_x64.dll always require a Windows toolchain
(MSVC / NativeAOT) and are packaged as prebuilt artifacts if present. ocap_exporter_x64.dll
cross-compiles from Linux via mingw-w64 (see subprojects/ocap-renderterrain/ocap-exporter/build.sh)
and is rebuilt automatically unless --skip-subprojects is passed.
EOF
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_path() {
    local path="$1"
    local description="$2"
    local -n issues_ref="$3"
    if [[ ! -e "$path" ]]; then
        issues_ref+=("$description is missing at '$path'.")
    fi
}

find_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        printf '%s\n' "$path"
    fi
}

grad_meh_dll() {
    find_file "subprojects/grad_meh/build/lib64/grad_meh_x64.dll"
}

a3me_dll() {
    find_file "subprojects/arma3MapExporter/publish/MapExportExtension_x64.dll"
}

ocap_exporter_dll() {
    find_file "subprojects/ocap-renderterrain/ocap-exporter/ocap_exporter_x64.dll"
}

preflight_report() {
    local -a issues=()
    local -a notes=()

    for cmd in hemtt docker git bash python3; do
        if ! have_cmd "$cmd"; then
            issues+=("Required command '$cmd' is not on PATH.")
        fi
    done

    local grad_dll
    local a3me_dll_path
    local ocap_dll_path
    grad_dll="$(grad_meh_dll || true)"
    a3me_dll_path="$(a3me_dll || true)"
    ocap_dll_path="$(ocap_exporter_dll || true)"

    if have_cmd docker; then
        if ! docker info >/dev/null 2>&1; then
            issues+=("Docker is on PATH but the daemon is not reachable. Start Docker and retry.")
        fi
    fi

    check_path ".hemtt/project.toml" ".hemtt project" issues
    check_path ".hemtt/hooks/post_build/01_bundle_pipeline.rhai" "post_build bundle hook" issues
    check_path "tools/Dockerfile" "Dockerfile" issues
    check_path "tools/requirements.txt" "Python requirements" issues
    check_path "tools/deploy_to_planner.py" "planner deploy helper" issues
    check_path "tools/orchestrate.py" "post-process orchestrator" issues
    check_path "batch/01_export_grad_meh.bat" "grad_meh batch wrapper" issues
    check_path "batch/02_export_ocap.bat" "ocap batch wrapper" issues
    check_path "batch/03_postprocess.bat" "post-process batch wrapper" issues
    check_path "batch/03_postprocess.sh" "post-process shell wrapper" issues
    check_path "batch/04_deploy.bat" "deploy batch wrapper" issues
    check_path "batch/04_deploy.sh" "deploy shell wrapper" issues
    check_path "batch/05_zip_for_upload.bat" "zip batch wrapper" issues
    check_path "batch/05_zip_for_upload.sh" "zip shell wrapper" issues
    check_path "batch/build_grad_meh.bat" "grad_meh build helper" issues
    check_path "batch/worlds.txt" "world queue file" issues
    check_path "batch/render_worlds.txt" "render filter file" issues
    check_path "ramet" "ramet Python package" issues
    check_path "modules/\$FLATDEVIL\$" "FlatDevil marker" issues
    check_path "addons/main" "main addon" issues
    check_path "addons/grad_meh_main" "grad_meh main addon" issues
    check_path "addons/grad_meh_ui" "grad_meh UI addon" issues
    check_path "addons/ocap_exporter" "ocap exporter addon" issues
    check_path "addons/ocap_ui" "ocap UI addon" issues
    check_path "addons/a3me_main" "arma3MapExporter main addon" issues
    check_path "addons/a3me_exporter" "arma3MapExporter exporter addon" issues
    check_path "addons/intercept_core" "intercept core addon" issues
    check_path "vendor/intercept/intercept_x64.dll" "vendored intercept DLL" issues
    check_path "subprojects/grad_meh/CMakePresets.json" "grad_meh CMake presets" issues
    check_path "subprojects/grad_meh/conanfile.py" "grad_meh Conan recipe" issues
    check_path "subprojects/grad_meh/ci-conan-profile" "grad_meh Conan profile" issues
    check_path "subprojects/grad_meh/conan.lock" "grad_meh Conan lockfile" issues
    check_path "subprojects/arma3MapExporter/MapExportExtension/MapExportExtension.csproj" "arma3MapExporter project" issues
    check_path "subprojects/ocap-renderterrain/ocap-exporter/go.mod" "ocap exporter module" issues
    check_path "subprojects/ocap-renderterrain/ocap-exporter/build.sh" "ocap exporter cross-build script" issues
    check_path "subprojects/ocap-renderterrain/ocap-renderterrain/Dockerfile" "ocap render Dockerfile" issues
    check_path "subprojects/ocap-renderterrain/ocap_renderterrain_process.sh" "ocap render launcher" issues

    # grad_meh and arma3MapExporter DLLs require a Windows toolchain (MSVC/NativeAOT) that
    # doesn't exist on Linux — always treated as prebuilt here, never rebuilt, never blocking.
    if [[ -n "$grad_dll" ]]; then
        notes+=("Found grad_meh_x64.dll at '$grad_dll'.")
    else
        notes+=("grad_meh_x64.dll is missing; it requires a Windows toolchain to build (see release.ps1). HEMTT will package without it and emit a warning.")
    fi
    if [[ -n "$a3me_dll_path" ]]; then
        notes+=("Found MapExportExtension_x64.dll at '$a3me_dll_path'.")
    else
        notes+=("MapExportExtension_x64.dll is missing; it requires a Windows toolchain to build (see release.ps1). HEMTT will package without it and emit a warning.")
    fi
    if [[ "$REBUILD_GRAD_MEH_DLL" -eq 1 ]]; then
        notes+=("--rebuild-grad-meh-dll has no effect on Linux — grad_meh always requires the Windows toolchain.")
    fi

    if [[ "$SKIP_SUBPROJECTS" -eq 1 ]]; then
        notes+=("Skipping ocap_exporter DLL rebuild by request.")
        if [[ -n "$ocap_dll_path" ]]; then
            notes+=("Found ocap_exporter_x64.dll at '$ocap_dll_path'.")
        else
            notes+=("ocap_exporter_x64.dll is missing; HEMTT will package without it and emit a warning.")
        fi
    else
        for cmd in go x86_64-w64-mingw32-gcc i686-w64-mingw32-gcc; do
            if ! have_cmd "$cmd"; then
                issues+=("Required command '$cmd' is missing for the ocap_exporter cross-build (mingw-w64 + go).")
            fi
        done
    fi

    echo "=== preflight ==="
    for note in "${notes[@]}"; do
        echo "  note: $note"
    done

    if [[ "${#issues[@]}" -gt 0 ]]; then
        echo "  blocking issues:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
        echo "Preflight failed. Fix the blocking issues above, then re-run release.sh." >&2
        exit 1
    fi

    echo "  all required build tools and local project files were found."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-subprojects)
            SKIP_SUBPROJECTS=1
            ;;
        --clean)
            CLEAN=1
            ;;
        --no-clean)
            CLEAN=0
            ;;
        --rebuild-grad-meh-dll)
            REBUILD_GRAD_MEH_DLL=1
            ;;
        --no-rebuild-grad-meh-dll)
            REBUILD_GRAD_MEH_DLL=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

preflight_report

if [[ "$CLEAN" -eq 1 ]]; then
    rm -rf ".hemttout" "releases"
    # arma3MapExporter/publish and grad_meh's build/ are never wiped here — this script
    # never rebuilds them (Windows-toolchain-only), so any prebuilt DLL placed there is
    # the user's input to package, not a stale artifact to clean.
fi

echo "=== grad_meh_x64.dll / MapExportExtension_x64.dll: always prebuilt on Linux (Windows toolchain required, see release.ps1) ==="

if [[ "$SKIP_SUBPROJECTS" -eq 0 ]]; then
    echo "=== cross-compiling ocap_exporter_x64.dll (go + mingw-w64) ==="
    if ! ./subprojects/ocap-renderterrain/ocap-exporter/build.sh; then
        echo "[WARN] ocap_exporter cross-build failed — packaging without it." >&2
    fi
else
    echo "=== packaging without rebuilding ocap_exporter_x64.dll ==="
fi

echo "=== building RAMET ==="
echo "  > hemtt ${CHECK_ARGS[*]}"
hemtt "${CHECK_ARGS[@]}"
echo "  > hemtt release"
hemtt release

latest_zip=""
if [[ -d "releases" ]]; then
    latest_zip="$(
        find releases -maxdepth 1 -type f -name 'root_amet-*.zip' ! -name '*-latest*' -printf '%T@ %p\n' 2>/dev/null \
            | sort -nr \
            | awk 'NR==1 { $1=""; sub(/^ /, ""); print; exit }'
    )"
fi

echo
if [[ -n "$latest_zip" ]]; then
    echo "Release ready:"
    echo "  $latest_zip"
else
    echo "Release finished, but no versioned zip was found under releases/."
fi
