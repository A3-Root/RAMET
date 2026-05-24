@echo off
setlocal EnableExtensions

rem RAMET full pipeline — chains 01..04 with pauses for the manual branch swap.

set "SCRIPT_DIR=%~dp0"

echo === STEP 1: grad_meh export (Arma 3 MAIN branch) ===
call "%SCRIPT_DIR%01_export_grad_meh.bat"
echo.
echo [PAUSE] Swap Arma 3 to DIAGNOSTIC branch in Steam, then press any key to continue.
pause >nul

echo === STEP 2: ocap-renderterrain export (Arma 3 DIAG branch) ===
call "%SCRIPT_DIR%02_export_ocap.bat"
echo.
echo [PAUSE] When Arma reports completion in ramet_state\ramet_bulk.log, press any key.
pause >nul

echo === STEP 3: post-process ===
call "%SCRIPT_DIR%03_postprocess.bat"
if errorlevel 1 (
    echo [ERR] post-process failed — fix and re-run 03_postprocess.bat then 04_deploy.bat.
    endlocal & exit /b 1
)

echo === STEP 4: deploy to planner ===
call "%SCRIPT_DIR%04_deploy.bat"
echo === pipeline complete ===
endlocal
