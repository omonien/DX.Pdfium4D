# =============================================================================
# copy-pdfium-dll.ps1 - Copy PDFium DLL to build output directories
# =============================================================================
# USAGE:
#   .\copy-pdfium-dll.ps1                              # Win32 Debug (default)
#   .\copy-pdfium-dll.ps1 -Platform Win64 -Config Release
# =============================================================================

param(
    [string]$Platform = "Win32",
    [string]$Config = "Debug"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$SourceDll = Join-Path $ProjectRoot "lib\pdfium-bin\bin\pdfium.dll"
$OutputDir = Join-Path $ScriptDir "$Platform\$Config"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Copying PDFium DLL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Platform: $Platform"
Write-Host "Config:   $Config"
Write-Host ""

if (-not (Test-Path $SourceDll)) {
    Write-Host "ERROR: Source DLL not found: $SourceDll" -ForegroundColor Red
    Write-Host "Please ensure the PDFium binaries are in lib\pdfium-bin\bin\" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Copy-Item $SourceDll -Destination (Join-Path $OutputDir "pdfium.dll") -Force
Write-Host "PDFium DLL copied to $OutputDir" -ForegroundColor Green
