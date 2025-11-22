@echo off
REM Build script for VCL PDF Viewer Demo

echo.
echo ========================================
echo Building VCL PDF Viewer Demo...
echo ========================================
echo.

REM Create output directories if they don't exist
if not exist Win32\Debug mkdir Win32\Debug
if not exist Win32\Debug\dcu mkdir Win32\Debug\dcu

REM Compile with correct paths
dcc32 -B -U.. -E.\Win32\Debug -N.\Win32\Debug\dcu DX.PdfViewerVCL.dpr

if errorlevel 1 (
    echo.
    echo ========================================
    echo Build FAILED!
    echo ========================================
    exit /b 1
)

echo.
echo ========================================
echo Build successful!
echo ========================================
echo.
echo Executable: Win32\Debug\DX.PdfViewerVCL.exe
echo.

