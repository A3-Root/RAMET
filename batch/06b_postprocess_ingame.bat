@echo off
setlocal EnableExtensions EnableDelayedExpansion

@REM ====================================================
@REM             THIS IS BROKEN - DO NOT USE             
@REM ====================================================

rem RAMET step 6b - post-process GMS (arma3MapExporter) output only.
rem
rem Reads:   <Arma3>\ramet_ingame_output\{world}\   (index.json + base.png from GMS)
rem Writes:  <Arma3>\ramet_output\{world}\          (tiled + map.json, ready to deploy)
rem
rem Skips ocap-rt Docker render - run 03_postprocess.bat for the full pipeline.
rem Merges with any existing grad_meh / ocap data for the same world if present.

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul
pushd "%SCRIPT_DIR%..\.." >nul
set "ARMA_ROOT=%CD%"

echo [DBG] SCRIPT_DIR=%SCRIPT_DIR%
echo [DBG] RAMET_ROOT=%RAMET_ROOT%
echo [DBG] ARMA_ROOT=%ARMA_ROOT%

where docker >nul 2>nul || (
    echo [ERR] docker not on PATH - install Docker Desktop.
    popd & exit /b 1
)

rem -------- 1) Build ramet-postprocess image (cached after first build) --------
echo === building ramet-postprocess image (cached after first build) ===
docker build -t ramet-postprocess:latest -f "%RAMET_ROOT%\tools\Dockerfile" "%RAMET_ROOT%"
echo [DBG] docker build errorlevel=%ERRORLEVEL%
if errorlevel 1 (
    echo [ERR] docker build failed.
    popd & exit /b 1
)

rem -------- 2) Discover worlds from ramet_ingame_output --------
set "INGAME_ROOT=%ARMA_ROOT%\ramet_ingame_output"
echo [DBG] INGAME_ROOT=%INGAME_ROOT%
if not exist "%INGAME_ROOT%" (
    echo [ERR] %INGAME_ROOT% not found - run 06_export_ingame.bat first
    popd & exit /b 1
)
echo [DBG] INGAME_ROOT exists

set "WORLD_ARGS="
set "FOUND_WORLDS=0"
pushd "%INGAME_ROOT%"
echo [DBG] scanning for worlds in %CD%
for /d %%W in (*) do (
    echo [DBG] found dir: %%W
    if exist "%%W\index.json" (
        echo [DBG] index.json present in %%W
        set "FOUND_WORLDS=1"
        set "WORLD_ARGS=!WORLD_ARGS! --world %%W"
    )
)
popd
echo [DBG] WORLD_ARGS=%WORLD_ARGS%
echo [DBG] FOUND_WORLDS=%FOUND_WORLDS%

if "%WORLD_ARGS%"=="" (
    echo [ERR] No completed GMS worlds found in %INGAME_ROOT% - missing index.json
    popd & exit /b 1
)
echo [DBG] past world check

echo [GMS worlds] %WORLD_ARGS%

rem -------- 3) Run orchestrate for GMS worlds only --------
echo === orchestrate (ingame tile render + optimize + verify) ===
docker run --rm ^
    -v "%ARMA_ROOT%":/work ^
    -e RAMET_ARMA_ROOT=/work ^
    -e PYTHONUNBUFFERED=1 ^
    ramet-postprocess:latest --ingame-only %WORLD_ARGS%
if errorlevel 1 (
    echo [ERR] orchestrate reported failures.
    popd & exit /b 1
)

echo === done. Output at "%ARMA_ROOT%\ramet_output". Run 04_deploy.bat to push to planner. ===
popd
endlocal
