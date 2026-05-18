# =============================================================================
# DelphiBuildDPROJ.ps1 - Universal Delphi Project Builder
# =============================================================================
# Copyright (c) 2025 Olaf Monien - The MIT License (MIT)
#   https://github.com/omonien/DelphiStandards
# =============================================================================
# Builds any Delphi project file (.dproj) with MSBuild
# Can be used in any Delphi project - no dependencies to specific projects
#
# USAGE:
#   .\DelphiBuildDPROJ.ps1 -ProjectFile "MyProject.dproj"
#   .\DelphiBuildDPROJ.ps1 -ProjectFile "MyProject.dproj" -Config Release -Platform Win64
#   .\DelphiBuildDPROJ.ps1 -ProjectFile "MyProject.dproj" -DelphiVersion "23.0" -VerboseOutput
#   .\DelphiBuildDPROJ.ps1 -ProjectFile "MyProject.dproj" -ExtraProperties @{ Foo = "bar" }
#
# PARAMETERS:
#   -ProjectFile     : Path to the .dproj file to build (mandatory)
#   -Config          : Build configuration (default: "Debug")
#   -Platform        : Target platform (default: "Win64")
#   -DelphiVersion   : Delphi version to use (default: auto-detect latest)
#   -ExtraProperties : Hashtable of extra MSBuild /p:Key=Value properties to
#                      forward to the project build (default: empty).
#                      Values containing whitespace are auto-quoted; simple
#                      tokens stay unquoted so MSBuild conditions like
#                      '$(Foo)'=='bar' match correctly.
#   -VerboseOutput   : Enable verbose MSBuild output
#
# REQUIREMENTS:
#   - Embarcadero Delphi installed
#   - MSBuild available (Visual Studio Build Tools or full Visual Studio)
#
# AUTO-DETECTION:
#   The script automatically detects the latest installed Delphi version by reading:
#   Registry: HKEY_LOCAL_MACHINE\SOFTWARE\Embarcadero\BDS (and Wow6432Node for 32-bit)
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectFile,

    [string]$Config = "",
    [string]$Platform = "",
    [string]$DelphiVersion = "",
    [hashtable]$ExtraProperties = @{},
    [switch]$VerboseOutput,
    [switch]$LinuxMap
)

Write-Host "============================================="
Write-Host "| Universal Delphi Project Builder  -  v1.1 |"
Write-Host "============================================="

# =============================================================================
# CONFIGURATION - Edit these defaults as needed
# =============================================================================
$DefaultConfig        = "Debug"
$DefaultPlatform      = "Win32"
$DefaultDelphiVersion = ""  # Empty = auto-detect latest installed version
# =============================================================================

# Apply defaults if not specified
if ([string]::IsNullOrEmpty($Config)) { $Config = $DefaultConfig }
if ([string]::IsNullOrEmpty($Platform)) { $Platform = $DefaultPlatform }
if ([string]::IsNullOrEmpty($DelphiVersion)) { $DelphiVersion = $DefaultDelphiVersion }

# -----------------------------------------------------------------------------
# Helper Functions (Note: Write-Warn/Write-Err to avoid PowerShell cmdlet conflicts)
# -----------------------------------------------------------------------------
function Write-Info($Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Success($Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn($Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err($Message) { Write-Host $Message -ForegroundColor Red }
function Write-Detail($Message) { Write-Host $Message -ForegroundColor Gray }

# -----------------------------------------------------------------------------
# Get-LatestDelphiVersion
# -----------------------------------------------------------------------------
function Get-LatestDelphiVersion {
    <#
    .SYNOPSIS
    Auto-detects the latest installed Delphi version from Windows Registry

    .DESCRIPTION
    Scans the Windows Registry for Embarcadero BDS installations and returns
    the highest version number found along with its installation path.

    .OUTPUTS
    PSCustomObject with Version and RootDir properties, or $null if none found
    #>

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Embarcadero\BDS",            # 64-bit registry
        "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS" # 32-bit registry on 64-bit Windows
    )

    $FoundVersions = @()

    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path $RegPath) {
            Write-Detail "  Scanning registry: $RegPath"
            try {
                $BDSKeys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
                foreach ($Key in $BDSKeys) {
                    $VersionName = $Key.PSChildName
                    if ($VersionName -match '^\d+\.\d+$') {
                        try {
                            $RootDir = Get-ItemProperty -Path $Key.PSPath -Name "RootDir" -ErrorAction SilentlyContinue
                            if ($RootDir -and $RootDir.RootDir -and (Test-Path $RootDir.RootDir)) {
                                $FoundVersions += [PSCustomObject]@{
                                    Version = $VersionName
                                    RootDir = $RootDir.RootDir
                                    RegistryPath = $Key.PSPath
                                }
                                Write-Detail "  Found Delphi $VersionName at: $($RootDir.RootDir)"
                            }
                        } catch { }
                    }
                }
            } catch { }
        }
    }

    if ($FoundVersions.Count -eq 0) {
        Write-Warn "No Delphi installations found in Windows Registry"
        return $null
    }

    $SortedVersions = $FoundVersions | Sort-Object { [Version]$_.Version } -Descending
    $LatestVersion = $SortedVersions[0]

    Write-Detail "  Available versions: $($SortedVersions.Version -join ', ')"
    Write-Detail "  Using latest: $($LatestVersion.Version)"

    return $LatestVersion
}

# -----------------------------------------------------------------------------
# Initialize-DelphiEnvironment
# -----------------------------------------------------------------------------
function Initialize-DelphiEnvironment {
    param([string]$Version)

    Write-Info "Initializing Delphi environment..."

    if ([string]::IsNullOrEmpty($Version)) {
        Write-Warn "No Delphi version specified, auto-detecting..."
        $DelphiInfo = Get-LatestDelphiVersion

        if ($null -eq $DelphiInfo -or [string]::IsNullOrEmpty($DelphiInfo.Version)) {
            Write-Err "Could not auto-detect Delphi version"
            Write-Err "Please specify a version using -DelphiVersion parameter"
            exit 1
        }

        $Version = $DelphiInfo.Version
        $DelphiPath = $DelphiInfo.RootDir
        Write-Info "Using Delphi $Version"
    } else {
        Write-Detail "Using specified Delphi version: $Version"
        $DelphiPath = "C:\Program Files (x86)\Embarcadero\Studio\$Version"
    }

    $RSVars = Join-Path $DelphiPath "bin\rsvars.bat"
    if (-not (Test-Path $RSVars)) {
        Write-Err "rsvars.bat not found at: $RSVars"
        Write-Err "Check Delphi installation or -DelphiVersion parameter"
        exit 1
    }

    Write-Warn "Loading Delphi environment..."

    # Execute rsvars.bat and capture environment
    $tempFile = [System.IO.Path]::GetTempFileName()
    cmd /c "`"$RSVars`" && set > `"$tempFile`"" 2>$null

    Get-Content $tempFile | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
    Remove-Item $tempFile -ErrorAction SilentlyContinue

    # Find MSBuild
    $MSBuild = Get-Command msbuild.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $MSBuild) {
        Write-Err "msbuild.exe not found in PATH"
        Write-Err "Ensure MSBuild is installed (Visual Studio or Build Tools)"
        exit 1
    }

    Write-Success "Delphi environment initialized"
    Write-Detail "MSBuild: $MSBuild"
    return $MSBuild
}

# -----------------------------------------------------------------------------
# Build-DPROJProject
# -----------------------------------------------------------------------------
function Build-DPROJProject {
    param(
        [string]$ProjectFile,
        [string]$Config,
        [string]$Platform,
        [string]$MSBuild,
        [hashtable]$ExtraProperties,
        [bool]$VerboseOutput,
        [bool]$LinuxMap
    )

    if (-not (Test-Path -LiteralPath $ProjectFile)) {
        Write-Err "Project file not found: $ProjectFile"
        exit 1
    }

    $ProjectItem = Get-Item -LiteralPath $ProjectFile
    $ProjectPath = $ProjectItem.FullName
    
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)

    Write-Warn "Building: $ProjectName"
    Write-Detail "  File:     $ProjectPath"
    Write-Detail "  Config:   $Config"
    Write-Detail "  Platform: $Platform"
    Write-Host ""

    $MSBuildArgs = @(
        $ProjectPath,
        "/t:Build",
        "/p:Config=$Config",
        "/p:Platform=$Platform"
    )

    if ($LinuxMap) {
        $MSBuildArgs += "/p:DCC_MapFile=3"
        $MSBuildArgs += "/p:DCC_DebugInfo=3"
        $MSBuildArgs += "/p:DCC_LocalSymbols=true"
        $MSBuildArgs += "/p:DCC_LocalDebugSymbols=true"
        $MSBuildArgs += "/p:DCC_DebugInformation=2"
        $MSBuildArgs += "/p:DCC_DebugInfoInExe=false"
    }

    $MSBuildArgs += @(
        "/nologo",
        "/m"
    )

    if ($ExtraProperties) {
        foreach ($Key in $ExtraProperties.Keys) {
            # PowerShell -> MSBuild quoting is a two-step trap:
            #   1. PowerShell splits the call-operator arguments on whitespace.
            #      So `/p:Foo=hello world` would arrive at msbuild as the two
            #      arguments `/p:Foo=hello` and `world` - msbuild then either
            #      drops the trailing token or errors.
            #   2. MSBuild treats any quotes inside `/p:Key=Value` as part of
            #      the property value, so `/p:Foo="true"` sets $(Foo) to the
            #      literal string `"true"` (including the quotes) and a
            #      condition like '$(Foo)'=='true' silently fails to match.
            #
            # So we quote only when there's no other way to keep PowerShell
            # from splitting the token. Simple tokens stay unquoted, which is
            # the common case (`FmxLinux=true`, `DefineConstants=FOO;BAR`,
            # etc.). Whitespace-bearing values (e.g. paths) are passed with
            # embedded quotes - this is the unavoidable MSBuild caveat: the
            # quotes survive into $(Key), so downstream conditions and tool
            # arguments must tolerate them or strip them. Encode whitespace
            # out-of-band (e.g. via short-paths) when this matters.
            $Value = [string]$ExtraProperties[$Key]
            if ($Value -match '\s') {
                $MSBuildArgs += "/p:$Key=`"$Value`""
            } else {
                $MSBuildArgs += "/p:$Key=$Value"
            }
            Write-Detail "  Extra:    $Key=$Value"
        }
    }

    if ($VerboseOutput) {
        $MSBuildArgs += "/v:normal"
    } else {
        $MSBuildArgs += "/v:minimal"
    }

    Write-Warn "Starting build..."
    Write-Host ""

    # Execute MSBuild and capture output
    $BuildOutput = & $MSBuild @MSBuildArgs 2>&1
    $BuildExitCode = $LASTEXITCODE

    # Display output
    $BuildOutput | ForEach-Object { Write-Host $_ }

    Write-Host ""

    if ($BuildExitCode -eq 0) {
        Write-Success "Build completed successfully!"
        return $true
    } else {
        Write-Err "Build failed with exit code: $BuildExitCode"
        return $false
    }
}

# -----------------------------------------------------------------------------
# Show-BuildSummary
# -----------------------------------------------------------------------------
function Show-BuildSummary {
    param(
        [string]$ProjectFile,
        [string]$Config,
        [string]$Platform,
        [bool]$Success
    )

    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectFile)

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "Build Summary" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Detail "Project:  $ProjectName"
    Write-Detail "Config:   $Config"
    Write-Detail "Platform: $Platform"
    Write-Host ""

    if ($Success) {
        Write-Success "BUILD SUCCESSFUL"
    } else {
        Write-Err "BUILD FAILED"
    }

    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
try {
    Write-Info "DelphiBuildDPROJ - Universal Delphi Project Builder"
    Write-Host ""

    # Initialize Delphi environment
    $MSBuild = Initialize-DelphiEnvironment -Version $DelphiVersion
    Write-Host ""

    # Build the project
    $BuildSuccess = Build-DPROJProject -ProjectFile $ProjectFile -Config $Config -Platform $Platform -MSBuild $MSBuild -ExtraProperties $ExtraProperties -VerboseOutput $VerboseOutput -LinuxMap $LinuxMap

    # Normalize boolean result
    $BuildResult = ($BuildSuccess -eq $true)

    # Show summary
    Show-BuildSummary -ProjectFile $ProjectFile -Config $Config -Platform $Platform -Success $BuildResult

    # Exit with appropriate code
    if (-not $BuildResult) {
        exit 1
    }
}
catch {
    Write-Err "Unexpected error: $($_.Exception.Message)"
    Write-Err "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
