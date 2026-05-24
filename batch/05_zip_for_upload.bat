@echo off
setlocal EnableExtensions

rem RAMET — pack <Arma3>\ramet_output\{world}\ into per-world zips for SFTP upload
rem to a remote planner. Pass --bundle to emit a single ramet_output_bundle.zip.

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul
pushd "%SCRIPT_DIR%..\.." >nul
set "ARMA_ROOT=%CD%"

docker info >nul 2>nul
if not errorlevel 1 (
    docker run --rm ^
        -v "%ARMA_ROOT%":/work ^
        -e RAMET_ARMA_ROOT=/work ^
        --entrypoint python ^
        ramet-postprocess:latest /app/tools/deploy_to_planner.py --zip %*
    set "RC=%ERRORLEVEL%"
) else (
    where python >nul 2>nul || (
        echo [ERR] Neither Docker nor Python available.
        popd & exit /b 1
    )
    set "RAMET_ARMA_ROOT=%ARMA_ROOT%"
    python "%RAMET_ROOT%\tools\deploy_to_planner.py" --zip %*
    set "RC=%ERRORLEVEL%"
)

echo.
echo Zips ready under "%ARMA_ROOT%\ramet_output\_zips\"
popd
endlocal & exit /b %RC%
