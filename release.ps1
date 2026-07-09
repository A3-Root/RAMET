# RAMET release wrapper.
# Builds the native DLL chains (grad_meh Conan/CMake/Ninja, arma3MapExporter dotnet AOT
# publish), then runs a single `hemtt check` + `hemtt release` at the repo root.
# @root_amet is the only mod produced — its post_build hook stages the FlatDevil
# marker, ramet/ + ocap_renderterrain python packages, docs/tools/batch, and all
# four native DLLs into the PBO output. releases\root_amet-{ver}.zip is the deliverable.

[CmdletBinding()]
param(
    [switch]$SkipSubprojects,
    [switch]$Clean,
    [switch]$RebuildGradMehDll,
    [string]$VsDevCmd = $env:RAMET_VSDEVCMD,
    [string]$VcVarsVer = "14.44.35207"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$CheckArgs = @("check", "-p", "-Lc14", "-e")

function Resolve-VsDevCmd {
    param([string]$PreferredPath)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($PreferredPath) { $candidates.Add($PreferredPath) }

    $commonRoots = @(
        "C:\Program Files\Microsoft Visual Studio\2022",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022"
    )
    $editions = @("Community", "Professional", "Enterprise", "BuildTools")
    foreach ($rootPath in $commonRoots) {
        foreach ($edition in $editions) {
            $candidates.Add((Join-Path $rootPath "$edition\Common7\Tools\VsDevCmd.bat"))
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    return $null
}

function Test-CommandPresent {
    param(
        [string]$Name,
        [switch]$Required
    )

    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        return $true
    }

    if ($Required) {
        throw "Required command '$Name' is not on PATH."
    }

    return $false
}

function Find-GradMehDll {
    param([string]$Repo)
    $dll = Join-Path $Repo "build\lib64\grad_meh_x64.dll"
    if (Test-Path $dll) { return $dll }
    return $null
}

function Find-A3meDll {
    param([string]$Repo)
    $dll = Join-Path $Repo "publish\MapExportExtension_x64.dll"
    if (Test-Path $dll) { return $dll }
    return $null
}

function Write-PreflightReport {
    param(
        [string]$ResolvedVsDevCmd
    )

    $issues = New-Object System.Collections.Generic.List[string]
    $notes = New-Object System.Collections.Generic.List[string]

    if (-not (Test-CommandPresent -Name "hemtt")) { $issues.Add("hemtt is not on PATH.") }

    if (-not $ResolvedVsDevCmd) {
        $issues.Add("VsDevCmd.bat was not found. Set RAMET_VSDEVCMD or pass -VsDevCmd.")
    } else {
        $notes.Add("Using VsDevCmd.bat at '$ResolvedVsDevCmd'.")
    }

    $vsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsInstaller)) {
        $notes.Add("vswhere.exe was not found at '$vsInstaller'; .NET AOT linking may fail if the Visual Studio Installer is absent.")
    }

    $gradRepo = Join-Path $root "subprojects\grad_meh"
    $a3meRepo = Join-Path $root "subprojects\arma3MapExporter"

    $gradDll = Find-GradMehDll -Repo $gradRepo
    $a3meDll = Find-A3meDll -Repo $a3meRepo

    if (-not (Test-Path (Join-Path $root ".hemtt\project.toml"))) {
        $issues.Add(".hemtt\\project.toml is missing at the repository root.")
    }

    if ($SkipSubprojects) {
        if (-not $gradDll) { $issues.Add("subprojects\\grad_meh\\build\\lib64\\grad_meh_x64.dll is missing, but -SkipSubprojects was set.") }
        if (-not $a3meDll) { $issues.Add("subprojects\\arma3MapExporter\\publish\\MapExportExtension_x64.dll is missing, but -SkipSubprojects was set.") }
    } else {
        if (-not $gradDll -or $RebuildGradMehDll) {
            if (-not (Test-CommandPresent -Name "conan")) { $issues.Add("conan is required to build grad_meh_x64.dll.") }
            if (-not (Test-CommandPresent -Name "cmake")) { $issues.Add("cmake is required to build grad_meh_x64.dll.") }
            if (-not (Test-CommandPresent -Name "ninja")) { $issues.Add("ninja is required to build grad_meh_x64.dll.") }
            if (-not (Test-CommandPresent -Name "cargo")) { $issues.Add("cargo is required to build grad_meh_x64.dll.") }
        }

        if (-not (Test-CommandPresent -Name "dotnet")) { $issues.Add("dotnet SDK is required to build @arma3MapExporter.") }
        if (-not $ResolvedVsDevCmd) { $issues.Add("VsDevCmd.bat is required to build @arma3MapExporter.") }
    }

    Write-Host "=== preflight ===" -ForegroundColor Cyan
    foreach ($note in $notes) {
        Write-Host "  note: $note" -ForegroundColor DarkGray
    }

    if ($issues.Count -gt 0) {
        Write-Host "  blocking issues:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
        throw "Preflight failed. Fix the blocking issues above, then re-run release.ps1."
    }

    Write-Host "  all required build tools and local project files were found." -ForegroundColor Green
}

if (-not $VsDevCmd) {
    $VsDevCmd = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
}

$VsDevCmd = Resolve-VsDevCmd -PreferredPath $VsDevCmd
Write-PreflightReport -ResolvedVsDevCmd $VsDevCmd

if ($Clean) {
    Get-ChildItem -Path `
        "subprojects\arma3MapExporter\publish", `
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

function Build-Arma3MapExporter {
    # dotnet publish (native AOT) -> subprojects\arma3MapExporter\publish\MapExportExtension_x64.dll.
    # The addons that used to ship alongside it now live in root addons\a3me_main / a3me_exporter,
    # built as part of the single root `hemtt release` below.
    param([string]$Repo)
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet SDK not on PATH — @arma3MapExporter DLL will not be rebuilt."
        return $false
    }
    $csproj = Join-Path $Repo "MapExportExtension\MapExportExtension.csproj"
    $publishDir = Join-Path $Repo "publish"
    if (-not (Test-Path $csproj)) {
        Write-Warning "$csproj not found — skipping arma3MapExporter build."
        return $false
    }

    Write-Host "  > dotnet publish $csproj -> $publishDir" -ForegroundColor DarkGray
    # PublishAot chains MSVC link.exe via vswhere.exe (Visual Studio Installer dir).
    # PATH usually lacks both, so wrap the publish in VsDevCmd.bat — same trick
    # Build-GradMehDll uses for its CMake/Ninja chain.
    if (-not (Test-Path $VsDevCmd)) {
        Write-Warning "VsDevCmd.bat not found at '$VsDevCmd' — needed for AOT link. Set -VsDevCmd or env RAMET_VSDEVCMD."
        return $false
    }
    $vsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer"
    $publishScript = @"
@echo off
set "PATH=$vsInstaller;%PATH%"
call "$VsDevCmd" -arch=x64 -host_arch=x64 -vcvars_ver=$VcVarsVer || exit /b 1
dotnet publish "$csproj" -r win-x64 -c Release -o "$publishDir" || exit /b 1
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
        return $false
    }
    return (Test-Path (Join-Path $publishDir "MapExportExtension_x64.dll"))
}

if (-not $SkipSubprojects) {
    $gradRepo = Join-Path $root "subprojects\grad_meh"
    $gradDll = Find-GradMehDll -Repo $gradRepo
    if ($RebuildGradMehDll -or -not $gradDll) {
        Write-Host "=== building grad_meh native DLL (Conan + CMake + Ninja) ===" -ForegroundColor Cyan
        if (-not (Build-GradMehDll -Repo $gradRepo)) {
            throw "grad_meh DLL build failed — re-run with -RebuildGradMehDll or build it manually."
        }
    }

    Write-Host "=== building arma3MapExporter native DLL (dotnet AOT publish) ===" -ForegroundColor Cyan
    if (-not (Build-Arma3MapExporter -Repo (Join-Path $root "subprojects\arma3MapExporter"))) {
        Write-Warning "arma3MapExporter DLL build failed — @root_amet will bundle without it (in-game export unavailable)."
    }
}

Write-Host "=== building RAMET ===" -ForegroundColor Cyan
Write-Host "  > hemtt $($CheckArgs -join ' ')" -ForegroundColor DarkGray
& hemtt @CheckArgs
if ($LASTEXITCODE -ne 0) { throw "hemtt check failed (exit $LASTEXITCODE) — release skipped" }
Write-Host "  > hemtt release" -ForegroundColor DarkGray
& hemtt release
if ($LASTEXITCODE -ne 0) { throw "hemtt release failed (exit $LASTEXITCODE)" }

$verZip = Get-ChildItem -Path (Join-Path $root "releases") -Filter "root_amet-*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notlike "*-latest*" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ""
if ($verZip) {
    Write-Host "Release ready:" -ForegroundColor Green
    Write-Host "  $($verZip.FullName)"
} else {
    Write-Warning "hemtt release completed but no releases\root_amet-*.zip was found."
}
