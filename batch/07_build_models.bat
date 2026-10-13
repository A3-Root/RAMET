@echo off
setlocal EnableExtensions

rem RAMET step 7 — build the planner's map-independent 3D model library from the modpack PBOs.
rem Host only: no Docker, no Arma running. Reads the PBOs in place (nothing is unpacked).
rem Produces releases\models_library-<stamp>.zip, which extracts into the planner's data
rem directory as models3d\library.sqlite — the geometry for mission-placed objects.
rem
rem Run after every modpack update. Pass -Update for a delta instead of a full rebuild.
rem All arguments are forwarded to build_model_library.ps1.

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"

where powershell >nul 2>nul || (
    echo [ERR] powershell not on PATH.
    popd & exit /b 1
)
where python >nul 2>nul || (
    echo [ERR] python not on PATH — install Python 3.10+ on host.
    popd & exit /b 1
)

echo === build model library ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%RAMET_ROOT%\build_model_library.ps1" %*
set "RC=%ERRORLEVEL%"

popd
endlocal & exit /b %RC%
