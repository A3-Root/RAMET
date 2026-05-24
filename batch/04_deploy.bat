@echo off
setlocal EnableExtensions

rem RAMET step 4 — sync output/ into JSOC-OPS-Warlords/server/warlords/map_tiles/.

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul

where python >nul 2>nul || (
    echo [ERR] python not on PATH.
    popd & exit /b 1
)

python "%CD%\tools\deploy_to_planner.py" %*
set "RC=%ERRORLEVEL%"
popd
endlocal & exit /b %RC%
