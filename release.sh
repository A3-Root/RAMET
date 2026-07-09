#!/usr/bin/env bash
# RAMET release wrapper for Linux.
#
# Packages the repo with HEMTT and keeps the same release output layout as
# release.ps1. The native DLL builds are Windows-only in this repo, so this
# script treats them as prebuilt artifacts: pass --skip-subprojects if you only
# want to package existing outputs.

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

  --skip-subprojects       Skip native DLL checks and package existing outputs.
  --clean                  Force the default clean pass on.
  --no-clean               Skip the default clean pass.
  --rebuild-grad-meh-dll   Keep the default grad_meh rebuild requirement on.
  --no-rebuild-grad-meh-dll
                           Skip the default grad_meh rebuild requirement.
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
    grad_dll="$(grad_meh_dll || true)"
    a3me_dll_path="$(a3me_dll || true)"

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
    check_path "batch/04_deploy.bat" "deploy batch wrapper" issues
    check_path "batch/05_zip_for_upload.bat" "zip batch wrapper" issues
    check_path "batch/build_grad_meh.bat" "grad_meh build helper" issues
    check_path "batch/worlds.txt" "world queue file" issues
    check_path "batch/render_worlds.txt" "render filter file" issues
    check_path "ramet" "ramet Python package" issues
    check_path "modules/\$FLATDEVIL\$" "FlatDevil marker" issues
    check_path "modules/ocap_renderterrain" "ocap_renderterrain Python package" issues
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
    check_path "subprojects/ocap-renderterrain/ocap-renderterrain/Dockerfile" "ocap render Dockerfile" issues
    check_path "subprojects/ocap-renderterrain/ocap_renderterrain_process.bat" "ocap render launcher" issues

    if [[ "$SKIP_SUBPROJECTS" -eq 1 ]]; then
        notes+=("Skipping native DLL rebuilds by request.")
        for cmd in cmake conan ninja cargo dotnet; do
            if ! have_cmd "$cmd"; then
                notes+=("Required command '$cmd' is missing, but native rebuilds are skipped.")
            fi
        done
        if [[ -n "$grad_dll" ]]; then
            notes+=("Found grad_meh_x64.dll at '$grad_dll'.")
        else
            notes+=("grad_meh_x64.dll is missing; HEMTT will package without it and emit a warning.")
        fi
        if [[ -n "$a3me_dll_path" ]]; then
            notes+=("Found MapExportExtension_x64.dll at '$a3me_dll_path'.")
        else
            notes+=("MapExportExtension_x64.dll is missing; HEMTT will package without it and emit a warning.")
        fi
    else
        if [[ "$REBUILD_GRAD_MEH_DLL" -eq 1 || -z "$grad_dll" ]]; then
            notes+=("grad_meh_x64.dll will be rebuilt from source if the Windows toolchain is available.")
        fi
        if [[ -z "$a3me_dll_path" ]]; then
            notes+=("MapExportExtension_x64.dll will be rebuilt from source if the Windows toolchain is available.")
        fi
    fi

    if [[ "$SKIP_SUBPROJECTS" -eq 0 ]]; then
        for cmd in conan cmake ninja cargo dotnet; do
            if ! have_cmd "$cmd"; then
                issues+=("Required command '$cmd' is missing for the native DLL build chain.")
            fi
        done
        if ! have_cmd bash; then
            issues+=("Required command 'bash' is missing for the grad_meh versioning step.")
        fi
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
    if [[ "$SKIP_SUBPROJECTS" -eq 0 ]]; then
        rm -rf "subprojects/arma3MapExporter/publish"
    fi
fi

if [[ "$SKIP_SUBPROJECTS" -eq 0 ]]; then
    if [[ "$REBUILD_GRAD_MEH_DLL" -eq 1 ]]; then
        echo "grad_meh rebuild is not supported on Linux in this repo." >&2
        exit 1
    fi
    echo "=== using prebuilt native DLLs ==="
else
    echo "=== packaging without native DLL builds ==="
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
