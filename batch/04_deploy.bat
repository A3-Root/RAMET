@echo off
setlocal EnableExtensions

rem RAMET step 4 — copy <Arma3>\ramet_output\ into a user-supplied planner map_tiles\ directory.
rem Host Python only (deploy_to_planner.py is stdlib-only — no Docker needed).

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul
pushd "%SCRIPT_DIR%..\.." >nul
set "ARMA_ROOT=%CD%"

where python >nul 2>nul || (
    echo [ERR] python not on PATH — install Python 3.10+ on host.
    popd & exit /b 1
)

echo === deploy via host Python ===
set "RAMET_ARMA_ROOT=%ARMA_ROOT%"
python "%RAMET_ROOT%\tools\deploy_to_planner.py" %*
set "RC=%ERRORLEVEL%"

popd
endlocal & exit /b %RC%
