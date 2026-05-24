@echo off
setlocal EnableExtensions

rem RAMET step 3 — post-process intermediate exports into output/{world}/.
rem Runs the ocap-rt Docker render, then orchestrate.py (merge + pmtiles + slice + optimize + verify).

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"

rem -------- ocap-rt Docker render --------
if exist "%RAMET_ROOT%\ocap_renderterrain_process.bat" (
    set "OCAP_BAT=%RAMET_ROOT%\ocap_renderterrain_process.bat"
) else if exist "%RAMET_ROOT%\subprojects\ocap-renderterrain\ocap_renderterrain_process.bat" (
    set "OCAP_BAT=%RAMET_ROOT%\subprojects\ocap-renderterrain\ocap_renderterrain_process.bat"
) else (
    echo [WARN] ocap_renderterrain_process.bat not found — skipping Docker render.
    set "OCAP_BAT="
)

if defined OCAP_BAT (
    echo === ocap-rt Docker render ===
    call "%OCAP_BAT%"
    if errorlevel 1 echo [WARN] Docker render exited with errors — continuing.
)

rem -------- orchestrate (Python) --------
where python >nul 2>nul || (
    echo [ERR] python not on PATH — install Python 3.11+ to run post-processing.
    popd & exit /b 1
)

echo === orchestrate (merge + pmtiles + slice + optimize + verify) ===
python "%RAMET_ROOT%\tools\orchestrate.py" --all
if errorlevel 1 (
    echo [ERR] orchestrate reported failures.
    popd & exit /b 1
)

echo === done. Output at "%RAMET_ROOT%\output". Run 04_deploy.bat to push to planner. ===
popd
endlocal
