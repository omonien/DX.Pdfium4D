{*******************************************************************************
  Unit: DX.Pdf.API

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Platform-independent PDFium C-API bindings for Delphi.
    Provides low-level bindings to the PDFium library.
    For high-level object-oriented access, use DX.Pdf.Document instead.

  Based on:
    PDFium from https://pdfium.googlesource.com/pdfium/
    Binaries from https://github.com/bblanchon/pdfium-binaries

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.API;

interface

uses
  System.SysUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

const
  {$IFDEF MSWINDOWS}
    {$IFDEF WIN64}
      PDFIUM_DLL = 'pdfium.dll';
    {$ELSE}
      PDFIUM_DLL = 'pdfium.dll';
    {$ENDIF}
  {$ENDIF}
  {$IFDEF MACOS}
    {$IFDEF CPUARM64}
      PDFIUM_DLL = 'libpdfium.dylib';
    {$ELSE}
      PDFIUM_DLL = 'libpdfium.dylib';
    {$ENDIF}
  {$ENDIF}
  {$IFDEF LINUX}
    PDFIUM_DLL = 'libpdfium.so';
  {$ENDIF}
  {$IFDEF ANDROID}
    PDFIUM_DLL = 'libpdfium.so';
  {$ENDIF}
  {$IFDEF IOS}
    PDFIUM_DLL = 'libpdfium.dylib';
  {$ENDIF}

  // Error codes
  FPDF_ERR_SUCCESS = 0;
  FPDF_ERR_UNKNOWN = 1;
  FPDF_ERR_FILE = 2;
  FPDF_ERR_FORMAT = 3;
  FPDF_ERR_PASSWORD = 4;
  FPDF_ERR_SECURITY = 5;
  FPDF_ERR_PAGE = 6;

  // Render flags
  FPDF_ANNOT = $01;
  FPDF_LCD_TEXT = $02;
  FPDF_NO_NATIVETEXT = $04;
  FPDF_GRAYSCALE = $08;
  FPDF_DEBUG_INFO = $80;
  FPDF_NO_CATCH = $100;
  FPDF_RENDER_LIMITEDIMAGECACHE = $200;
  FPDF_RENDER_FORCEHALFTONE = $400;
  FPDF_PRINTING = $800;
  FPDF_RENDER_NO_SMOOTHTEXT = $1000;
  FPDF_RENDER_NO_SMOOTHIMAGE = $2000;
  FPDF_RENDER_NO_SMOOTHPATH = $4000;
  FPDF_REVERSE_BYTE_ORDER = $10;

  // Page rotation
  FPDF_ROTATE_0 = 0;
  FPDF_ROTATE_90 = 1;
  FPDF_ROTATE_180 = 2;
  FPDF_ROTATE_270 = 3;

  // Bitmap formats
  FPDFBitmap_Unknown = 0;
  FPDFBitmap_Gray = 1;
  FPDFBitmap_BGR = 2;
  FPDFBitmap_BGRx = 3;
  FPDFBitmap_BGRA = 4;

type
  // Opaque types (pointers to internal PDFium structures)
  FPDF_DOCUMENT = type Pointer;
  FPDF_PAGE = type Pointer;
  FPDF_BITMAP = type Pointer;
  FPDF_TEXTPAGE = type Pointer;
  FPDF_PAGELINK = type Pointer;
  FPDF_SCHHANDLE = type Pointer;
  FPDF_BOOKMARK = type Pointer;
  FPDF_DEST = type Pointer;
  FPDF_ACTION = type Pointer;
  FPDF_LINK = type Pointer;

  // Basic types
  FPDF_BOOL = type Integer;
  FPDF_DWORD = type Cardinal;
  FPDF_WCHAR = type Word;
  FPDF_BYTESTRING = type PAnsiChar;
  FPDF_WIDESTRING = type PWideChar;
  FPDF_STRING = type PAnsiChar;

  // Structures
  PFS_MATRIX = ^FS_MATRIX;
  FS_MATRIX = record
    A: Single;
    B: Single;
    C: Single;
    D: Single;
    E: Single;
    F: Single;
  end;

  PFS_RECTF = ^FS_RECTF;
  FS_RECTF = record
    Left: Single;
    Top: Single;
    Right: Single;
    Bottom: Single;
  end;

  PFS_SIZEF = ^FS_SIZEF;
  FS_SIZEF = record
    Width: Single;
    Height: Single;
  end;

  PFS_POINTF = ^FS_POINTF;
  FS_POINTF = record
    X: Single;
    Y: Single;
  end;

  PFPDF_LIBRARY_CONFIG = ^FPDF_LIBRARY_CONFIG;
  FPDF_LIBRARY_CONFIG = record
    Version: Integer;
    UserFontPaths: PPAnsiChar;
    Isolate: Pointer;
    V8EmbedderSlot: Cardinal;
  end;

  // Callback function for custom file access
  // Returns non-zero if successful, zero for error
  TFPDFFileAccessGetBlock = function(param: Pointer; position: Cardinal;
    pBuf: PByte; size: Cardinal): Integer; cdecl;

  // Structure for custom file access (streaming support)
  PFPDF_FILEACCESS = ^FPDF_FILEACCESS;
  FPDF_FILEACCESS = record
    m_FileLen: Cardinal;        // Total file length in bytes
    m_GetBlock: TFPDFFileAccessGetBlock;  // Callback to read data blocks
    m_Param: Pointer;           // Custom user data passed to callback
  end;

// Library initialization and cleanup
procedure FPDF_InitLibrary; cdecl; external PDFIUM_DLL;
procedure FPDF_InitLibraryWithConfig(const AConfig: PFPDF_LIBRARY_CONFIG); cdecl; external PDFIUM_DLL;
procedure FPDF_DestroyLibrary; cdecl; external PDFIUM_DLL;

// Error handling
function FPDF_GetLastError: Cardinal; cdecl; external PDFIUM_DLL;

// Document functions
function FPDF_LoadDocument(const AFilePath: FPDF_STRING; const APassword: FPDF_BYTESTRING): FPDF_DOCUMENT; cdecl; external PDFIUM_DLL;
function FPDF_LoadMemDocument(const ADataBuf: Pointer; ASize: Integer; const APassword: FPDF_BYTESTRING): FPDF_DOCUMENT; cdecl; external PDFIUM_DLL;
function FPDF_LoadCustomDocument(pFileAccess: PFPDF_FILEACCESS; const APassword: FPDF_BYTESTRING): FPDF_DOCUMENT; cdecl; external PDFIUM_DLL;
procedure FPDF_CloseDocument(ADocument: FPDF_DOCUMENT); cdecl; external PDFIUM_DLL;
function FPDF_GetPageCount(ADocument: FPDF_DOCUMENT): Integer; cdecl; external PDFIUM_DLL;
function FPDF_GetFileVersion(ADocument: FPDF_DOCUMENT; var AFileVersion: Integer): FPDF_BOOL; cdecl; external PDFIUM_DLL;
function FPDF_GetPageSizeByIndex(ADocument: FPDF_DOCUMENT; APageIndex: Integer; out AWidth: Double; out AHeight: Double): FPDF_BOOL; cdecl; external PDFIUM_DLL;
function FPDF_GetMetaText(ADocument: FPDF_DOCUMENT; const ATag: FPDF_BYTESTRING; ABuffer: Pointer; ABufLen: Cardinal): Cardinal; cdecl; external PDFIUM_DLL;

// Page functions (fpdfview.h)
function FPDF_LoadPage(ADocument: FPDF_DOCUMENT; APageIndex: Integer): FPDF_PAGE; cdecl; external PDFIUM_DLL;
procedure FPDF_ClosePage(APage: FPDF_PAGE); cdecl; external PDFIUM_DLL;
function FPDF_GetPageWidth(APage: FPDF_PAGE): Double; cdecl; external PDFIUM_DLL;
function FPDF_GetPageHeight(APage: FPDF_PAGE): Double; cdecl; external PDFIUM_DLL;

// Page edit functions (fpdf_edit.h)
function FPDFPage_GetRotation(APage: FPDF_PAGE): Integer; cdecl; external PDFIUM_DLL;

// Bitmap functions
function FPDFBitmap_Create(AWidth: Integer; AHeight: Integer; AAlpha: Integer): FPDF_BITMAP; cdecl; external PDFIUM_DLL;
function FPDFBitmap_CreateEx(AWidth: Integer; AHeight: Integer; AFormat: Integer; AFirstScan: Pointer; AStride: Integer): FPDF_BITMAP; cdecl; external PDFIUM_DLL;
procedure FPDFBitmap_Destroy(ABitmap: FPDF_BITMAP); cdecl; external PDFIUM_DLL;
function FPDFBitmap_GetBuffer(ABitmap: FPDF_BITMAP): Pointer; cdecl; external PDFIUM_DLL;
function FPDFBitmap_GetWidth(ABitmap: FPDF_BITMAP): Integer; cdecl; external PDFIUM_DLL;
function FPDFBitmap_GetHeight(ABitmap: FPDF_BITMAP): Integer; cdecl; external PDFIUM_DLL;
function FPDFBitmap_GetStride(ABitmap: FPDF_BITMAP): Integer; cdecl; external PDFIUM_DLL;
procedure FPDFBitmap_FillRect(ABitmap: FPDF_BITMAP; ALeft: Integer; ATop: Integer; AWidth: Integer; AHeight: Integer; AColor: FPDF_DWORD); cdecl; external PDFIUM_DLL;

// Rendering functions
procedure FPDF_RenderPageBitmap(ABitmap: FPDF_BITMAP; APage: FPDF_PAGE; AStartX: Integer; AStartY: Integer; ASizeX: Integer; ASizeY: Integer; ARotate: Integer; AFlags: Integer); cdecl; external PDFIUM_DLL;

{$IFDEF MSWINDOWS}
procedure FPDF_RenderPage(ADC: HDC; APage: FPDF_PAGE; AStartX: Integer; AStartY: Integer; ASizeX: Integer; ASizeY: Integer; ARotate: Integer; AFlags: Integer); cdecl; external PDFIUM_DLL;
{$ENDIF}

// Text functions
function FPDFText_LoadPage(APage: FPDF_PAGE): FPDF_TEXTPAGE; cdecl; external PDFIUM_DLL;
procedure FPDFText_ClosePage(ATextPage: FPDF_TEXTPAGE); cdecl; external PDFIUM_DLL;
function FPDFText_CountChars(ATextPage: FPDF_TEXTPAGE): Integer; cdecl; external PDFIUM_DLL;
function FPDFText_GetUnicode(ATextPage: FPDF_TEXTPAGE; AIndex: Integer): Cardinal; cdecl; external PDFIUM_DLL;
function FPDFText_GetText(ATextPage: FPDF_TEXTPAGE; AStartIndex: Integer; ACount: Integer; AResult: PWideChar): Integer; cdecl; external PDFIUM_DLL;

// Bookmark functions
function FPDFBookmark_GetFirstChild(ADocument: FPDF_DOCUMENT; ABookmark: FPDF_BOOKMARK): FPDF_BOOKMARK; cdecl; external PDFIUM_DLL;
function FPDFBookmark_GetNextSibling(ADocument: FPDF_DOCUMENT; ABookmark: FPDF_BOOKMARK): FPDF_BOOKMARK; cdecl; external PDFIUM_DLL;
function FPDFBookmark_GetTitle(ABookmark: FPDF_BOOKMARK; ABuffer: Pointer; ABufLen: Cardinal): Cardinal; cdecl; external PDFIUM_DLL;
function FPDFBookmark_GetDest(ADocument: FPDF_DOCUMENT; ABookmark: FPDF_BOOKMARK): FPDF_DEST; cdecl; external PDFIUM_DLL;

// Helper functions
function FPDF_BoolToBoolean(AValue: FPDF_BOOL): Boolean; inline;
function BooleanToFPDF_Bool(AValue: Boolean): FPDF_BOOL; inline;
function FPDF_ErrorToString(AError: Cardinal): string;

implementation

function FPDF_BoolToBoolean(AValue: FPDF_BOOL): Boolean;
begin
  Result := AValue <> 0;
end;

function BooleanToFPDF_Bool(AValue: Boolean): FPDF_BOOL;
begin
  if AValue then
    Result := 1
  else
    Result := 0;
end;

function FPDF_ErrorToString(AError: Cardinal): string;
begin
  case AError of
    FPDF_ERR_SUCCESS: Result := 'Success';
    FPDF_ERR_UNKNOWN: Result := 'Unknown error';
    FPDF_ERR_FILE: Result := 'File not found or could not be opened';
    FPDF_ERR_FORMAT: Result := 'File not in PDF format or corrupted';
    FPDF_ERR_PASSWORD: Result := 'Password required or incorrect password';
    FPDF_ERR_SECURITY: Result := 'Unsupported security scheme';
    FPDF_ERR_PAGE: Result := 'Page not found or content error';
  else
    Result := 'Unknown error code: ' + AError.ToString;
  end;
end;

end.

