@echo off
setlocal EnableExtensions

rem RAMET step 4 — copy <Arma3>\ramet_output\ into JSOC-OPS-Warlords\server\warlords\map_tiles\.
rem
rem Tries the ramet-postprocess Docker image first (no host Python needed); falls back
rem to a local `python` if Docker isn't running.

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul
pushd "%SCRIPT_DIR%..\.." >nul
set "ARMA_ROOT=%CD%"

set "PLANNER_DEFAULT=%RAMET_ROOT%\..\..\JSOC-OPS-Warlords\server\warlords\map_tiles"

docker info >nul 2>nul
if not errorlevel 1 (
    echo === deploy via Docker ===
    docker run --rm ^
        -v "%ARMA_ROOT%":/work ^
        -v "%PLANNER_DEFAULT%":/planner ^
        -e RAMET_ARMA_ROOT=/work ^
        --entrypoint python ^
        ramet-postprocess:latest /app/tools/deploy_to_planner.py ^
        --output /work/ramet_output --planner-root /planner %*
    set "RC=%ERRORLEVEL%"
) else (
    where python >nul 2>nul || (
        echo [ERR] Neither Docker nor Python available on host.
        popd & exit /b 1
    )
    echo === deploy via host Python ===
    set "RAMET_ARMA_ROOT=%ARMA_ROOT%"
    python "%RAMET_ROOT%\tools\deploy_to_planner.py" %*
    set "RC=%ERRORLEVEL%"
)

popd
endlocal & exit /b %RC%
