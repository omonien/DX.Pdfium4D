# =============================================================================
# copy-pdfium-dll.ps1 - Download and copy PDFium DLL to build output
# =============================================================================
# Downloads PDFium binaries from bblanchon/pdfium-binaries (if not cached)
# and copies the DLL to the build output directory.
#
# USAGE:
#   .\copy-pdfium-dll.ps1                              # Win64 Debug (default)
#   .\copy-pdfium-dll.ps1 -Platform Win32
#   .\copy-pdfium-dll.ps1 -Platform Win64 -Config Release
#   .\copy-pdfium-dll.ps1 -ForceDownload              # Re-download even if cached
# =============================================================================

param(
    [ValidateSet("Win32", "Win64")]
    [string]$Platform = "Win64",

    [string]$Config = "Debug",
    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$PdfiumBinDir = Join-Path $ProjectRoot "lib\pdfium-bin"
$OutputDir = Join-Path $ScriptDir "$Platform\$Config"

# Map Delphi platform names to pdfium-binaries asset names
$AssetMap = @{
    "Win32" = "pdfium-win-x86.tgz"
    "Win64" = "pdfium-win-x64.tgz"
}

$AssetName = $AssetMap[$Platform]
$CacheDir = Join-Path $PdfiumBinDir "cache"
$CachedArchive = Join-Path $CacheDir $AssetName
$DllSource = Join-Path $PdfiumBinDir "bin\pdfium.dll"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PDFium DLL Setup ($Platform $Config)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Download if needed ----
$NeedDownload = $ForceDownload -or -not (Test-Path $CachedArchive)

if ($NeedDownload) {
    Write-Host "Downloading $AssetName from bblanchon/pdfium-binaries..." -ForegroundColor Yellow

    # Get latest release tag via gh CLI
    $LatestTag = & gh release view --repo bblanchon/pdfium-binaries --json tagName --jq ".tagName" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($LatestTag)) {
        Write-Host "ERROR: Could not determine latest release. Ensure 'gh' CLI is installed and authenticated." -ForegroundColor Red
        exit 1
    }

    Write-Host "Latest release: $LatestTag" -ForegroundColor Gray

    if (-not (Test-Path $CacheDir)) {
        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    }

    & gh release download $LatestTag --repo bblanchon/pdfium-binaries --pattern $AssetName --dir $CacheDir --clobber 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Download failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host "Downloaded to cache: $CachedArchive" -ForegroundColor Green
} else {
    Write-Host "Using cached archive: $CachedArchive" -ForegroundColor Gray
}

# ---- Extract DLL ----
Write-Host "Extracting pdfium.dll..." -ForegroundColor Yellow

# Extract bin/pdfium.dll from the archive into lib/pdfium-bin/
Push-Location $PdfiumBinDir
try {
    tar xzf $CachedArchive "bin/pdfium.dll" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Extraction failed!" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

if (-not (Test-Path $DllSource)) {
    Write-Host "ERROR: pdfium.dll not found after extraction!" -ForegroundColor Red
    exit 1
}

# ---- Copy to output directory ----
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Copy-Item $DllSource -Destination (Join-Path $OutputDir "pdfium.dll") -Force
Write-Host "Copied pdfium.dll to $OutputDir" -ForegroundColor Green

Write-Host ""
Write-Host "Done." -ForegroundColor Green
