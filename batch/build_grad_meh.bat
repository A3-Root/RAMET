@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Build grad_meh C++ plugin and deploy grad_meh_x64.dll to @grad_meh\intercept\.
rem
rem Requires:
rem   - Visual Studio 2022 with MSVC C++ workload (or run from a VS Developer prompt)
rem   - CMake 3.28+, Ninja, Conan 2.x, Rust (rustup)
rem
rem DLL source: subprojects\grad_meh\build\lib64\grad_meh_x64.dll
rem DLL dest:   <Arma3>\@grad_meh\intercept\grad_meh_x64.dll

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul

set "GRAD_DIR=%RAMET_ROOT%\subprojects\grad_meh"
set "DLL_SRC=%GRAD_DIR%\build\lib64\grad_meh_x64.dll"

rem ---- locate Arma 3 (registry first, then path fallback) ----
set "ARMA_ROOT="
for /f "tokens=2*" %%A in (
    'reg query "HKLM\SOFTWARE\WOW6432Node\Bohemia Interactive\arma 3" /v main 2^>nul'
) do set "ARMA_ROOT=%%B"

if not defined ARMA_ROOT (
    set "ARMA_ROOT=G:\Games\Steam\steamapps\common\Arma 3"
    echo [INFO] Registry lookup failed, using hardcoded Arma root: %ARMA_ROOT%
)

set "DLL_DST=%ARMA_ROOT%\@grad_meh\intercept"

echo RAMET root : %RAMET_ROOT%
echo Arma root  : %ARMA_ROOT%
echo DLL source : %DLL_SRC%
echo DLL dest   : %DLL_DST%
echo.

rem ---- activate VS 2022 x64 environment ----
where cl >nul 2>nul
if not errorlevel 1 goto :check_atl

for %%E in (Enterprise Professional Community BuildTools) do (
    set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvarsall.bat"
    if exist "!VCVARS!" (
        echo [INFO] activating VS 2022 %%E x64
        call "!VCVARS!" x64
        goto :check_atl
    )
)
echo [ERR] VS 2022 MSVC not found. Install VS 2022 with C++ workload,
echo       or open a VS 2022 x64 Developer Command Prompt and re-run.
exit /b 1

:check_atl
rem If the default toolset has no ATL (e.g. 14.42 selected over 14.44),
rem find the newest installed toolset that does and re-activate with it.
set "ATL_OK="
if defined VCToolsInstallDir (
    if exist "%VCToolsInstallDir%atlmfc\lib\x64\atls.lib"         set "ATL_OK=1"
    if exist "%VCToolsInstallDir%atlmfc\lib\spectre\x64\atls.lib" set "ATL_OK=1"
)
if not defined ATL_OK call :find_atl_toolset
if not defined ATL_OK (
    echo [ERR] ATL ^(atls.lib^) not found in any installed MSVC toolset.
    echo       VS Installer ^> Modify ^> Individual Components ^>
    echo           "C++ ATL for latest v143 build tools ^(x86 ^& x64^)"
    exit /b 1
)
goto :env_ready

:find_atl_toolset
for %%E in (Enterprise Professional Community BuildTools) do (
    set "_MSVC=C:\Program Files\Microsoft Visual Studio\2022\%%E\VC\Tools\MSVC"
    if exist "!_MSVC!" (
        for /f "tokens=*" %%T in ('dir /b /o-n "!_MSVC!" 2^>nul') do (
            if not defined ATL_OK (
                if exist "!_MSVC!\%%T\atlmfc\lib\x64\atls.lib" (
                    echo [INFO] re-activating with MSVC %%T ^(has ATL^)
                    call "C:\Program Files\Microsoft Visual Studio\2022\%%E\VC\Auxiliary\Build\vcvarsall.bat" x64 -vcvars_ver=%%T
                    set "ATL_OK=1"
                )
            )
        )
    )
)
goto :eof

:env_ready
rem ---- verify required tools ----
where conan  >nul 2>nul || ( echo [ERR] conan not on PATH.  & exit /b 1 )
where cmake  >nul 2>nul || ( echo [ERR] cmake not on PATH.  & exit /b 1 )
where ninja  >nul 2>nul || ( echo [ERR] ninja not on PATH.  & exit /b 1 )
where cargo  >nul 2>nul || ( echo [ERR] cargo not on PATH. Install Rust via rustup. & exit /b 1 )

rem ---- wipe stale build dir ----
if exist "%GRAD_DIR%\build" (
    echo [INFO] removing stale build dir...
    rmdir /s /q "%GRAD_DIR%\build"
)

pushd "%GRAD_DIR%"

rem ---- 1) conan install ----
echo === conan install ===
conan install . --output-folder=build --build=missing --profile=ci-conan-profile -c tools.cmake.cmaketoolchain:generator=Ninja
if errorlevel 1 ( echo [ERR] conan install failed. & popd & exit /b 1 )

rem ---- 2) cmake configure ----
echo.
echo === cmake configure ===
rem vcvarsall sets these VS-generator env vars; Ninja rejects them.
set "CMAKE_GENERATOR_PLATFORM="
set "CMAKE_GENERATOR_TOOLSET="
cmake --preset ninja-release-win
if errorlevel 1 ( echo [ERR] cmake configure failed. & popd & exit /b 1 )

rem ---- 3) cmake build ----
echo.
echo === cmake build ===
cmake --build --preset ninja-msvc-release
if errorlevel 1 ( echo [ERR] cmake build failed. & popd & exit /b 1 )

popd

rem ---- 4) deploy DLL ----
echo.
echo === deploy DLL ===
if not exist "%DLL_SRC%" (
    echo [ERR] DLL not found at %DLL_SRC%
    echo       Check that the build completed successfully.
    exit /b 1
)

if not exist "%DLL_DST%" (
    echo [INFO] creating %DLL_DST%
    md "%DLL_DST%"
)

copy /Y "%DLL_SRC%" "%DLL_DST%\grad_meh_x64.dll"
if errorlevel 1 ( echo [ERR] copy failed. & exit /b 1 )

echo.
echo === done ===
echo grad_meh_x64.dll deployed to %DLL_DST%
echo Run Arma 3 with @grad_meh + @intercept + @CBA_A3, then re-export your maps.

endlocal
