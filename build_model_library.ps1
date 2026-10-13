# Builds the planner's 3D model library from the modpack and zips it for upload.
#
# The web planner is a separate, isolated server: it cannot reach the game or
# the modpack, and the only channel into it is the Zeus "Export to Web Planner"
# push. Arma itself cannot read p3d geometry, so mission objects would render as
# bounding boxes forever. This script runs on the machine that *has* the
# modpack, reads the models straight out of the PBOs (no unpacking, no Arma
# running), and produces one drop-in zip:
#
#   models3d/library.sqlite   the library the planner serves
#   models3d/manifest.json    what it was built from, for verification
#
# Extract that into the planner's data directory and restart it.
#
# Re-run after every modpack update. -Update only touches models that are new
# or whose PBO changed, which is the cheap path.

[CmdletBinding()]
param(
    # Extra or replacement mod directories. Without this the list below is used.
    [string[]]$ModRoot = @(),
    [switch]$Update,
    [switch]$SkipZip,
    [switch]$RebuildTool,
    [string]$Arma3Root,
    [string]$OutputDir,
    [double]$MaxZipGb = 5.0,
    [string]$VsDevCmd = $env:RAMET_VSDEVCMD,
    [string]$VcVarsVer = "14.44.35207"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# ----------------------------------------------------------------------------
# The one line to edit when a mod is added to the modpack.
# ----------------------------------------------------------------------------
$DefaultModFolders = @(
    "@77th_core",
    "@77th_maps",
    "@77th_ops",
    "@77th_optional",
    "@77th_unit"
)

$logPath = Join-Path $root "build_model_library.log"
Set-Content -Path $logPath -Value "" -Encoding UTF8
$script:TranscriptActive = $false
try {
    Start-Transcript -Path $logPath -Force | Out-Null
    $script:TranscriptActive = $true
} catch {
    Write-Warning "Could not start transcript at '$logPath': $($_.Exception.Message)"
}
trap {
    Write-Host "=== model library build failed: $($_.Exception.Message) ===" -ForegroundColor Red
    if ($script:TranscriptActive) {
        Stop-Transcript | Out-Null
        $script:TranscriptActive = $false
    }
    exit 1
}

function Resolve-Arma3Root {
    param([string]$Preferred)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Preferred) { $candidates.Add($Preferred) }

    foreach ($key in @("HKLM:\SOFTWARE\WOW6432Node\Bohemia Interactive\Arma 3",
                       "HKLM:\SOFTWARE\Bohemia Interactive\Arma 3")) {
        try {
            $value = (Get-ItemProperty -Path $key -Name "main" -ErrorAction Stop).main
            if ($value) { $candidates.Add($value) }
        } catch {
            # Not installed under this key; try the next one.
        }
    }
    $candidates.Add("G:\Games\Steam\steamapps\common\Arma 3")
    $candidates.Add("C:\Program Files (x86)\Steam\steamapps\common\Arma 3")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate -PathType Container)) { return $candidate }
    }
    return $null
}

function Resolve-VsDevCmd {
    param([string]$PreferredPath)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($PreferredPath) { $candidates.Add($PreferredPath) }
    foreach ($rootPath in @("C:\Program Files\Microsoft Visual Studio\2022",
                            "C:\Program Files (x86)\Microsoft Visual Studio\2022")) {
        foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
            $candidates.Add((Join-Path $rootPath "$edition\Common7\Tools\VsDevCmd.bat"))
        }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

function Build-ModelTool {
    param([string]$Repo)

    $resolved = Resolve-VsDevCmd -PreferredPath $VsDevCmd
    if (-not $resolved) {
        throw "VsDevCmd.bat was not found. Set RAMET_VSDEVCMD or pass -VsDevCmd."
    }

    Write-Host "=== building ramet_models ===" -ForegroundColor Cyan
    $gradRepo = Join-Path $Repo "subprojects\grad_meh"
    $script = @"
@echo on
call "$resolved" -arch=x64 -host_arch=x64 -vcvars_ver=$VcVarsVer || exit /b 1
cd /d "$gradRepo" || exit /b 1
cmake --build --preset ninja-msvc-release --target ramet_models || exit /b 1
exit /b 0
"@
    $tmp = New-TemporaryFile
    $bat = "$($tmp.FullName).bat"
    Move-Item -Path $tmp.FullName -Destination $bat -Force
    Set-Content -Path $bat -Value $script -Encoding ASCII
    try {
        & cmd /c $bat 2>&1 | Out-Host
        $rc = $LASTEXITCODE
    } finally {
        Remove-Item $bat -Force -ErrorAction SilentlyContinue
    }
    if ($rc -ne 0) {
        throw "ramet_models build failed (exit $rc)."
    }
}

function Format-Size {
    param([long]$Bytes)
    $value = [double]$Bytes
    foreach ($unit in @("B", "KB", "MB", "GB")) {
        if ($value -lt 1024 -or $unit -eq "GB") {
            return ("{0:N1} {1}" -f $value, $unit)
        }
        $value = $value / 1024
    }
}

# --- preflight ---------------------------------------------------------------

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "python is not on PATH; it is needed to assemble the library."
}

$toolPath = Join-Path $root "subprojects\grad_meh\build\lib64\ramet_models.exe"
if ($RebuildTool -or -not (Test-Path $toolPath)) {
    if (-not $RebuildTool) {
        Write-Host "ramet_models.exe is missing; building it first." -ForegroundColor DarkGray
    }
    Build-ModelTool -Repo $root
}
if (-not (Test-Path $toolPath)) {
    throw "ramet_models.exe was not produced at '$toolPath'."
}

$modRoots = @()
if ($ModRoot.Count -gt 0) {
    $modRoots = $ModRoot
} else {
    $armaRoot = Resolve-Arma3Root -Preferred $Arma3Root
    if (-not $armaRoot) {
        throw "Could not find the Arma 3 directory. Pass -Arma3Root or -ModRoot."
    }
    Write-Host "Arma 3 root: $armaRoot" -ForegroundColor DarkGray
    foreach ($folder in $DefaultModFolders) {
        $candidate = Join-Path $armaRoot $folder
        if (Test-Path $candidate -PathType Container) {
            $modRoots += $candidate
        } else {
            Write-Warning "Mod folder not found, skipping: $candidate"
        }
    }
}

if ($modRoots.Count -eq 0) {
    throw "No mod directories to scan."
}

Write-Host "=== model library ===" -ForegroundColor Cyan
foreach ($modPath in $modRoots) {
    Write-Host "  mod root: $modPath" -ForegroundColor DarkGray
}

$outDir = if ($OutputDir) { $OutputDir } else { Join-Path $root "model_library" }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# --- build -------------------------------------------------------------------

$buildArgs = @("tools/build_models.py", "--out", $outDir)
foreach ($modPath in $modRoots) {
    $buildArgs += @("--mod-root", $modPath)
}
if ($Update) {
    $buildArgs += "--update"
    Write-Host "  mode: update (only new or changed models)" -ForegroundColor DarkGray
} else {
    Write-Host "  mode: full rebuild" -ForegroundColor DarkGray
}

& python @buildArgs 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "build_models.py failed (exit $LASTEXITCODE)."
}

$dbPath = Join-Path $outDir "library.sqlite"
if (-not (Test-Path $dbPath)) {
    throw "library.sqlite was not produced in '$outDir'."
}

# --- manifest ----------------------------------------------------------------

$dbInfo = Get-Item $dbPath
Write-Host "=== verifying ===" -ForegroundColor Cyan
$hash = (Get-FileHash -Path $dbPath -Algorithm SHA256).Hash
$metaJson = & python -c @"
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1])
meta = dict(con.execute('SELECT key, value FROM meta'))
meta['failureCount'] = con.execute('SELECT COUNT(*) FROM failures').fetchone()[0]
meta['categories'] = dict(con.execute('SELECT category, COUNT(*) FROM models GROUP BY 1'))
print(json.dumps(meta))
"@ $dbPath
if ($LASTEXITCODE -ne 0) {
    throw "Could not read back library.sqlite."
}

$meta = $metaJson | ConvertFrom-Json
if ($meta.schema -ne "ramet-models-1") {
    throw "Unexpected library schema '$($meta.schema)'."
}

$manifest = [ordered]@{
    schema       = $meta.schema
    builtAt      = $meta.builtAt
    modelCount   = [int]$meta.modelCount
    failureCount = [int]$meta.failureCount
    sizeBytes    = $dbInfo.Length
    sha256       = $hash
    modRoots     = $modRoots
    categories   = $meta.categories
}
$manifestPath = Join-Path $outDir "manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "  schema      : $($meta.schema)" -ForegroundColor DarkGray
Write-Host "  models      : $($meta.modelCount)" -ForegroundColor DarkGray
Write-Host "  failures    : $($meta.failureCount)" -ForegroundColor DarkGray
Write-Host "  library size: $(Format-Size $dbInfo.Length)" -ForegroundColor DarkGray

# --- zip ---------------------------------------------------------------------

if ($SkipZip) {
    Write-Host "=== zip skipped by request ===" -ForegroundColor DarkGray
    Write-Host "Library ready: $dbPath" -ForegroundColor Green
} else {
    Write-Host "=== packing for upload ===" -ForegroundColor Cyan
    $releases = Join-Path $root "releases"
    New-Item -ItemType Directory -Path $releases -Force | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $zipPath = Join-Path $releases "models_library-$stamp.zip"

    # Staged under models3d\ so the zip extracts straight into the planner's
    # data directory with no moving of files afterwards.
    $staging = Join-Path $outDir "_zip"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    $payload = Join-Path $staging "models3d"
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    Copy-Item $dbPath (Join-Path $payload "library.sqlite")
    Copy-Item $manifestPath (Join-Path $payload "manifest.json")

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    # Fastest, not Optimal: the payload is mostly incompressible float blobs, so
    # the extra minutes of deflate buy almost nothing on a multi-GB library.
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $staging, $zipPath, [System.IO.Compression.CompressionLevel]::Fastest, $false)
    Remove-Item $staging -Recurse -Force

    $zipInfo = Get-Item $zipPath
    $zipGb = $zipInfo.Length / 1GB
    Write-Host ""
    Write-Host "Upload this to the planner host and extract it there:" -ForegroundColor Green
    Write-Host "  $zipPath"
    Write-Host "  $(Format-Size $zipInfo.Length), $($meta.modelCount) models"
    if ($zipGb -gt $MaxZipGb) {
        Write-Warning ("The zip is {0:N1} GB, over the -MaxZipGb limit of {1:N1} GB. " -f $zipGb, $MaxZipGb +
            "Raise minExtent in tools/model_filter.json to drop more small models, or use -Update for deltas.")
    }
}

Write-Host "=== model library finished (exit 0) ===" -ForegroundColor Green

if ($script:TranscriptActive) {
    Stop-Transcript | Out-Null
    $script:TranscriptActive = $false
}
