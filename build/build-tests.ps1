# =============================================================================
# build-tests.ps1 - Build and optionally run DX Pdfium4D unit tests
# =============================================================================
# USAGE:
#   .\build-tests.ps1                          # Build Win64 Debug
#   .\build-tests.ps1 -Platform Win32          # Build Win32 Debug
#   .\build-tests.ps1 -Run                     # Build and run tests
#   .\build-tests.ps1 -Platform Win32 -Run     # Build Win32 and run
#   .\build-tests.ps1 -Platform Linux64 -FmxLinux
#                                              # Build Linux64 WITH FMXLinux
#                                              # viewer support (requires
#                                              # FMXLinux on the IDE Library
#                                              # Path; see issue #9).
# =============================================================================

param(
    [string]$Config = "Debug",
    [string]$Platform = "Win64",
    [string]$DelphiVersion = "",
    [switch]$Run,
    [switch]$FmxLinux,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TestDproj = Join-Path $ProjectRoot "src\tests\DxPdfium4dTests.dproj"
$BuildScript = Join-Path $ScriptDir "DelphiBuildDPROJ.ps1"

# Build tests
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building DX Pdfium4D Tests ($Platform $Config)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$BuildArgs = @{
    ProjectFile = $TestDproj
    Config      = $Config
    Platform    = $Platform
}
if ($DelphiVersion) { $BuildArgs.DelphiVersion = $DelphiVersion }
if ($VerboseOutput) { $BuildArgs.VerboseOutput = $true }
if ($FmxLinux) {
    $BuildArgs.ExtraProperties = @{ FmxLinux = "true" }
    Write-Host "FMXLinux opt-in is ON (defines HAS_FMXLINUX, includes FMX viewer on Linux)" -ForegroundColor Yellow
}

& $BuildScript @BuildArgs
if ($LASTEXITCODE -ne 0) { exit 1 }

# Copy pdfium.dll to output directory if needed
$OutputDir = Join-Path $ScriptDir "$Platform\$Config"
$PdfiumDll = Join-Path $ProjectRoot "lib\pdfium-bin\bin\pdfium.dll"

if ((Test-Path $PdfiumDll) -and -not (Test-Path (Join-Path $OutputDir "pdfium.dll"))) {
    Write-Host ""
    Write-Host "Copying pdfium.dll to output directory..." -ForegroundColor Yellow
    Copy-Item $PdfiumDll -Destination $OutputDir -Force
}

# Run tests if requested
if ($Run) {
    $TestExe = Join-Path $OutputDir "DxPdfium4dTests.exe"

    if (-not (Test-Path $TestExe)) {
        Write-Host "ERROR: Test executable not found: $TestExe" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Running tests..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    & $TestExe
    $TestExitCode = $LASTEXITCODE

    Write-Host ""
    if ($TestExitCode -eq 0) {
        Write-Host "Tests completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Tests failed with exit code: $TestExitCode" -ForegroundColor Red
        exit $TestExitCode
    }
}
