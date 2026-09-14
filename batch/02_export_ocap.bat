@echo off
setlocal EnableExtensions

rem RAMET step 2 — bulk ocap-renderterrain export.
rem Requires: @root_amet, @CBA_A3 in Arma3 root. Runs on the normal game binary
rem (terrain SVG comes from the extension); the diagnostic binary is only used
rem when the normal x64 binary is missing.

rem batch/ lives inside @root_amet/ inside the Arma 3 root.
set "ARMA_ROOT=%~dp0..\.."
pushd "%ARMA_ROOT%" >nul

set "ARMA_EXE=arma3_x64.exe"
if not exist "%ARMA_EXE%" set "ARMA_EXE=arma3diag_x64.exe"
if not exist "%ARMA_EXE%" (
    echo [ERR] Neither arma3_x64.exe nor arma3diag_x64.exe found in the Arma 3 root.
    popd & exit /b 1
)

if not exist "%~dp0worlds.txt" (
    echo [ERR] %~dp0worlds.txt missing — populate it before running.
    popd & exit /b 1
)

rem Bulk state is per-stage (schema ramet-bulk-2) — no reset needed; the ocap
rem pass advances only its own stage cell. Resume across crashes / re-runs is automatic.

echo Launching Arma 3 (%ARMA_EXE%) for ocap-renderterrain bulk export...
start "" "%ARMA_EXE%" -mod=@root_amet;@CBA_A3 -world=empty -nosound -noPause -nosplash -window

echo.
echo When complete, run 03_postprocess.bat (no Arma needed for that step).

popd
endlocal
