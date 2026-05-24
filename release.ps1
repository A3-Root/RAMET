# RAMET release wrapper.
# Runs `hemtt release` in each subproject + RAMET root, then repackages the final
# zip so @grad_meh / @ocap_renderterrain / @root_amet sit as siblings in the bundle
# (HEMTT's own zip only contains @root_amet content; this wrapper adds the rest).

[CmdletBinding()]
param(
    [switch]$SkipSubprojects,
    [switch]$Clean
)

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
    Get-ChildItem -Path "subprojects\grad_meh\.hemttout", "subprojects\ocap-renderterrain\.hemttout", ".hemttout", "releases" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}

if (-not $SkipSubprojects) {
    Write-Host "=== building subprojects/grad_meh ===" -ForegroundColor Cyan
    Invoke-Hemtt "subprojects\grad_meh"
    Write-Host "=== building subprojects/ocap-renderterrain ===" -ForegroundColor Cyan
    Invoke-Hemtt "subprojects\ocap-renderterrain"
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

# 1) @root_amet — copy what hemtt produced (already contains $ARCHANGEL$, ramet/, docs/, tools/, batch/)
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
} else {
    Write-Warning "$gradOut missing — @grad_meh not bundled"
}
if (Test-Path $ocapOut) {
    Copy-Item -Path $ocapOut -Destination (Join-Path $stagingRoot "@ocap_renderterrain") -Recurse
} else {
    Write-Warning "$ocapOut missing — @ocap_renderterrain not bundled"
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
