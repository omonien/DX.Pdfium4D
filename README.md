# DX Pdfium4D

<p align="center">
  <img src="assets/Logo.svg" alt="DX Pdfium4D Logo" width="200">
</p>

<p align="center">
  <strong>Delphi Cross-Platform Wrapper for Google's PDFium</strong>
</p>

<p align="center">
  <a href="https://github.com/omonien/DX.Pdfium4D/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  </a>
  <a href="https://www.embarcadero.com/products/delphi">
    <img src="https://img.shields.io/badge/Delphi-12%2B-red.svg" alt="Delphi Version">
  </a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Android%20%7C%20iOS-lightgrey.svg" alt="Platforms">
  <img src="https://img.shields.io/badge/framework-FMX%20%7C%20VCL-orange.svg" alt="Framework">
  <a href="https://pdfium.googlesource.com/pdfium/">
    <img src="https://img.shields.io/badge/PDFium-Google-4285F4.svg" alt="PDFium">
  </a>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#examples">Examples</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**DX Pdfium4D** is a comprehensive Delphi wrapper for Google's PDFium library, providing object-oriented classes for PDF document handling in cross-platform Delphi applications.

The project includes **DX PDF Viewer** demo applications for both **FireMonkey (FMX)** and **VCL**, which serve as practical demonstrations of the wrapper's capabilities and showcase modern Delphi development practices.

### Why DX Pdfium4D?

- ✅ **Type-safe, object-oriented API** - No more dealing with raw C pointers
- ✅ **Automatic resource management** - Destructors handle PDFium cleanup automatically
- ✅ **Cross-platform** - Windows, macOS, Android, iOS
- ✅ **FMX and VCL support** - Works with both FireMonkey and VCL frameworks
- ✅ **Well-documented** - Comprehensive documentation and examples
- ✅ **Production-ready** - Includes unit tests and demo applications
- ✅ **MIT Licensed** - Free for commercial and open-source projects

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Examples](#examples)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Features

### DX Pdfium4D Wrapper

🔧 **Object-Oriented API**
- High-level Delphi classes wrapping PDFium C-API
- Automatic PDFium resource cleanup in destructors
- Type-safe, exception-based error handling

📄 **PDF Document Support**
- Load PDF documents from files or memory
- Extract metadata (title, author, subject, keywords)
- PDF/A compliance detection
- Page count and dimensions

🎨 **Rendering**
- High-quality bitmap rendering
- Configurable DPI support
- Platform-independent rendering
- Separate renderers for FMX and VCL

🌍 **Cross-Platform**
- Windows (Win32, Win64) - FMX and VCL
- macOS (Intel, Apple Silicon) - FMX
- Android - FMX
- iOS - FMX

### DX PDF Viewer Applications

✨ **Two Implementations**
- **FMX Viewer** - Cross-platform (Windows, macOS, Android, iOS)
- **VCL Viewer** - Windows-only with native Windows controls

✨ **Minimalistic Design**
- Clean, distraction-free interface
- Focus on content, not chrome
- Modern Material Design-inspired UI (FMX)
- Native Windows look and feel (VCL)

🎯 **User-Friendly**
- Drag & Drop PDF files to open
- Click anywhere to browse for files
- Keyboard shortcuts (Ctrl+O to open, arrow keys to navigate)
- PDF/A detection and metadata display

⚡ **Performance**
- Background rendering for smooth UI
- Efficient memory management
- Fast page switching
- Proper aspect ratio preservation
- Centered display with visual feedback

---

## Getting Started

### Prerequisites

- **Delphi 12 or 13** (recommended and tested)
  - Tested with Delphi 12.3 Athens and Delphi 13 Florence
  - Should work with Delphi 10.0 or later (not tested, no guarantee)
  - Minimum: Delphi 10.0 for FMX and VCL support
- **PDFium Library** (included in `lib/pdfium-bin`)

### Installation

#### Option 1: Clone the Repository

```bash
git clone https://github.com/omonien/DX.Pdfium4D.git
cd DX.Pdfium4D
```

#### Option 2: Download Release

Download the latest release from the [Releases](https://github.com/omonien/DX.Pdfium4D/releases) page.

### Quick Start

#### Using the Wrapper in Your Project

1. **Add the wrapper units to your project:**
   ```pascal
   uses
     DX.Pdf.API,          // Low-level PDFium C-API bindings
     DX.Pdf.Document,     // High-level document/page classes
     DX.Pdf.Viewer.FMX,   // (Optional) FMX visual component
     DX.Pdf.Viewer.VCL;   // (Optional) VCL visual component
   ```

2. **Include PDFium library:**
   - Copy the appropriate PDFium DLL/dylib/so from `lib/pdfium-bin` to your output directory
   - Windows: `pdfium.dll`
   - macOS: `libpdfium.dylib`
   - Linux: `libpdfium.so`

3. **Load and render a PDF:**
   ```pascal
   var
     LDocument: TPdfDocument;
     LPage: TPdfPage;
     LBitmap: TBitmap;
   begin
     LDocument := TPdfDocument.Create('document.pdf');
     try
       LPage := LDocument.Pages[0];
       LBitmap := LPage.RenderToBitmap(96); // 96 DPI
       try
         // Use the bitmap
       finally
         LBitmap.Free;
       end;
     finally
       LDocument.Free;
     end;
   end;
   ```

4. **See the full documentation:**
   - 📖 **[Using the DX.Pdf Wrapper Classes](USING_DX_PDF.md)**

#### Building the DX PDF Viewer Examples

**FMX Viewer (Cross-Platform):**
1. Open `src/PdfViewer/DX.PdfViewer.dproj` in Delphi IDE
2. Press **F9** or select **Run → Run**
3. The PDFium DLL will be automatically copied to the output directory

**VCL Viewer (Windows):**
1. Open `src/PdfViewerVCL/DX.PdfViewerVCL.dproj` in Delphi IDE
2. Press **F9** or select **Run → Run**
3. The PDFium DLL will be automatically copied to the output directory

**Run from command line:**
```bash
# FMX Viewer - Windows
src\PdfViewer\Win32\Debug\DX.PdfViewer.exe path\to\document.pdf

# FMX Viewer - macOS
./DX.PdfViewer document.pdf

# VCL Viewer - Windows
src\PdfViewerVCL\Win32\Debug\DX.PdfViewerVCL.exe path\to\document.pdf
```

---

## Documentation

For detailed documentation on using the DX Pdfium4D wrapper in your projects, see:

📖 **[Using the DX.Pdf Wrapper Classes](USING_DX_PDF.md)**

### API Reference

The wrapper provides three main abstraction layers:

1. **`DX.Pdf.API`** - Low-level PDFium C-API bindings
2. **`DX.Pdf.Document`** - High-level object-oriented wrapper
3. **`DX.Pdf.Viewer.Core`** - Shared viewer logic (platform-independent)
4. **`DX.Pdf.Viewer.FMX`** - FMX visual component
5. **`DX.Pdf.Viewer.VCL`** - VCL visual component
6. **`DX.Pdf.Renderer.FMX`** - FMX-specific rendering
7. **`DX.Pdf.Renderer.VCL`** - VCL-specific rendering

---

## Examples

### DX PDF Viewer Demo Applications

The included **DX PDF Viewer** applications (FMX and VCL) demonstrate the wrapper's capabilities.

#### Features

#### Opening PDF Files

**Method 1: Drag & Drop**
- Drag a PDF file from Explorer and drop it onto the DX PDF Viewer window

**Method 2: Click to Browse**
- Click anywhere on the drop zone or status bar to open the file browser
- Select a PDF file and click "Open"

**Method 3: Keyboard Shortcut**
- Press **Ctrl+O** to open the file browser

**Method 4: Command Line**
- Pass the PDF file path as a command-line argument:
  ```bash
  DX.PdfViewer.exe document.pdf
  ```

#### Navigation

| Action | Method |
|--------|--------|
| **Next Page** | ↓ Arrow Key, Mouse Wheel Down, Swipe Up |
| **Previous Page** | ↑ Arrow Key, Mouse Wheel Up, Swipe Down |
| **Open File** | Ctrl+O, Click on status bar |

#### Status Bar

The status bar displays:
- **File name** (clickable to open another file)
- **PDF version** (e.g., PDF 1.7)
- **PDF/A compliance** (if applicable)
- **Current page / Total pages**



---

## Project Structure

```
DX.Pdfium4D/
├── src/                          # Source code
│   ├── DX.Pdf.API.pas           # Low-level PDFium C-API bindings
│   ├── DX.Pdf.Document.pas      # High-level document/page classes
│   ├── DX.Pdf.Viewer.Core.pas   # Shared viewer logic
│   ├── DX.Pdf.Viewer.FMX.pas    # FMX visual component
│   ├── DX.Pdf.Viewer.VCL.pas    # VCL visual component
│   ├── DX.Pdf.Renderer.FMX.pas  # FMX rendering
│   ├── DX.Pdf.Renderer.VCL.pas  # VCL rendering
│   ├── PdfViewer/               # FMX demo application
│   │   ├── DX.PdfViewer.dpr     # Main program file
│   │   ├── DX.PdfViewer.dproj   # Delphi project file
│   │   ├── Main.Form.pas        # Main application form
│   │   └── Main.Form.fmx        # Form layout
│   ├── PdfViewerVCL/            # VCL demo application
│   │   ├── DX.PdfViewerVCL.dpr  # Main program file
│   │   ├── DX.PdfViewerVCL.dproj # Delphi project file
│   │   ├── Main.Form.pas        # Main application form
│   │   └── Main.Form.dfm        # Form layout
│   └── tests/                   # Unit tests
│       ├── DxPdfium4dTests.dpr    # Test project
│       ├── DxPdfium4dTests.dproj  # Test project file
│       └── DX.Pdf.Document.Tests.pas
├── assets/                       # Icons and logos
│   ├── Icon.svg                 # Application icon (source)
│   └── Logo.svg                 # DX Pdfium4D logo
├── samples/                      # Sample PDF files for testing
│   ├── Simple PDF 2.0 file.pdf  # Basic PDF 2.0 example
│   └── pdf20-utf8-test.pdf      # Complex PDF with UTF-8, bookmarks, layers
└── lib/                          # Third-party libraries
    ├── pdfium-bin/              # PDFium binaries
    └── DUnitX/                  # Unit testing framework
```


---

## Architecture

### PDFium Wrapper Layers

**1. Low-Level API (`DX.Pdf.API.pas`)**
- Direct C-API bindings to PDFium
- Platform-independent function declarations
- Minimal abstraction

**2. High-Level Classes (`DX.Pdf.Document.pas`)**
- Object-oriented wrapper with automatic PDFium resource cleanup
- Metadata extraction (title, author, PDF/A compliance, etc.)
- Bitmap rendering with configurable DPI

**3. Viewer Core (`DX.Pdf.Viewer.Core.pas`)**
- Shared viewer logic for FMX and VCL
- Page navigation and state management
- Platform-independent functionality

**4. Visual Components**
- **FMX Component (`DX.Pdf.Viewer.FMX.pas`)** - Cross-platform PDF viewer
- **VCL Component (`DX.Pdf.Viewer.VCL.pas`)** - Windows-native PDF viewer
- Automatic page navigation
- Drag & Drop support
- Background rendering for smooth UI
- Proper aspect ratio preservation

### Threading Model

- **Main Thread:** UI updates, user interaction
- **Background Thread:** PDF page rendering (using `TTask`)
- **Synchronization:** `TThread.Synchronize` for bitmap updates

---

## Dependencies

### PDFium Library

DX Pdfium4D uses Google's PDFium library for PDF rendering:

- **Source:** https://pdfium.googlesource.com/pdfium/
- **Binaries:** https://github.com/bblanchon/pdfium-binaries
- **License:** BSD-3-Clause (compatible with commercial use)

### DUnitX

Unit testing framework:

- **Source:** https://github.com/VSoftTechnologies/DUnitX
- **License:** Apache 2.0

---

## Sample PDF Files

The `samples/` directory contains example PDF files for testing and demonstration purposes:

### Simple PDF 2.0 file.pdf
A basic single-page PDF 2.0 file demonstrating:
- Simple text and path operators
- Commented content stream for educational purposes
- Example XMP metadata fields

### pdf20-utf8-test.pdf
A more complex PDF 2.0 file featuring:
- UTF-8 encoded text strings (new in PDF 2.0)
- Outlines (bookmarks) with Unicode characters
- Optional Content layers with UTF-8 names
- AltText and Information dictionary with UTF-8 values
- Non-trivial Unicode characters for testing

**Attribution:** Sample PDF files are provided by the [PDF Association](https://github.com/pdf-association/pdf20examples) under the [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/) license.

---

## Testing

DX Pdfium4D includes comprehensive unit tests for the PDFium wrapper classes.

### Running Tests

**Option 1: Batch Script**
```bash
cd src\tests
build-and-run-tests.bat
```

**Option 2: Delphi IDE**
1. Open `src\tests\DxPdfium4dTests.dproj`
2. Press **F9** to run tests
3. View results in the console

### Test Coverage

- ✅ PDF document loading
- ✅ Page count and dimensions
- ✅ Metadata extraction
- ✅ PDF/A detection
- ✅ Bitmap rendering
- ✅ Error handling

---

## Contributing

Contributions are welcome! We appreciate your help in making DX Pdfium4D better.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add some amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Coding Standards

- Follow the [Delphi Coding Style Guide](docs/CODING_STYLE.md) included in this project
- Write unit tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in [Issues](https://github.com/omonien/DX.Pdfium4D/issues)
2. If not, create a new issue with:
   - Clear description of the problem/feature
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Delphi version and platform
   - Sample code if applicable

### Development Setup

1. Clone the repository
2. Open `src/PdfViewer/DX.PdfViewer.dproj` in Delphi
3. Build and run tests: `src/tests/build-and-run-tests.bat`

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### What does this mean?

✅ **Commercial use** - Use in commercial projects
✅ **Modification** - Modify the source code
✅ **Distribution** - Distribute the software
✅ **Private use** - Use privately
⚠️ **Liability** - No warranty provided
⚠️ **License and copyright notice** - Must include license in distributions

### Third-Party Licenses

- **PDFium:** BSD-3-Clause License ([Google](https://pdfium.googlesource.com/pdfium/))
- **DUnitX:** Apache 2.0 License ([VSoft Technologies](https://github.com/VSoftTechnologies/DUnitX))

---

## Author & Support

**Olaf Monien**
🌐 Website: [developer-experts.net](https://developer-experts.net)
📧 Email: olaf@monien.net
💼 GitHub: [@omonien](https://github.com/omonien)

### Support This Project

If you find DX Pdfium4D useful, please consider:

- ⭐ **Starring** this repository
- 🐛 **Reporting bugs** and suggesting features
- 🔀 **Contributing** code improvements
- 📢 **Sharing** with the Delphi community

---

## Acknowledgments

Special thanks to:

- **Google** - For creating and maintaining the [PDFium library](https://pdfium.googlesource.com/pdfium/)
- **Benoît Blanchon** - For maintaining [PDFium binaries](https://github.com/bblanchon/pdfium-binaries)
- **PDF Association** - For providing [PDF 2.0 example files](https://github.com/pdf-association/pdf20examples) for testing
- **VSoft Technologies** - For the excellent [DUnitX](https://github.com/VSoftTechnologies/DUnitX) testing framework
- **Embarcadero** - For Delphi and the FireMonkey framework
- **The Delphi Community** - For continuous support and feedback

---

<p align="center">
  <strong>DX Pdfium4D</strong><br>
  <em>Delphi Cross-Platform Wrapper für Pdfium</em><br><br>
  Made with ❤️ by <a href="https://developer-experts.net">Olaf Monien</a>
</p>

<p align="center">
  <a href="#top">Back to top ⬆️</a>
</p>
