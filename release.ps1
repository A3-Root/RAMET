# RAMET release wrapper.
# Builds the native DLL chains (grad_meh Conan/CMake/Ninja, arma3MapExporter dotnet AOT
# publish, ocap_exporter Go/cgo + gcc), then runs a single `hemtt check` + `hemtt release`
# at the repo root. @root_amet is the only mod produced — its post_build hook stages the
# FlatDevil marker, ramet/ python package, docs/tools/batch, and
# all four native DLLs (three built here, plus the vendored intercept_x64.dll) into the
# PBO output. releases\root_amet-{ver}.zip is the deliverable.

[CmdletBinding()]
param(
    [switch]$SkipSubprojects,
    [switch]$Clean,
    [switch]$RebuildGradMehDll,
    [switch]$NoClean,
    [switch]$NoRebuildGradMehDll,
    [string]$VsDevCmd = $env:RAMET_VSDEVCMD,
    [string]$VcVarsVer = "14.44.35207"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$Clean = -not $NoClean
if ($PSBoundParameters.ContainsKey("Clean")) { $Clean = $true }

$RebuildGradMehDll = -not $NoRebuildGradMehDll
if ($PSBoundParameters.ContainsKey("RebuildGradMehDll")) { $RebuildGradMehDll = $true }

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

function Test-RequiredPath {
    param(
        [string]$Path,
        [string]$Description,
        [System.Collections.Generic.List[string]]$Issues
    )

    if (-not (Test-Path $Path)) {
        $Issues.Add("$Description is missing at '$Path'.")
    }
}

function Add-ProcessPath {
    param([string]$Path)

    if (-not (Test-Path $Path -PathType Container)) { return }
    $entries = @($env:Path -split ';' | Where-Object { $_ })
    if ($entries -notcontains $Path) {
        $env:Path = "$Path;$env:Path"
    }
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($machinePath -or $userPath) {
        $env:Path = (($machinePath, $userPath | Where-Object { $_ }) -join ';')
    }

    $knownDirectories = @(
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\Git\bin",
        "$env:ProgramFiles\Docker\Docker\resources\bin",
        "$env:ProgramFiles\Go\bin",
        "$env:ProgramFiles\CMake\bin",
        "$env:USERPROFILE\.cargo\bin",
        "$env:USERPROFILE\.conan2\bin",
        "$env:USERPROFILE\scoop\shims",
        "$env:USERPROFILE\scoop\apps\hemtt\current",
        "$env:LOCALAPPDATA\Programs\HEMTT",
        "C:\ProgramData\chocolatey\bin",
        "$env:APPDATA\Python\Python312\Scripts",
        "$env:APPDATA\Python\Python311\Scripts",
        "C:\msys64\mingw64\bin"
    )
    foreach ($directory in $knownDirectories) {
        Add-ProcessPath -Path $directory
    }

    Get-ChildItem "$env:APPDATA\Python" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Add-ProcessPath -Path (Join-Path $_.FullName "Scripts") }
}

function Invoke-WingetInstall {
    param(
        [string]$Name,
        [string]$Id,
        [string]$InstallHint,
        [string[]]$ExtraArguments = @()
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not available. Install $Name manually: $InstallHint"
        return $false
    }

    $answer = Read-Host "Install $Name now with winget? [Y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Warning "Skipped $Name. Install it manually: $InstallHint"
        return $false
    }

    Write-Host "=== installing $Name ===" -ForegroundColor Cyan
    $arguments = @(
        "install", "--id", $Id, "--exact",
        "--accept-source-agreements", "--accept-package-agreements"
    ) + $ExtraArguments
    & winget @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "winget could not install $Name (exit $LASTEXITCODE). Install it manually: $InstallHint"
        return $false
    }

    Refresh-ProcessPath
    return $true
}

function Start-DockerIfInstalled {
    Refresh-ProcessPath

    $desktopCandidates = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )
    $desktop = $desktopCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not (Get-Command docker -ErrorAction SilentlyContinue) -and $desktop) {
        Add-ProcessPath -Path (Split-Path $desktop -Parent)
        Add-ProcessPath -Path (Join-Path (Split-Path $desktop -Parent) "resources\bin")
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue) -and -not $desktop) {
        Invoke-WingetInstall -Name "Docker Desktop" -Id "Docker.DockerDesktop" -InstallHint "https://www.docker.com/products/docker-desktop/" | Out-Null
        Refresh-ProcessPath
        $desktop = $desktopCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return
    }

    & docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if ($desktop) {
        Write-Host "Docker Desktop is installed but not running. Starting it..." -ForegroundColor Yellow
        try {
            Start-Process -FilePath $desktop
        } catch {
            Write-Warning "Docker Desktop could not be started automatically: $($_.Exception.Message)"
            return
        }
        $deadline = (Get-Date).AddSeconds(60)
        do {
            Start-Sleep -Seconds 2
            & docker info *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Docker is ready." -ForegroundColor Green
                return
            }
        } while ((Get-Date) -lt $deadline)
    }

    Write-Warning "Docker is installed but its daemon is not ready. Start Docker Desktop, wait until it is ready, then run release.ps1 again."
}

function Install-Msys2Gcc {
    Refresh-ProcessPath
    if (Get-Command gcc -ErrorAction SilentlyContinue) { return $true }

    $msysRoot = "C:\msys64"
    $pacman = Join-Path $msysRoot "usr\bin\pacman.exe"
    if (-not (Test-Path $pacman)) {
        $installed = Invoke-WingetInstall -Name "MSYS2" -Id "MSYS2.MSYS2" -InstallHint "https://www.msys2.org/"
        if (-not $installed) { return $false }
    }

    Refresh-ProcessPath
    $pacman = Join-Path $msysRoot "usr\bin\pacman.exe"
    if (-not (Test-Path $pacman)) {
        Write-Warning "MSYS2 was installed, but pacman.exe was not found at '$pacman'. Open MSYS2 once, then run release.ps1 again."
        return $false
    }

    $answer = Read-Host "Install the MinGW-w64 GCC package required by the OCAP cgo build? [Y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Warning "Skipped MinGW-w64 GCC. Install it in the MSYS2 UCRT64 or MinGW64 environment, then add C:\msys64\mingw64\bin to PATH."
        return $false
    }

    & $pacman -S --needed --noconfirm mingw-w64-x86_64-gcc | Out-Host
    Refresh-ProcessPath
    return [bool](Get-Command gcc -ErrorAction SilentlyContinue)
}

function Repair-MissingDependencies {
    Refresh-ProcessPath

    # Docker is special: an installed desktop application may have no CLI on
    # PATH, and its daemon must be running before preflight can continue.
    Start-DockerIfInstalled

    $toolSpecs = @(
        @{ Command = "git"; Name = "Git"; Id = "Git.Git"; Hint = "https://git-scm.com/download/win" },
        @{ Command = "bash"; Name = "Git Bash"; Id = "Git.Git"; Hint = "https://git-scm.com/download/win" },
        @{ Command = "python"; Name = "Python 3"; Id = "Python.Python.3.12"; Hint = "https://www.python.org/downloads/windows/" },
        @{ Command = "hemtt"; Name = "HEMTT"; Id = $null; Hint = "https://github.com/BrettMayson/HEMTT/releases" }
    )
    if (-not $SkipSubprojects) {
        $toolSpecs += @(
            @{ Command = "go"; Name = "Go"; Id = "GoLang.Go"; Hint = "https://go.dev/dl/" },
            @{ Command = "cmake"; Name = "CMake"; Id = "Kitware.CMake"; Hint = "https://cmake.org/download/" },
            @{ Command = "ninja"; Name = "Ninja"; Id = "Ninja-build.Ninja"; Hint = "https://github.com/ninja-build/ninja/releases" },
            @{ Command = "cargo"; Name = "Rust"; Id = "Rustlang.Rustup"; Hint = "https://rustup.rs/" },
            @{ Command = "dotnet"; Name = ".NET SDK"; Id = "Microsoft.DotNet.SDK.10"; Hint = "https://dotnet.microsoft.com/download/dotnet/10.0" }
        )
    }

    foreach ($spec in $toolSpecs) {
        Refresh-ProcessPath
        if (Get-Command $spec.Command -ErrorAction SilentlyContinue) { continue }
        if ($spec.Id) {
            Invoke-WingetInstall -Name $spec.Name -Id $spec.Id -InstallHint $spec.Hint | Out-Null
        } else {
            Write-Warning "$($spec.Name) was not found on PATH. Install it from $($spec.Hint), then run release.ps1 again."
        }
    }

    if (-not $SkipSubprojects) {
        Refresh-ProcessPath
        if (-not (Get-Command conan -ErrorAction SilentlyContinue) -and (Get-Command python -ErrorAction SilentlyContinue)) {
            $answer = Read-Host "Install Conan with Python pip? [Y/N]"
            if ($answer -match '^(y|yes)$') {
                & python -m pip install --user conan | Out-Host
                Refresh-ProcessPath
            } else {
                Write-Warning "Skipped Conan. Install it with 'python -m pip install --user conan'."
            }
        }

        Install-Msys2Gcc | Out-Null
        Refresh-ProcessPath
    }

    if (-not $SkipSubprojects -and -not $VsDevCmd) {
        $vsAnswer = Read-Host "Visual Studio 2022 C++ tools were not found. Install the Build Tools with winget? [Y/N]"
        if ($vsAnswer -match '^(y|yes)$' -and (Get-Command winget -ErrorAction SilentlyContinue)) {
            Invoke-WingetInstall -Name "Visual Studio 2022 Build Tools" `
                -Id "Microsoft.VisualStudio.2022.BuildTools" `
                -InstallHint "https://visualstudio.microsoft.com/visual-cpp-build-tools/" `
                -ExtraArguments @("--override", "--wait --passive --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended") | Out-Null
            $script:VsDevCmd = Resolve-VsDevCmd -PreferredPath $VsDevCmd
        } else {
            Write-Warning "Visual Studio 2022 C++ tools were not found. Install them from https://visualstudio.microsoft.com/visual-cpp-build-tools/"
        }
    }
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

function Find-OcapExporterDll {
    param([string]$Repo)
    $dll = Join-Path $Repo "ocap_exporter_x64.dll"
    if (Test-Path $dll) { return $dll }
    return $null
}

function Write-PreflightReport {
    param(
        [string]$ResolvedVsDevCmd
    )

    $issues = New-Object System.Collections.Generic.List[string]
    $notes = New-Object System.Collections.Generic.List[string]

    foreach ($cmd in @("hemtt", "docker", "git", "bash", "python")) {
        if (-not (Test-CommandPresent -Name $cmd)) {
            $issues.Add("Required command '$cmd' is not on PATH.")
        }
    }

    if (-not $SkipSubprojects) {
        if (-not (Test-CommandPresent -Name "go")) {
            $issues.Add("Required command 'go' is missing for ocap_exporter_x64.dll.")
        }
        if (-not (Test-CommandPresent -Name "gcc")) {
            $issues.Add("Required command 'gcc' is missing for ocap_exporter_x64.dll. Go cgo is enabled; install a Windows MinGW-w64/MSYS2 GCC toolchain and add its bin directory to PATH.")
        }
    }

    if ($SkipSubprojects) {
        if ($ResolvedVsDevCmd) {
            $notes.Add("Using VsDevCmd.bat at '$ResolvedVsDevCmd'.")
        } else {
            $notes.Add("VsDevCmd.bat not found; native rebuilds are being skipped.")
        }
    } elseif (-not $ResolvedVsDevCmd) {
        $issues.Add("VsDevCmd.bat was not found. Set RAMET_VSDEVCMD or pass -VsDevCmd.")
    } else {
        $notes.Add("Using VsDevCmd.bat at '$ResolvedVsDevCmd'.")
    }

    if (Test-CommandPresent -Name "docker") {
        & docker info *> $null
        if ($LASTEXITCODE -ne 0) {
            $issues.Add("Docker is on PATH but the daemon is not reachable. Start Docker Desktop and retry.")
        }
    }

    $requiredPaths = @(
        @(".hemtt\project.toml", ".hemtt project"),
        @(".hemtt\hooks\post_build\01_bundle_pipeline.rhai", "post_build bundle hook"),
        @("tools\Dockerfile", "Dockerfile"),
        @("tools\requirements.txt", "Python requirements"),
        @("tools\deploy_to_planner.py", "planner deploy helper"),
        @("tools\orchestrate.py", "post-process orchestrator"),
        @("batch\01_export_grad_meh.bat", "grad_meh batch wrapper"),
        @("batch\02_export_ocap.bat", "ocap batch wrapper"),
        @("batch\03_postprocess.bat", "post-process batch wrapper"),
        @("batch\03_postprocess.sh", "post-process shell wrapper"),
        @("batch\04_deploy.bat", "deploy batch wrapper"),
        @("batch\04_deploy.sh", "deploy shell wrapper"),
        @("batch\05_zip_for_upload.bat", "zip batch wrapper"),
        @("batch\05_zip_for_upload.sh", "zip shell wrapper"),
        @("batch\build_grad_meh.bat", "grad_meh build helper"),
        @("batch\worlds.txt", "world queue file"),
        @("batch\render_worlds.txt", "render filter file"),
        @("ramet", "ramet Python package"),
        @('modules\$FLATDEVIL$', "FlatDevil marker"),
        @("addons\main", "main addon"),
        @("addons\grad_meh_main", "grad_meh main addon"),
        @("addons\grad_meh_ui", "grad_meh UI addon"),
        @("addons\ocap_exporter", "ocap exporter addon"),
        @("addons\ocap_ui", "ocap UI addon"),
        @("addons\a3me_main", "arma3MapExporter main addon"),
        @("addons\a3me_exporter", "arma3MapExporter exporter addon"),
        @("addons\intercept_core", "intercept core addon"),
        @("vendor\intercept\intercept_x64.dll", "vendored intercept DLL"),
        @("subprojects\grad_meh\CMakePresets.json", "grad_meh CMake presets"),
        @("subprojects\grad_meh\conanfile.py", "grad_meh Conan recipe"),
        @("subprojects\grad_meh\ci-conan-profile", "grad_meh Conan profile"),
        @("subprojects\grad_meh\conan.lock", "grad_meh Conan lockfile"),
        @("subprojects\arma3MapExporter\MapExportExtension\MapExportExtension.csproj", "arma3MapExporter project"),
        @("subprojects\ocap-renderterrain\ocap-exporter\go.mod", "ocap exporter module"),
        @("subprojects\ocap-renderterrain\ocap-exporter\build.sh", "ocap exporter cross-build script"),
        @("subprojects\ocap-renderterrain\ocap-renderterrain\Dockerfile", "ocap render Dockerfile"),
        @("subprojects\ocap-renderterrain\ocap_renderterrain_process.bat", "ocap render launcher"),
        @("subprojects\ocap-renderterrain\ocap_renderterrain_process.sh", "ocap render launcher (shell)")
    )

    foreach ($entry in $requiredPaths) {
        Test-RequiredPath -Path (Join-Path $root $entry[0]) -Description $entry[1] -Issues $issues
    }

    if ($SkipSubprojects) {
        $notes.Add("Skipping native DLL rebuilds by request.")
        foreach ($cmd in @("cmake", "conan", "ninja", "cargo", "dotnet")) {
            if (-not (Test-CommandPresent -Name $cmd)) {
                $notes.Add("Required command '$cmd' is missing, but native rebuilds are skipped.")
            }
        }
    } else {
        $gradRepo = Join-Path $root "subprojects\grad_meh"
        $a3meRepo = Join-Path $root "subprojects\arma3MapExporter"

        $ocapRepo = Join-Path $root "subprojects\ocap-renderterrain\ocap-exporter"

        $gradDll = Find-GradMehDll -Repo $gradRepo
        $a3meDll = Find-A3meDll -Repo $a3meRepo
        $ocapDll = Find-OcapExporterDll -Repo $ocapRepo

        if (-not $gradDll) {
            $notes.Add("grad_meh_x64.dll is missing and will be rebuilt from source.")
        }
        if (-not $a3meDll) {
            $notes.Add("MapExportExtension_x64.dll is missing and will be rebuilt from source.")
        }
        if (-not $ocapDll) {
            $notes.Add("ocap_exporter_x64.dll is missing and will be rebuilt from source.")
        }

        if ($RebuildGradMehDll -or -not $gradDll) {
            foreach ($cmd in @("conan", "cmake", "ninja", "cargo")) {
                if (-not (Test-CommandPresent -Name $cmd)) {
                    $issues.Add("Required command '$cmd' is missing for grad_meh_x64.dll.")
                }
            }
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
Repair-MissingDependencies
$VsDevCmd = Resolve-VsDevCmd -PreferredPath $VsDevCmd
Write-PreflightReport -ResolvedVsDevCmd $VsDevCmd

if ($Clean) {
    $cleanPaths = @(".hemttout", "releases")
    if (-not $SkipSubprojects) {
        $cleanPaths += "subprojects\arma3MapExporter\publish"
    }
    Get-ChildItem -Path $cleanPaths -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
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

function Build-OcapExporterDll {
    # go build -buildmode=c-shared -> subprojects\ocap-renderterrain\ocap-exporter\ocap_exporter_x64.dll.
    # CGO_ENABLED=1 means Go also needs a native Windows C compiler (gcc).
    # The Linux cross-build uses explicit MinGW compiler names in build.sh.
    param([string]$Repo)
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Warning "go not on PATH — ocap_exporter_x64.dll will not be rebuilt. Install Go and add it to PATH."
        return $false
    }
    if (-not (Get-Command gcc -ErrorAction SilentlyContinue)) {
        Write-Warning "gcc not on PATH — Go cgo cannot build ocap_exporter_x64.dll. Install MinGW-w64/MSYS2 GCC and add its bin directory to PATH."
        return $false
    }
    Push-Location $Repo
    try {
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "1"
        & go build -o ocap_exporter_x64.dll -buildmode=c-shared .
        $rc = $LASTEXITCODE
    } finally {
        Pop-Location
        Remove-Item Env:\GOARCH -ErrorAction SilentlyContinue
        Remove-Item Env:\CGO_ENABLED -ErrorAction SilentlyContinue
    }
    if ($rc -ne 0) {
        Write-Warning "go build failed for ocap_exporter (exit $rc). Check the Go and gcc output above; this target requires CGO_ENABLED=1 and a working Windows C toolchain."
        return $false
    }
    $dll = Join-Path $Repo "ocap_exporter_x64.dll"
    if (-not (Test-Path $dll)) {
        Write-Warning "go build reported success but did not create '$dll'."
        return $false
    }
    return $true
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

    Write-Host "=== building ocap_exporter native DLL (go build) ===" -ForegroundColor Cyan
    if (-not (Build-OcapExporterDll -Repo (Join-Path $root "subprojects\ocap-renderterrain\ocap-exporter"))) {
        Write-Warning "ocap_exporter DLL build failed — @root_amet will bundle without it (OCAP batch export unavailable)."
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
