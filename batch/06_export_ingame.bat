@echo off
setlocal EnableExtensions

@REM ====================================================
@REM             THIS IS BROKEN - DO NOT USE             
@REM ====================================================

rem RAMET step 6 — in-game (GMS) bulk export.
rem Requires: @arma3MapExporter, @CBA_A3, @root_amet, ARCHANGEL.
rem Sets RAMET_INGAME_OUTPUT_DIR so the GMS C# extension writes into the Arma 3 root.

set "ARMA_ROOT=%~dp0..\.."
pushd "%ARMA_ROOT%" >nul

if not exist "arma3_x64.exe" (
    echo [ERR] arma3_x64.exe not found — main branch needed for in-game export.
    popd & exit /b 1
)

if not exist "%~dp0worlds.txt" (
    echo [ERR] %~dp0worlds.txt missing — populate it before running.
    popd & exit /b 1
)

if not exist "%ARMA_ROOT%\@arma3MapExporter" (
    echo [ERR] @arma3MapExporter missing in Arma 3 root.
    popd & exit /b 1
)

set "RAMET_INGAME_OUTPUT_DIR=%ARMA_ROOT%\arma3_mapexporter_output"
if not exist "%RAMET_INGAME_OUTPUT_DIR%" mkdir "%RAMET_INGAME_OUTPUT_DIR%"

echo Launching Arma 3 for in-game (GMS) bulk export...
start "" "arma3_x64.exe" -mod=@root_amet;@arma3MapExporter;@CBA_A3 -world=empty -nosound -noPause -nosplash -window

echo.
echo When complete, run 03_postprocess.bat (Docker required).

popd
endlocal
