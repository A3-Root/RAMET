@echo off
setlocal

cd /d "%~dp0\.."

if not exist input mkdir input
if not exist output mkdir output
if not exist temp mkdir temp
if "%OCAP_RENDER_DOCKER_MEMORY%"=="" set "OCAP_RENDER_DOCKER_MEMORY=48g"

docker build -t ocap-renderterrain:latest ocap-renderterrain
if errorlevel 1 exit /b %errorlevel%

docker run --rm --name ocap-renderterrain ^
  --mount type=bind,src="%CD%\input",target=/app/input ^
  --mount type=bind,src="%CD%\output",target=/app/output ^
  --mount type=bind,src="%CD%\temp",target=/app/temp ^
  --env OCAP_RENDER_MAX_SIZE=32768 ^
  --memory=%OCAP_RENDER_DOCKER_MEMORY% ^
  ocap-renderterrain:latest

exit /b %errorlevel%
