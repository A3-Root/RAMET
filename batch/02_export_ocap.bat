@echo off
setlocal EnableExtensions

rem RAMET step 2 — bulk ocap-renderterrain export on Arma 3 DIAGNOSTIC branch.
rem Requires: @root_amet, @ocap_renderterrain in Arma3 root, plus diag binary.

rem batch/ lives inside @root_amet/ inside the Arma 3 root.
set "ARMA_ROOT=%~dp0..\.."
pushd "%ARMA_ROOT%" >nul

if not exist "arma3diag_x64.exe" (
    echo [ERR] arma3diag_x64.exe not found — switch to the diagnostic branch in Steam first.
    popd & exit /b 1
)

if not exist "%~dp0worlds.txt" (
    echo [ERR] %~dp0worlds.txt missing — populate it before running.
    popd & exit /b 1
)

rem Reset bulk state so the ocap pass iterates the full list independently.
if exist "%ARMA_ROOT%\ramet_state\bulk_state.json" del /q "%ARMA_ROOT%\ramet_state\bulk_state.json"

echo Launching Arma 3 (diag) for ocap-renderterrain bulk export...
start "" "arma3diag_x64.exe" -mod=@root_amet;@grad_meh;@ocap_renderterrain;@intercept;@CBA_A3 -world=empty -nosound -noPause -nosplash -window

echo.
echo When complete, run 03_postprocess.bat (no Arma needed for that step).

popd
endlocal
