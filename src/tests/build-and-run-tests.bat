@echo off
REM Build and run DX Pdfium4D Tests
REM This script compiles the tests and runs them

echo.
echo ========================================
echo Building DX Pdfium4D Tests...
echo ========================================
echo.

REM Create output directories if they don't exist
if not exist Win32\Debug mkdir Win32\Debug
if not exist Win32\Debug\dcu mkdir Win32\Debug\dcu

REM Compile tests with correct paths
dcc32 -B -U..\..\lib\DUnitX\Source;.. -E.\Win32\Debug -N.\Win32\Debug\dcu DxPdfium4dTests.dpr

if errorlevel 1 (
    echo.
    echo ========================================
    echo Build FAILED!
    echo ========================================
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build successful!
echo ========================================
echo.

REM Copy pdfium.dll if needed
if not exist Win32\Debug\pdfium.dll (
    echo Copying pdfium.dll...
    copy /Y ..\PdfViewer\Win32\Debug\pdfium.dll Win32\Debug\
)

echo.
echo ========================================
echo Running tests...
echo ========================================
echo.

REM Run tests
.\Win32\Debug\DxPdfium4dTests.exe

echo.
echo ========================================
echo Tests completed!
echo ========================================
pause

