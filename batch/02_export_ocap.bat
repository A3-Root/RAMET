@echo off
setlocal EnableExtensions

rem RAMET step 2 — bulk ocap-renderterrain export on Arma 3 DIAGNOSTIC branch.
rem Requires: @root_amet, @ocap_renderterrain in Arma3 root, plus diag binary.

set "ARMA_ROOT=%~dp0.."
pushd "%ARMA_ROOT%" >nul

if not exist "arma3diag_x64.exe" (
    echo [ERR] arma3diag_x64.exe not found — switch to the diagnostic branch in Steam first.
    popd & exit /b 1
)

if not exist "worlds.txt" (
    if exist "%~dp0worlds.txt" (
        copy "%~dp0worlds.txt" "%ARMA_ROOT%\worlds.txt" >nul
    ) else (
        echo [ERR] worlds.txt missing.
        popd & exit /b 1
    )
)

rem Reset bulk state so the ocap pass iterates the full list independently.
if exist "ramet_state\bulk_state.json" del /q "ramet_state\bulk_state.json"

echo Launching Arma 3 (diag) for ocap-renderterrain bulk export...
start "" "arma3diag_x64.exe" -mod=@root_amet;@ocap_renderterrain -world=empty -nosound -noPause -nosplash -window

echo.
echo When complete, run 03_postprocess.bat (no Arma needed for that step).

popd
endlocal
