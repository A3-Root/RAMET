# RAMET release wrapper.
# Runs `hemtt release` in each subproject + RAMET root, then repackages the final
# zip so @grad_meh / @ocap_renderterrain / @root_amet sit as siblings in the bundle
# (HEMTT's own zip only contains @root_amet content; this wrapper adds the rest).

[CmdletBinding()]
param(
    [switch]$SkipSubprojects,
    [switch]$Clean,
    [switch]$RebuildGradMehDll,
    [string]$VsDevCmd = $env:RAMET_VSDEVCMD,
    [string]$VcVarsVer = "14.44.35207"
)

if (-not $VsDevCmd) {
    $VsDevCmd = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
}

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$CheckArgs = @("check", "-p", "-Lc14", "-e")

function Invoke-Hemtt {
    param([string]$Dir)
    Push-Location $Dir
    try {
        Write-Host "  > hemtt $($CheckArgs -join ' ')" -ForegroundColor DarkGray
        & hemtt @CheckArgs
        if ($LASTEXITCODE -ne 0) { throw "hemtt check failed in $Dir (exit $LASTEXITCODE) — release skipped" }
        Write-Host "  > hemtt release" -ForegroundColor DarkGray
        & hemtt release
        if ($LASTEXITCODE -ne 0) { throw "hemtt release failed in $Dir (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

if ($Clean) {
    Get-ChildItem -Path `
        "subprojects\grad_meh\.hemttout", `
        "subprojects\ocap-renderterrain\.hemttout", `
        "subprojects\arma3MapExporter\@arma3MapExporter\.hemttout", `
        "subprojects\arma3MapExporter\@arma3MapExporter\addons\*\*.pbo", `
        ".hemttout", "releases" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}

function Build-GradMehDll {
    param([string]$Repo)
    if (-not (Test-Path $VsDevCmd)) {
        Write-Warning "VsDevCmd.bat not found at '$VsDevCmd'. Set -VsDevCmd or env RAMET_VSDEVCMD. Skipping grad_meh DLL build."
        return $false
    }
    # Run the full Conan + CMake chain inside one cmd.exe so VsDevCmd env vars persist.
    $script = @"
@echo off
call "$VsDevCmd" -arch=x64 -host_arch=x64 -vcvars_ver=$VcVarsVer || exit /b 1
cd /d "$Repo" || exit /b 1
if exist build rmdir /s /q build
conan install . -s build_type=Release --output-folder=build --build=missing -c tools.cmake.cmaketoolchain:generator=Ninja --profile:host=./ci-conan-profile --profile:build=./ci-conan-profile --lockfile=conan.lock || exit /b 1
if not exist build\ninja-release-win mkdir build\ninja-release-win
cmake --preset ninja-release-win || exit /b 1
cmake --build --preset ninja-msvc-release || exit /b 1
exit /b 0
"@
    $tmp = New-TemporaryFile
    $bat = "$($tmp.FullName).bat"
    Move-Item -Path $tmp.FullName -Destination $bat -Force
    Set-Content -Path $bat -Value $script -Encoding ASCII
    try {
        & cmd /c $bat
        return ($LASTEXITCODE -eq 0)
    } finally {
        Remove-Item $bat -Force -ErrorAction SilentlyContinue
    }
}

function Find-GradMehDll {
    param([string]$Repo)
    $dll = Join-Path $Repo "build\lib64\grad_meh_x64.dll"
    if (Test-Path $dll) { return $dll }
    return $null
}

function Build-Arma3MapExporter {
    # Two-stage build (matches upstream build.ps1):
    #   1) dotnet publish -> MapExportExtension_x64.dll into @arma3MapExporter\
    #   2) hemtt release  (inside @arma3MapExporter\) -> packed PBOs into .hemttout\release\
    # Returns the path to the .hemttout\release\@arma3MapExporter dir on success, else $null.
    param([string]$Repo)
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet SDK not on PATH — @arma3MapExporter will not be rebuilt."
        return $null
    }
    $csproj = Join-Path $Repo "MapExportExtension\MapExportExtension.csproj"
    $modDir = Join-Path $Repo "@arma3MapExporter"
    if (-not (Test-Path $csproj)) {
        Write-Warning "$csproj not found — skipping arma3MapExporter build."
        return $null
    }
    if (-not (Test-Path (Join-Path $modDir ".hemtt\project.toml"))) {
        Write-Warning "$modDir\.hemtt\project.toml missing — cannot run hemtt release."
        return $null
    }

    Write-Host "  > dotnet publish $csproj -> $modDir" -ForegroundColor DarkGray
    # PublishAot in this project chains MSVC link.exe via vswhere.exe (Visual Studio
    # Installer dir). PATH usually lacks both, so wrap the publish in VsDevCmd.bat —
    # same trick Build-GradMehDll uses for its CMake/Ninja chain.
    if (-not (Test-Path $VsDevCmd)) {
        Write-Warning "VsDevCmd.bat not found at '$VsDevCmd' — needed for AOT link. Set -VsDevCmd or env RAMET_VSDEVCMD."
        return
    }
    # The AOT toolchain shells out to `vswhere.exe` to discover MSVC link.exe.
    # vswhere ships with the VS Installer, which is NOT added to PATH by VsDevCmd.
    # Prepend the installer dir so AOT linking works on a stock dev box.
    $vsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer"
    $publishScript = @"
@echo off
set "PATH=$vsInstaller;%PATH%"
call "$VsDevCmd" -arch=x64 -host_arch=x64 -vcvars_ver=$VcVarsVer || exit /b 1
dotnet publish "$csproj" -r win-x64 -c Release -o "$modDir" || exit /b 1
exit /b 0
"@
    $tmp = New-TemporaryFile
    $bat = "$($tmp.FullName).bat"
    Move-Item -Path $tmp.FullName -Destination $bat -Force
    Set-Content -Path $bat -Value $publishScript -Encoding ASCII
    try {
        & cmd /c $bat | Out-Host
        $publishRc = $LASTEXITCODE
    } finally { Remove-Item $bat -Force -ErrorAction SilentlyContinue }
    if ($publishRc -ne 0) {
        Write-Warning "dotnet publish failed for $csproj (exit $publishRc)."
        return
    }

    # HEMTT must run from the mod root (where .hemtt/ lives).
    Push-Location $modDir
    $hemttOk = $false
    try {
        Write-Host "  > hemtt $($CheckArgs -join ' ')  (in $modDir)" -ForegroundColor DarkGray
        & hemtt @CheckArgs | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "hemtt check failed in $modDir (exit $LASTEXITCODE) — release skipped"
        } else {
            Write-Host "  > hemtt release  (in $modDir)" -ForegroundColor DarkGray
            & hemtt release | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "hemtt release failed in $modDir (exit $LASTEXITCODE)"
            } else {
                $hemttOk = $true
            }
        }
    } finally { Pop-Location }

    if (-not $hemttOk) { return }

    $candidates = @(
        (Join-Path $modDir ".hemttout\release\@arma3MapExporter"),
        (Join-Path $modDir ".hemttout\release")
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "addons")) {
            # Single output: the resolved path. Anything else would pollute the caller's variable.
            Write-Output $c
            return
        }
    }
    Write-Warning "hemtt release produced no recognisable @arma3MapExporter tree under $modDir\.hemttout"
}

$a3meReleaseDir = $null
if (-not $SkipSubprojects) {
    Write-Host "=== building subprojects/grad_meh ===" -ForegroundColor Cyan
    Invoke-Hemtt "subprojects\grad_meh"
    Write-Host "=== building subprojects/ocap-renderterrain ===" -ForegroundColor Cyan
    Invoke-Hemtt "subprojects\ocap-renderterrain"
    Write-Host "=== building subprojects/arma3MapExporter (dotnet AOT + hemtt release) ===" -ForegroundColor Cyan
    $a3meReleaseDir = Build-Arma3MapExporter -Repo (Join-Path $root "subprojects\arma3MapExporter")
}
if (-not $a3meReleaseDir) {
    # SkipSubprojects path, or previous build attempt — locate prior hemtt release output.
    $a3meCandidates = @(
        (Join-Path $root "subprojects\arma3MapExporter\@arma3MapExporter\.hemttout\release\@arma3MapExporter"),
        (Join-Path $root "subprojects\arma3MapExporter\@arma3MapExporter\.hemttout\release")
    )
    foreach ($c in $a3meCandidates) {
        if (Test-Path (Join-Path $c "addons")) { $a3meReleaseDir = $c; break }
    }
}

Write-Host "=== building RAMET ===" -ForegroundColor Cyan
Invoke-Hemtt $root

# Derive version from the zip HEMTT just produced (root_amet-{ver}.zip, excluding -latest)
$verZip = Get-ChildItem -Path (Join-Path $root "releases") -Filter "root_amet-*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notlike "*-latest*" -and $_.BaseName -notlike "*-bundle*" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($verZip) {
    $ver = $verZip.BaseName -replace '^root_amet-', ''
} else {
    $ver = (Get-Date -Format "yyyyMMdd-HHmmss")
}

$stagingRoot = Join-Path $root "releases\_bundle"
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

# 1) @root_amet — copy what hemtt produced (already contains $FLATDEVIL$, ramet/, docs/, tools/, batch/)
$ramOut = Join-Path $root ".hemttout\release"
if (-not (Test-Path $ramOut)) { throw "Expected $ramOut from hemtt release" }
Copy-Item -Path $ramOut -Destination (Join-Path $stagingRoot "@root_amet") -Recurse

# 2) @grad_meh and @ocap_renderterrain — from each subproject's .hemttout/release.
# @ocap_renderterrain's own bundle hook already plants ocap_renderterrain/ (Docker context)
# and ocap_renderterrain_process.bat inside it — no extra copy needed here.
$gradOut = Join-Path $root "subprojects\grad_meh\.hemttout\release"
$ocapOut = Join-Path $root "subprojects\ocap-renderterrain\.hemttout\release"
if (Test-Path $gradOut) {
    Copy-Item -Path $gradOut -Destination (Join-Path $stagingRoot "@grad_meh") -Recurse

    # Stage the native Intercept plugin DLL produced by the CMake/Conan/Ninja build.
    # Without this DLL, Intercept logs "Client plugin: grad_meh was not found"
    # and every `gradMehExportMap` call fails with
    # "grad_meh native SQF commands are unavailable".
    $gradRepo = Join-Path $root "subprojects\grad_meh"
    $gradDll  = Find-GradMehDll -Repo $gradRepo
    if ($RebuildGradMehDll -or -not $gradDll) {
        Write-Host "=== building grad_meh native DLL (Conan + CMake + Ninja) ===" -ForegroundColor Cyan
        if (-not (Build-GradMehDll -Repo $gradRepo)) {
            throw "grad_meh DLL build failed — re-run with -RebuildGradMehDll or build it manually."
        }
        $gradDll = Find-GradMehDll -Repo $gradRepo
    }
    if ($gradDll) {
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $stagingRoot "@grad_meh\intercept")
        Copy-Item -Path $gradDll -Destination (Join-Path $stagingRoot "@grad_meh\intercept\grad_meh_x64.dll")
        Write-Host "  + staged $gradDll -> @grad_meh\intercept\grad_meh_x64.dll" -ForegroundColor DarkGray
        Copy-Item -Path $gradDll -Destination (Join-Path $stagingRoot "@grad_meh\grad_meh_x64.dll")
        Write-Host "  + staged $gradDll -> @grad_meh\grad_meh_x64.dll" -ForegroundColor DarkGray
    } else {
        Write-Warning "grad_meh_x64.dll still missing after build attempt — bundle will lack native SQF commands."
    }
} else {
    Write-Warning "$gradOut missing — @grad_meh not bundled"
}
if (Test-Path $ocapOut) {
    Copy-Item -Path $ocapOut -Destination (Join-Path $stagingRoot "@ocap_renderterrain") -Recurse
} else {
    Write-Warning "$ocapOut missing — @ocap_renderterrain not bundled"
}

# 3) @arma3MapExporter — packed PBOs from hemtt release + native AOT DLL.
#    Build-Arma3MapExporter ran dotnet publish + hemtt release; result lives in
#    subprojects\arma3MapExporter\@arma3MapExporter\.hemttout\release\(@arma3MapExporter|).
# Coerce to a single string in case a caller leaked extra output into the variable.
if ($a3meReleaseDir -is [array]) {
    $a3meReleaseDir = $a3meReleaseDir | Where-Object { $_ -and (Test-Path (Join-Path $_ "addons") -ErrorAction SilentlyContinue) } | Select-Object -Last 1
}
if ($a3meReleaseDir -and (Test-Path (Join-Path $a3meReleaseDir "addons"))) {
    $a3meDst = Join-Path $stagingRoot "@arma3MapExporter"
    Copy-Item -Path $a3meReleaseDir -Destination $a3meDst -Recurse
    Write-Host "  + staged @arma3MapExporter from $a3meReleaseDir" -ForegroundColor DarkGray

    # HEMTT [files] include lists MapExportExtension_x64.dll, but only if it sat next to
    # project.toml at build time. Re-stage explicitly as a safety net.
    $a3meDll = Join-Path $root "subprojects\arma3MapExporter\@arma3MapExporter\MapExportExtension_x64.dll"
    if ((Test-Path $a3meDll) -and -not (Test-Path (Join-Path $a3meDst "MapExportExtension_x64.dll"))) {
        Copy-Item -Path $a3meDll -Destination (Join-Path $a3meDst "MapExportExtension_x64.dll")
        Write-Host "  + staged MapExportExtension_x64.dll" -ForegroundColor DarkGray
    }
    if (-not (Test-Path (Join-Path $a3meDst "MapExportExtension_x64.dll"))) {
        Write-Warning "MapExportExtension_x64.dll missing in @arma3MapExporter bundle — extension calls will fail."
    }
} else {
    Write-Warning "no hemtt release output for @arma3MapExporter found — not bundled. Re-run without -SkipSubprojects with .NET 10 SDK + HEMTT installed."
}

# 4) Zip the bundle
$outZip = Join-Path $root "releases\root_amet-$ver-bundle.zip"
$latestZip = Join-Path $root "releases\root_amet-latest-bundle.zip"
if (Test-Path $outZip) { Remove-Item $outZip -Force }
if (Test-Path $latestZip) { Remove-Item $latestZip -Force }

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $outZip
if ((Resolve-Path $outZip).Path -ne (Resolve-Path -LiteralPath $latestZip -ErrorAction SilentlyContinue).Path) {
    Copy-Item -Path $outZip -Destination $latestZip -Force
}

Write-Host ""
Write-Host "Bundle ready:" -ForegroundColor Green
Write-Host "  $outZip"
Write-Host "  $latestZip"
Write-Host ""
Write-Host "Staging tree:" -ForegroundColor Green
Get-ChildItem $stagingRoot | Format-Table Name, Length, LastWriteTime -AutoSize
