{*******************************************************************************
  Unit: DX.Pdf.Document

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Object-oriented wrapper for PDFium library.
    Provides high-level access to PDF documents with automatic resource management.
    All classes use reference counting and automatic cleanup.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Document;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Graphics,
  DX.Pdf.API;

type
  EPdfException = class(Exception);
  EPdfLoadException = class(EPdfException);
  EPdfPageException = class(EPdfException);
  EPdfRenderException = class(EPdfException);

  TPdfPage = class;
  TPdfDocument = class;
  TPdfStreamAdapter = class;

  /// <summary>
  /// Adapter class that bridges TStream to PDFium's FPDF_FILEACCESS interface
  /// Enables true streaming support without loading entire PDF into memory
  /// </summary>
  TPdfStreamAdapter = class
  private
    FStream: TStream;
    FFileAccess: FPDF_FILEACCESS;
    FOwnsStream: Boolean;
    class function GetBlockCallback(param: Pointer; position: Cardinal;
      pBuf: PByte; size: Cardinal): Integer; cdecl; static;
  public
    constructor Create(AStream: TStream; AOwnsStream: Boolean = False);
    destructor Destroy; override;

    property FileAccess: FPDF_FILEACCESS read FFileAccess;
    property Stream: TStream read FStream;
  end;

  /// <summary>
  /// Represents a single page in a PDF document
  /// </summary>
  TPdfPage = class
  private
    FDocument: TPdfDocument;
    FHandle: FPDF_PAGE;
    FPageIndex: Integer;
    FWidth: Double;
    FHeight: Double;
    function GetRotation: Integer;
  public
    constructor Create(ADocument: TPdfDocument; APageIndex: Integer);
    destructor Destroy; override;

    /// <summary>
    /// Renders the page to a bitmap
    /// </summary>
    procedure RenderToBitmap(ABitmap: TBitmap; ABackgroundColor: TAlphaColor = TAlphaColors.White);

    /// <summary>
    /// Page index (0-based)
    /// </summary>
    property PageIndex: Integer read FPageIndex;

    /// <summary>
    /// Page width in points (1/72 inch)
    /// </summary>
    property Width: Double read FWidth;

    /// <summary>
    /// Page height in points (1/72 inch)
    /// </summary>
    property Height: Double read FHeight;

    /// <summary>
    /// Page rotation (0, 90, 180, or 270 degrees)
    /// </summary>
    property Rotation: Integer read GetRotation;

    /// <summary>
    /// Internal PDFium page handle
    /// </summary>
    property Handle: FPDF_PAGE read FHandle;
  end;

  /// <summary>
  /// Represents a PDF document
  /// </summary>
  TPdfDocument = class
  private
    FHandle: FPDF_DOCUMENT;
    FPageCount: Integer;
    FFileName: string;
    FMemoryBuffer: TBytes; // Buffer must remain valid while document is open!
    FStreamAdapter: TPdfStreamAdapter; // Stream adapter must remain valid while document is open!
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Loads a PDF document from a file
    /// </summary>
    procedure LoadFromFile(const AFileName: string; const APassword: string = '');

    /// <summary>
    /// Loads a PDF document from a stream (legacy method - loads entire stream into memory)
    /// </summary>
    /// <remarks>
    /// DEPRECATED: Use LoadFromStreamEx for efficient streaming support.
    /// This method reads the entire stream content into memory and keeps it for the lifetime
    /// of the document. For large PDFs, use LoadFromStreamEx or LoadFromFile instead.
    /// </remarks>
    procedure LoadFromStream(AStream: TStream; const APassword: string = '');

    /// <summary>
    /// Loads a PDF document from a stream with true streaming support (recommended)
    /// </summary>
    /// <remarks>
    /// This method uses PDFium's custom file access API for efficient streaming.
    /// The stream is NOT loaded entirely into memory - PDFium reads blocks on demand.
    /// The stream must remain valid and seekable for the lifetime of the document.
    /// Ideal for large PDFs, network streams, or memory-constrained scenarios.
    /// </remarks>
    /// <param name="AStream">Source stream (must support seeking)</param>
    /// <param name="AOwnsStream">If true, the document takes ownership and will free the stream on Close</param>
    /// <param name="APassword">Optional password for encrypted PDFs</param>
    procedure LoadFromStreamEx(AStream: TStream; AOwnsStream: Boolean = False; const APassword: string = '');

    /// <summary>
    /// Closes the currently loaded document
    /// </summary>
    procedure Close;

    /// <summary>
    /// Checks if a document is currently loaded
    /// </summary>
    function IsLoaded: Boolean;

    /// <summary>
    /// Gets a page by index (0-based). Caller is responsible for freeing the page.
    /// </summary>
    function GetPageByIndex(AIndex: Integer): TPdfPage;

    /// <summary>
    /// Gets the PDF file version (e.g., 14 for PDF 1.4, 17 for PDF 1.7)
    /// </summary>
    function GetFileVersion: Integer;

    /// <summary>
    /// Gets the PDF version as a string (e.g., "1.4", "1.7")
    /// </summary>
    function GetFileVersionString: string;

    /// <summary>
    /// Gets metadata from the PDF document (Title, Author, Subject, Keywords, Creator, Producer, CreationDate, ModDate)
    /// </summary>
    function GetMetadata(const ATag: string): string;

    /// <summary>
    /// Checks if the document is PDF/A compliant and returns the version (e.g., "PDF/A-1b", "PDF/A-2u")
    /// </summary>
    function GetPdfAInfo: string;

    /// <summary>
    /// Number of pages in the document
    /// </summary>
    property PageCount: Integer read FPageCount;

    /// <summary>
    /// File name of the loaded document
    /// </summary>
    property FileName: string read FFileName;

    /// <summary>
    /// Internal PDFium document handle
    /// </summary>
    property Handle: FPDF_DOCUMENT read FHandle;
  end;

  /// <summary>
  /// Global PDFium library manager (singleton)
  /// </summary>
  TPdfLibrary = class
  private
    class var FInstance: TPdfLibrary;
    class var FInitialized: Boolean;
    class var FReferenceCount: Integer;
    class function GetInstance: TPdfLibrary; static;
  public
    class constructor Create;
    class destructor Destroy;

    /// <summary>
    /// Initializes the PDFium library
    /// </summary>
    class procedure Initialize;

    /// <summary>
    /// Shuts down the PDFium library
    /// </summary>
    class procedure Finalize;

    /// <summary>
    /// Checks if the library is initialized
    /// </summary>
    class function IsInitialized: Boolean;

    /// <summary>
    /// Singleton instance
    /// </summary>
    class property Instance: TPdfLibrary read GetInstance;
  end;

implementation

uses
  System.Math;

{ TPdfStreamAdapter }

constructor TPdfStreamAdapter.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;

  // Initialize FPDF_FILEACCESS structure
  FFileAccess.m_FileLen := FStream.Size;
  FFileAccess.m_GetBlock := GetBlockCallback;
  FFileAccess.m_Param := Self;  // Pass Self as user data to callback
end;

destructor TPdfStreamAdapter.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

class function TPdfStreamAdapter.GetBlockCallback(param: Pointer; position: Cardinal;
  pBuf: PByte; size: Cardinal): Integer;
var
  LAdapter: TPdfStreamAdapter;
  LBytesRead: Integer;
begin
  Result := 0;  // Default: error

  if param = nil then
    Exit;

  LAdapter := TPdfStreamAdapter(param);

  try
    // Seek to requested position
    LAdapter.FStream.Position := position;

    // Read requested block
    LBytesRead := LAdapter.FStream.Read(pBuf^, size);

    // Return success if we read the expected amount
    if LBytesRead = Integer(size) then
      Result := 1  // Success
    else
      Result := 0; // Error: couldn't read full block
  except
    // Any exception = error
    Result := 0;
  end;
end;

{ TPdfLibrary }

class constructor TPdfLibrary.Create;
begin
  FInstance := nil;
  FInitialized := False;
  FReferenceCount := 0;
end;

class destructor TPdfLibrary.Destroy;
begin
  if FInitialized then
    Finalize;
  FreeAndNil(FInstance);
end;

class function TPdfLibrary.GetInstance: TPdfLibrary;
begin
  if FInstance = nil then
    FInstance := TPdfLibrary.Create;
  Result := FInstance;
end;

class procedure TPdfLibrary.Initialize;
begin
  if not FInitialized then
  begin
    FPDF_InitLibrary;
    FInitialized := True;
  end;
  Inc(FReferenceCount);
end;

class procedure TPdfLibrary.Finalize;
begin
  Dec(FReferenceCount);
  if (FReferenceCount <= 0) and FInitialized then
  begin
    FPDF_DestroyLibrary;
    FInitialized := False;
    FReferenceCount := 0;
  end;
end;

class function TPdfLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

{ TPdfDocument }

constructor TPdfDocument.Create;
begin
  inherited Create;
  FHandle := nil;
  FPageCount := 0;
  FFileName := '';
  SetLength(FMemoryBuffer, 0);
  FStreamAdapter := nil;
  TPdfLibrary.Initialize;
end;

destructor TPdfDocument.Destroy;
begin
  Close;
  TPdfLibrary.Finalize;
  inherited;
end;

procedure TPdfDocument.LoadFromFile(const AFileName: string; const APassword: string = '');
var
  LPasswordAnsi: AnsiString;
  LFilePathUtf8: UTF8String;
  LError: Cardinal;
begin
  Close;

  if not FileExists(AFileName) then
    raise EPdfLoadException.CreateFmt('File not found: %s', [AFileName]);

  LFilePathUtf8 := UTF8String(AFileName);
  if APassword <> '' then
    LPasswordAnsi := AnsiString(APassword)
  else
    LPasswordAnsi := '';

  FHandle := FPDF_LoadDocument(FPDF_STRING(PAnsiChar(LFilePathUtf8)), FPDF_BYTESTRING(PAnsiChar(LPasswordAnsi)));

  if FHandle = nil then
  begin
    LError := FPDF_GetLastError;
    raise EPdfLoadException.CreateFmt('Failed to load PDF: %s (%s)', [AFileName, FPDF_ErrorToString(LError)]);
  end;

  FFileName := AFileName;
  FPageCount := FPDF_GetPageCount(FHandle);
end;

procedure TPdfDocument.LoadFromStream(AStream: TStream; const APassword: string = '');
var
  LPasswordAnsi: AnsiString;
  LError: Cardinal;
begin
  Close;

  if AStream = nil then
    raise EPdfLoadException.Create('Stream is nil');

  // IMPORTANT: Buffer must remain valid while document is open!
  // Store in FMemoryBuffer field instead of local variable
  SetLength(FMemoryBuffer, AStream.Size);
  AStream.Position := 0;
  AStream.ReadBuffer(FMemoryBuffer[0], AStream.Size);

  if APassword <> '' then
    LPasswordAnsi := AnsiString(APassword)
  else
    LPasswordAnsi := '';

  FHandle := FPDF_LoadMemDocument(@FMemoryBuffer[0], Length(FMemoryBuffer), FPDF_BYTESTRING(PAnsiChar(LPasswordAnsi)));

  if FHandle = nil then
  begin
    LError := FPDF_GetLastError;
    raise EPdfLoadException.CreateFmt('Failed to load PDF from stream: %s', [FPDF_ErrorToString(LError)]);
  end;

  FFileName := '';
  FPageCount := FPDF_GetPageCount(FHandle);
end;

procedure TPdfDocument.LoadFromStreamEx(AStream: TStream; AOwnsStream: Boolean; const APassword: string);
var
  LPasswordAnsi: AnsiString;
  LError: Cardinal;
begin
  Close;

  if AStream = nil then
    raise EPdfLoadException.Create('Stream is nil');

  // Create stream adapter for PDFium's custom file access
  FStreamAdapter := TPdfStreamAdapter.Create(AStream, AOwnsStream);

  if APassword <> '' then
    LPasswordAnsi := AnsiString(APassword)
  else
    LPasswordAnsi := '';

  // Load using custom document API - enables true streaming!
  FHandle := FPDF_LoadCustomDocument(@FStreamAdapter.FFileAccess, FPDF_BYTESTRING(PAnsiChar(LPasswordAnsi)));

  if FHandle = nil then
  begin
    LError := FPDF_GetLastError;
    FreeAndNil(FStreamAdapter);  // Clean up on error
    raise EPdfLoadException.CreateFmt('Failed to load PDF from stream: %s', [FPDF_ErrorToString(LError)]);
  end;

  FFileName := '';
  FPageCount := FPDF_GetPageCount(FHandle);
end;

procedure TPdfDocument.Close;
begin
  if FHandle <> nil then
  begin
    FPDF_CloseDocument(FHandle);
    FHandle := nil;
    FPageCount := 0;
    FFileName := '';
  end;
  SetLength(FMemoryBuffer, 0); // Free memory buffer
  FreeAndNil(FStreamAdapter);   // Free stream adapter (and optionally the stream)
end;

function TPdfDocument.IsLoaded: Boolean;
begin
  Result := FHandle <> nil;
end;

function TPdfDocument.GetPageByIndex(AIndex: Integer): TPdfPage;
begin
  if not IsLoaded then
    raise EPdfPageException.Create('No document loaded');

  if (AIndex < 0) or (AIndex >= FPageCount) then
    raise EPdfPageException.CreateFmt('Page index out of range: %d (valid range: 0-%d)', [AIndex, FPageCount - 1]);

  Result := TPdfPage.Create(Self, AIndex);
end;

function TPdfDocument.GetFileVersion: Integer;
var
  LVersion: Integer;
begin
  Result := 0;
  if IsLoaded then
  begin
    if FPDF_BoolToBoolean(FPDF_GetFileVersion(FHandle, LVersion)) then
      Result := LVersion;
  end;
end;

function TPdfDocument.GetFileVersionString: string;
var
  LVersion: Integer;
begin
  LVersion := GetFileVersion;
  if LVersion > 0 then
    Result := Format('%d.%d', [LVersion div 10, LVersion mod 10])
  else
    Result := 'Unknown';
end;

function TPdfDocument.GetMetadata(const ATag: string): string;
var
  LBufLen: Cardinal;
  LBuffer: array of WideChar;
  LTagAnsi: AnsiString;
begin
  Result := '';
  if not IsLoaded then
    Exit;

  LTagAnsi := AnsiString(ATag);

  // Get required buffer size
  LBufLen := FPDF_GetMetaText(FHandle, FPDF_BYTESTRING(PAnsiChar(LTagAnsi)), nil, 0);
  if LBufLen <= 2 then // Empty or just null terminator
    Exit;

  // Allocate buffer and get metadata (UTF-16LE encoded)
  SetLength(LBuffer, LBufLen div 2);
  FPDF_GetMetaText(FHandle, FPDF_BYTESTRING(PAnsiChar(LTagAnsi)), @LBuffer[0], LBufLen);

  // Convert to string (remove null terminator)
  Result := string(PWideChar(@LBuffer[0])).Trim;
end;

function TPdfDocument.GetPdfAInfo: string;
var
  LProducer: string;
  LCreator: string;
  LSubject: string;
begin
  Result := '';
  if not IsLoaded then
    Exit;

  // Check Producer and Creator metadata for PDF/A information
  LProducer := GetMetadata('Producer');
  LCreator := GetMetadata('Creator');
  LSubject := GetMetadata('Subject');

  // Look for PDF/A markers in metadata
  if LProducer.ToUpper.Contains('PDF/A') then
  begin
    // Try to extract version (e.g., "PDF/A-1b", "PDF/A-2u", "PDF/A-3")
    if LProducer.ToUpper.Contains('PDF/A-1') then
      Result := 'PDF/A-1'
    else if LProducer.ToUpper.Contains('PDF/A-2') then
      Result := 'PDF/A-2'
    else if LProducer.ToUpper.Contains('PDF/A-3') then
      Result := 'PDF/A-3'
    else if LProducer.ToUpper.Contains('PDF/A-4') then
      Result := 'PDF/A-4'
    else
      Result := 'PDF/A';
  end
  else if LCreator.ToUpper.Contains('PDF/A') then
  begin
    if LCreator.ToUpper.Contains('PDF/A-1') then
      Result := 'PDF/A-1'
    else if LCreator.ToUpper.Contains('PDF/A-2') then
      Result := 'PDF/A-2'
    else if LCreator.ToUpper.Contains('PDF/A-3') then
      Result := 'PDF/A-3'
    else if LCreator.ToUpper.Contains('PDF/A-4') then
      Result := 'PDF/A-4'
    else
      Result := 'PDF/A';
  end
  else if LSubject.ToUpper.Contains('PDF/A') then
  begin
    if LSubject.ToUpper.Contains('PDF/A-1') then
      Result := 'PDF/A-1'
    else if LSubject.ToUpper.Contains('PDF/A-2') then
      Result := 'PDF/A-2'
    else if LSubject.ToUpper.Contains('PDF/A-3') then
      Result := 'PDF/A-3'
    else if LSubject.ToUpper.Contains('PDF/A-4') then
      Result := 'PDF/A-4'
    else
      Result := 'PDF/A';
  end;
end;

{ TPdfPage }

constructor TPdfPage.Create(ADocument: TPdfDocument; APageIndex: Integer);
begin
  inherited Create;
  FDocument := ADocument;
  FPageIndex := APageIndex;

  FHandle := FPDF_LoadPage(FDocument.Handle, FPageIndex);
  if FHandle = nil then
    raise EPdfPageException.CreateFmt('Failed to load page %d', [FPageIndex]);

  FWidth := FPDF_GetPageWidth(FHandle);
  FHeight := FPDF_GetPageHeight(FHandle);
end;

destructor TPdfPage.Destroy;
begin
  if FHandle <> nil then
    FPDF_ClosePage(FHandle);
  inherited;
end;

function TPdfPage.GetRotation: Integer;
begin
  if FHandle <> nil then
    Result := FPDFPage_GetRotation(FHandle)
  else
    Result := 0;
end;

procedure TPdfPage.RenderToBitmap(ABitmap: TBitmap; ABackgroundColor: TAlphaColor = TAlphaColors.White);
var
  LPdfBitmap: FPDF_BITMAP;
  LBuffer: Pointer;
  LStride: Integer;
  LBitmapData: TBitmapData;
  LSrcPtr: PByte;
  LDstPtr: PByte;
  LY: Integer;
  LX: Integer;
  LR, LG, LB, LA: Byte;
  LBgColor: FPDF_DWORD;
begin
  if FHandle = nil then
    raise EPdfRenderException.Create('Page not loaded');

  if ABitmap = nil then
    raise EPdfRenderException.Create('Bitmap is nil');

  // Bitmap size should already be set by caller to desired resolution
  // Don't resize here - caller determines the DPI/resolution

  // Validate bitmap has valid size
  if (ABitmap.Width <= 0) or (ABitmap.Height <= 0) then
    raise EPdfRenderException.Create('Bitmap has invalid size');

  // Create PDFium bitmap (BGRA format)
  LPdfBitmap := FPDFBitmap_Create(ABitmap.Width, ABitmap.Height, 1);
  if LPdfBitmap = nil then
    raise EPdfRenderException.Create('Failed to create PDFium bitmap');

  try
    // Fill with background color (convert ARGB to BGRA)
    LA := TAlphaColorRec(ABackgroundColor).A;
    LR := TAlphaColorRec(ABackgroundColor).R;
    LG := TAlphaColorRec(ABackgroundColor).G;
    LB := TAlphaColorRec(ABackgroundColor).B;
    LBgColor := (LA shl 24) or (LR shl 16) or (LG shl 8) or LB;
    FPDFBitmap_FillRect(LPdfBitmap, 0, 0, ABitmap.Width, ABitmap.Height, LBgColor);

    // Render PDF page to bitmap with high-quality settings
    // Use FPDF_ANNOT for annotations and FPDF_LCD_TEXT for better text rendering
    FPDF_RenderPageBitmap(
      LPdfBitmap,
      FHandle,
      0, 0,
      ABitmap.Width, ABitmap.Height,
      FPDF_ROTATE_0,
      FPDF_ANNOT or FPDF_LCD_TEXT
    );

    // Copy PDFium bitmap to FMX bitmap
    LBuffer := FPDFBitmap_GetBuffer(LPdfBitmap);
    LStride := FPDFBitmap_GetStride(LPdfBitmap);

    if ABitmap.Map(TMapAccess.Write, LBitmapData) then
    try
      LSrcPtr := LBuffer;
      for LY := 0 to ABitmap.Height - 1 do
      begin
        LDstPtr := LBitmapData.GetScanline(LY);
        for LX := 0 to ABitmap.Width - 1 do
        begin
          // PDFium uses BGRA, FMX uses BGRA on Windows, RGBA on other platforms
          LB := LSrcPtr^; Inc(LSrcPtr);
          LG := LSrcPtr^; Inc(LSrcPtr);
          LR := LSrcPtr^; Inc(LSrcPtr);
          LA := LSrcPtr^; Inc(LSrcPtr);

          {$IFDEF MSWINDOWS}
          // Windows: BGRA -> BGRA (no conversion needed)
          LDstPtr^ := LB; Inc(LDstPtr);
          LDstPtr^ := LG; Inc(LDstPtr);
          LDstPtr^ := LR; Inc(LDstPtr);
          LDstPtr^ := LA; Inc(LDstPtr);
          {$ELSE}
          // macOS/iOS/Android: BGRA -> RGBA
          LDstPtr^ := LR; Inc(LDstPtr);
          LDstPtr^ := LG; Inc(LDstPtr);
          LDstPtr^ := LB; Inc(LDstPtr);
          LDstPtr^ := LA; Inc(LDstPtr);
          {$ENDIF}
        end;
        // Skip to next scanline in source
        LSrcPtr := PByte(NativeInt(LBuffer) + (LY + 1) * LStride);
      end;
    finally
      ABitmap.Unmap(LBitmapData);
    end;
  finally
    FPDFBitmap_Destroy(LPdfBitmap);
  end;
end;

end.

