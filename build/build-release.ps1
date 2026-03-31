# =============================================================================
# build-release.ps1 - Build DX PDF Viewer release packages
# =============================================================================
# Builds FMX and VCL viewers for Win32 and Win64, creates ZIP archives,
# and optionally uploads them to a GitHub release.
#
# USAGE:
#   .\build-release.ps1 -Version "v1.1.0"
#   .\build-release.ps1 -Version "v1.1.0" -Upload
#   .\build-release.ps1 -Version "v1.1.0" -Upload -DelphiVersion "23.0"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [string]$DelphiVersion = "",
    [switch]$Upload,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BuildScript = Join-Path $ScriptDir "DelphiBuildDPROJ.ps1"
$FmxDproj = Join-Path $ProjectRoot "src\PdfViewer\DX.PdfViewer.dproj"
$VclDproj = Join-Path $ProjectRoot "src\PdfViewerVCL\DX.PdfViewerVCL.dproj"
$PdfiumDll = Join-Path $ProjectRoot "lib\pdfium-bin\bin\pdfium.dll"
$ReleaseDir = Join-Path $ProjectRoot "release"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building DX PDF Viewer Release $Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Clean previous release
if (Test-Path $ReleaseDir) {
    Remove-Item $ReleaseDir -Recurse -Force
}

# Build configurations
$Builds = @(
    @{ Dproj = $FmxDproj; Platform = "Win32"; Config = "Release"; Name = "FMX" },
    @{ Dproj = $FmxDproj; Platform = "Win64"; Config = "Release"; Name = "FMX" },
    @{ Dproj = $VclDproj; Platform = "Win32"; Config = "Release"; Name = "VCL" },
    @{ Dproj = $VclDproj; Platform = "Win64"; Config = "Release"; Name = "VCL" }
)

foreach ($Build in $Builds) {
    Write-Host ""
    Write-Host "Building $($Build.Name) $($Build.Platform) $($Build.Config)..." -ForegroundColor Yellow

    $BuildArgs = @{
        ProjectFile = $Build.Dproj
        Config      = $Build.Config
        Platform    = $Build.Platform
    }
    if ($DelphiVersion) { $BuildArgs.DelphiVersion = $DelphiVersion }
    if ($VerboseOutput) { $BuildArgs.VerboseOutput = $true }

    & $BuildScript @BuildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: $($Build.Name) $($Build.Platform) build failed!" -ForegroundColor Red
        exit 1
    }
}

# Create release packages
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating release packages..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$Packages = @(
    @{ Name = "DX.PdfViewer"; Platform = "Win32"; Exe = "DX.PdfViewer.exe" },
    @{ Name = "DX.PdfViewer"; Platform = "Win64"; Exe = "DX.PdfViewer.exe" }
)

foreach ($Pkg in $Packages) {
    $PkgDir = Join-Path $ReleaseDir "$($Pkg.Name)-$($Pkg.Platform)"
    New-Item -ItemType Directory -Path $PkgDir -Force | Out-Null

    $ExeSource = Join-Path $ScriptDir "$($Pkg.Platform)\Release\$($Pkg.Exe)"
    Copy-Item $ExeSource -Destination $PkgDir
    if (Test-Path $PdfiumDll) { Copy-Item $PdfiumDll -Destination $PkgDir }
    Copy-Item (Join-Path $ProjectRoot "samples\*.pdf") -Destination $PkgDir -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $ProjectRoot "README.md") -Destination $PkgDir
    Copy-Item (Join-Path $ProjectRoot "LICENSE") -Destination $PkgDir

    $ZipFile = Join-Path $ReleaseDir "$($Pkg.Name)-$Version-$($Pkg.Platform).zip"
    Compress-Archive -Path "$PkgDir\*" -DestinationPath $ZipFile -Force
    Write-Host "Created: $ZipFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Upload to GitHub if requested
if ($Upload) {
    Write-Host ""
    Write-Host "Uploading to GitHub Release $Version..." -ForegroundColor Yellow

    $ZipFiles = Get-ChildItem -Path $ReleaseDir -Filter "*.zip" | Select-Object -ExpandProperty FullName

    # Create release and upload assets via gh CLI
    $GhArgs = @("release", "create", $Version) + $ZipFiles + @("--title", "DX PDF Viewer $Version", "--generate-notes")
    & gh @GhArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Upload complete!" -ForegroundColor Green
    } else {
        Write-Host "Upload failed!" -ForegroundColor Red
        exit 1
    }
}
