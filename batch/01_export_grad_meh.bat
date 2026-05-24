@echo off
setlocal EnableExtensions

rem RAMET step 1 — bulk grad_meh export on Arma 3 MAIN branch.
rem Requires: @root_amet, @grad_meh, @intercept, @CBA_A3 in Arma3 root.
rem worlds.txt must list one CfgWorlds class per line.

set "ARMA_ROOT=%~dp0.."
pushd "%ARMA_ROOT%" >nul

if not exist "arma3_64.exe" (
    echo [ERR] arma3_64.exe not found in "%ARMA_ROOT%" — point this script at your Arma 3 root.
    popd & exit /b 1
)

if not exist "worlds.txt" (
    if exist "%~dp0worlds.txt" (
        copy "%~dp0worlds.txt" "%ARMA_ROOT%\worlds.txt" >nul
    ) else (
        echo [ERR] worlds.txt missing — drop one in Arma3 root or batch/ folder.
        popd & exit /b 1
    )
)

rem Reset bulk state so the run starts from a clean queue.
if exist "ramet_state\bulk_state.json" del /q "ramet_state\bulk_state.json"

echo Launching Arma 3 (main) for grad_meh bulk export...
echo NOTE: load any world from worlds.txt; the in-game loop iterates the rest via Archangel.
start "" "arma3_64.exe" -mod=@root_amet;@grad_meh;@intercept;@CBA_A3 -world=empty -nosound -noPause -nosplash -window

echo.
echo When Arma reports "bulk grad_meh export complete" in ramet_state\ramet_bulk.log,
echo close Arma, swap to the diagnostic branch binary, and run 02_export_ocap.bat.

popd
endlocal
