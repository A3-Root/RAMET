@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem RAMET step 3 — post-process raw exports into <Arma3>\RAMET_Output\processed\{world}\.
rem
rem Runs entirely in Docker — no host install of tippecanoe / pmtiles / cwebp / etc.
rem   * ocap-rt render :  uses the upstream `ocap_renderterrain_process.bat` (its own Docker image)
rem   * RAMET orchestrate : uses the `ramet-postprocess` image built from tools/Dockerfile
rem
rem Flags:
rem   --skip-ocap    Skip the ocap-rt Docker render (use when tiles already rendered)

set "SKIP_OCAP=0"
for %%A in (%*) do (
    if /I "%%A"=="--skip-ocap" set "SKIP_OCAP=1"
)

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
set "RAMET_ROOT=%CD%"
popd >nul
pushd "%SCRIPT_DIR%..\.." >nul
set "ARMA_ROOT=%CD%"

where docker >nul 2>nul || (
    echo [ERR] docker not on PATH — install Docker Desktop.
    popd & exit /b 1
)

rem -------- 1) ocap-rt Docker render --------
if exist "%ARMA_ROOT%\@root_amet\ocap_renderterrain_process.bat" (
    set "OCAP_BAT=%ARMA_ROOT%\@root_amet\ocap_renderterrain_process.bat"
) else if exist "%RAMET_ROOT%\subprojects\ocap-renderterrain\ocap_renderterrain_process.bat" (
    set "OCAP_BAT=%RAMET_ROOT%\subprojects\ocap-renderterrain\ocap_renderterrain_process.bat"
) else (
    echo [WARN] ocap_renderterrain_process.bat not found — skipping Docker render.
    set "OCAP_BAT="
)

rem -------- Read render_worlds.txt → comma-separated list for ocap-rt --------
set "RENDER_WORLDS_FILE=%SCRIPT_DIR%render_worlds.txt"
set "RENDER_WORLDS="
if exist "%RENDER_WORLDS_FILE%" (
    for /f "usebackq eol=# tokens=*" %%W in ("%RENDER_WORLDS_FILE%") do (
        if not "%%W"=="" (
            if defined RENDER_WORLDS (
                set "RENDER_WORLDS=!RENDER_WORLDS!,%%W"
            ) else (
                set "RENDER_WORLDS=%%W"
            )
        )
    )
)
if defined RENDER_WORLDS (
    echo [render_worlds.txt] Filtering render to: %RENDER_WORLDS%
) else (
    echo [render_worlds.txt] Empty or missing — rendering all worlds.
)

if "%SKIP_OCAP%"=="1" (
    echo [SKIP] ocap-rt render skipped - --skip-ocap passed.
) else if defined OCAP_BAT (
    echo === ocap-rt Docker render ===
    call "%OCAP_BAT%" "%RENDER_WORLDS%"
    if errorlevel 1 echo [WARN] Docker render exited with errors - continuing.
)

rem -------- 2) RAMET orchestrate image (build once, reuse forever) --------
echo === building ramet-postprocess image (cached after first build) ===
docker build -t ramet-postprocess:latest -f "%RAMET_ROOT%\tools\Dockerfile" "%RAMET_ROOT%"
if errorlevel 1 (
    echo [ERR] docker build failed.
    popd & exit /b 1
)

rem -------- 3) Run orchestrate inside the image, mounting Arma 3 root --------
rem Build --world args from RENDER_WORLDS (comma-separated); fall back to --all.
set "ORCHESTRATE_WORLDS=--all"
if defined RENDER_WORLDS (
    set "ORCHESTRATE_WORLDS="
    for %%W in (%RENDER_WORLDS:,= %) do (
        set "ORCHESTRATE_WORLDS=!ORCHESTRATE_WORLDS! --world %%W"
    )
)

echo === orchestrate (merge + pmtiles + slice + optimize + verify) ===
docker run --rm ^
    -v "%ARMA_ROOT%":/work ^
    -e RAMET_ARMA_ROOT=/work ^
    -e PYTHONUNBUFFERED=1 ^
    ramet-postprocess:latest %ORCHESTRATE_WORLDS% --workers 2 --optimize-workers 4
if errorlevel 1 (
    echo [ERR] orchestrate reported failures.
    popd & exit /b 1
)

echo === done. Output at "%ARMA_ROOT%\RAMET_Output\processed". Run 04_deploy.bat to push to planner. ===
popd
endlocal
