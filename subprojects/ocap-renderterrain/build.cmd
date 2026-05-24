@echo off
setlocal EnableExtensions

set "MODE=%~1"
if "%MODE%"=="" set "MODE=build"

call "%~dp0tools\hemtt-package.cmd" "%MODE%"
set "CODE=%ERRORLEVEL%"

if "%CODE%"=="0" (
    echo.
    echo Output:
    if /I "%MODE%"=="release" (
        echo   releases\ocap_renderterrain-latest.zip
        echo   .hemttout\release
    ) else (
        echo   .hemttout\build
    )
)

echo.
pause
exit /b %CODE%
