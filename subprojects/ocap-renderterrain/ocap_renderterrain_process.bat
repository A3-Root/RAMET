@echo off
setlocal EnableExtensions

set "MOD_ROOT=%~dp0"
if "%MOD_ROOT:~-1%"=="\" set "MOD_ROOT=%MOD_ROOT:~0,-1%"

set "RENDER_CONTEXT=%MOD_ROOT%\ocap_renderterrain"
if not exist "%RENDER_CONTEXT%\Dockerfile" (
    echo Docker context not found: "%RENDER_CONTEXT%"
    exit /b 1
)

for %%I in ("%MOD_ROOT%\..") do set "MOD_PARENT=%%~fI"

set "ARMA_ROOT="
if exist "%MOD_PARENT%\ocap_exporter\" set "ARMA_ROOT=%MOD_PARENT%"
if not defined ARMA_ROOT if exist "%CD%\ocap_exporter\" set "ARMA_ROOT=%CD%"
if not defined ARMA_ROOT if exist "%MOD_ROOT%\ocap_exporter\" set "ARMA_ROOT=%MOD_ROOT%"

if not defined ARMA_ROOT (
    echo Could not find exported source data.
    echo Checked:
    echo   "%MOD_PARENT%\ocap_exporter"
    echo   "%CD%\ocap_exporter"
    echo   "%MOD_ROOT%\ocap_exporter"
    echo Run this from your Arma 3 root, or place @ocap_renderterrain inside the Arma 3 root after exporting terrain source data.
    exit /b 1
)

set "INPUT_DIR=%ARMA_ROOT%\ocap_exporter"
set "OUTPUT_DIR=%ARMA_ROOT%\ocap_renderterrain_output"
set "WORLDS=%~1"
if "%OCAP_RENDER_DOCKER_MEMORY%"=="" set "OCAP_RENDER_DOCKER_MEMORY=48g"

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Building Docker image from "%RENDER_CONTEXT%"...
docker build -t ocap-renderterrain:latest "%RENDER_CONTEXT%"
if errorlevel 1 exit /b %errorlevel%

docker rm -f ocap-renderterrain-manual >nul 2>nul

echo Processing source data from "%INPUT_DIR%"...
echo Writing rendered output to "%OUTPUT_DIR%"...
if "%WORLDS%"=="" (
    docker run --rm --name ocap-renderterrain-manual ^
      --mount type=bind,src="%INPUT_DIR%",target=/app/input ^
      --mount type=bind,src="%OUTPUT_DIR%",target=/app/output ^
      --env OCAP_RENDER_MAX_SIZE=32768 ^
      --memory=%OCAP_RENDER_DOCKER_MEMORY% ^
      ocap-renderterrain:latest
) else (
    docker run --rm --name ocap-renderterrain-manual ^
      --mount type=bind,src="%INPUT_DIR%",target=/app/input ^
      --mount type=bind,src="%OUTPUT_DIR%",target=/app/output ^
      --env "OCAP_RENDER_WORLDS=%WORLDS%" ^
      --env OCAP_RENDER_MAX_SIZE=32768 ^
      --memory=%OCAP_RENDER_DOCKER_MEMORY% ^
      ocap-renderterrain:latest
)

exit /b %errorlevel%
