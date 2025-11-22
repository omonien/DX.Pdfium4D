@echo off
REM Post-build script to copy PDFium DLL to DX PDF Viewer output directories
REM Usage: copy-pdfium-dll.bat <Platform> <Config>
REM Example: copy-pdfium-dll.bat Win32 Debug

set PLATFORM=%1
set CONFIG=%2

if "%PLATFORM%"=="" set PLATFORM=Win32
if "%CONFIG%"=="" set CONFIG=Debug

REM Set paths relative to repository root
set OUTPUT_DIR_FMX=src\PdfViewer\%PLATFORM%\%CONFIG%
set OUTPUT_DIR_VCL=src\PdfViewerVCL\%PLATFORM%\%CONFIG%
set SOURCE_DLL=lib\pdfium-bin\bin\pdfium.dll

echo.
echo ========================================
echo Copying PDFium DLL to PDF Viewers
echo ========================================
echo Platform: %PLATFORM%
echo Config:   %CONFIG%
echo.

REM Check if source DLL exists
if not exist "%SOURCE_DLL%" (
  echo ERROR: Source DLL not found: %SOURCE_DLL%
  echo Please ensure the PDFium binaries are in lib\pdfium-bin\bin\
  exit /b 1
)

REM Copy to FMX Viewer
echo Target:   %OUTPUT_DIR_FMX%
if not exist "%OUTPUT_DIR_FMX%" (
  echo Creating output directory: %OUTPUT_DIR_FMX%
  mkdir "%OUTPUT_DIR_FMX%"
)

copy /Y "%SOURCE_DLL%" "%OUTPUT_DIR_FMX%\pdfium.dll"
if errorlevel 1 (
  echo ERROR: Failed to copy PDFium DLL to FMX viewer
  exit /b 1
)
echo PDFium DLL copied to FMX viewer successfully!
echo.

REM Copy to VCL Viewer
echo Target:   %OUTPUT_DIR_VCL%
if not exist "%OUTPUT_DIR_VCL%" (
  echo Creating output directory: %OUTPUT_DIR_VCL%
  mkdir "%OUTPUT_DIR_VCL%"
)

copy /Y "%SOURCE_DLL%" "%OUTPUT_DIR_VCL%\pdfium.dll"
if errorlevel 1 (
  echo ERROR: Failed to copy PDFium DLL to VCL viewer
  exit /b 1
)
echo PDFium DLL copied to VCL viewer successfully!

echo.
echo ========================================
echo All PDFium DLLs copied successfully!
echo ========================================

