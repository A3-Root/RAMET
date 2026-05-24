@echo off
setlocal EnableExtensions

set "MODE=%~1"
if "%MODE%"=="" set "MODE=build"

if /I not "%MODE%"=="build" if /I not "%MODE%"=="release" (
    echo Usage: %~nx0 [build^|release]
    exit /b 2
)

pushd "%~dp0.." || exit /b 1

if /I "%MODE%"=="release" (
    call hemtt release
) else (
    call hemtt build
)
if errorlevel 1 goto :fail

echo HEMTT %MODE% completed. The post_build hook bundled the Archangel runtime files.
popd
exit /b 0

:fail
set "CODE=%ERRORLEVEL%"
popd
exit /b %CODE%
