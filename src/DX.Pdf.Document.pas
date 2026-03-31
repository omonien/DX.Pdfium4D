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
  System.Generics.Collections,
  System.UITypes,
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

  IPageSearch = interface
    ['{1B27E43D-FEA8-4A5F-8615-BF4FFC79497E}']
    function FindNext: Boolean;
    function FindPrev: Boolean;
    function GetResultIndex: Integer;
    function GetCount: Integer;
  end;

  TSearchNotify = TProc;

  TPageSearch = class(TInterfacedObject, IPageSearch)
  private
    FHandleSearch: FPDF_SCHHANDLE;
    FPage: TPdfPage;
    procedure NotifyHandle;
  public
    function FindNext: Boolean;
    function FindPrev: Boolean;
    function GetResultIndex: Integer;
    function GetCount: Integer;
    constructor Create(APage: TPdfPage; const AFindwhat: string; const AFlags: DWORD; const AStartIndex: Integer); reintroduce;
    destructor Destroy; override;
  end;

  /// <summary>
  /// Represents a single page in a PDF document
  /// </summary>
  TPdfPage = class
  private
    FDocument: TPdfDocument;
    FHandle: FPDF_PAGE;
    FHandleText: FPDF_TEXTPAGE;
    FPageIndex: Integer;
    FWidth: Double;
    FHeight: Double;
    FSearchNotifies: TList<TSearchNotify>;
    function GetRotation: Integer;
    procedure AddSearchNotify(ASearch: TSearchNotify);
    procedure RemoveSearchNotify(ASearch: TSearchNotify);
  public
    constructor Create(ADocument: TPdfDocument; APageIndex: Integer);
    destructor Destroy; override;

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

    function GetCharBox(const AIndex: Integer): TRectF;
    function GetCharIndexAtPos(const AX, AY, AXTolerance, AYTolerance: Double): Integer;
    function GetCharRect(const AIndex: Integer; var ARect: TRectF): Boolean;
    function FindStart(const AFindwhat: string; const AFlags: DWORD; const AStartIndex: Integer): IPageSearch;

    function CountRects(const AStartIndex, ACount: Integer): Integer;
    function GetBoundedText(const ARect: TRectF; const ABuffer: string): Integer;
  end;

  /// <summary>
  /// Represents a PDF document
  /// </summary>
  TPdfDocument = class
  private
    FHandle: FPDF_DOCUMENT;
    FPageCount: Integer;
    FFileName: string;
    FStreamAdapter: TPdfStreamAdapter; // Stream adapter must remain valid while document is open!
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Loads a PDF document from a file
    /// </summary>
    procedure LoadFromFile(const AFileName: string; const APassword: string = '');

    /// <summary>
    /// Loads a PDF document from a stream with efficient streaming support
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
    procedure LoadFromStream(AStream: TStream; AOwnsStream: Boolean = False; const APassword: string = '');

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

function ConvertPDFCoordsToCanvas(PDFRect: TRectF; PageHeight: Double; CanvasDPI: Integer = 96): TRectF;
var
  PointsToPixels: Double;
begin
  PointsToPixels := CanvasDPI / 72.0; // 72 points per inch

  Result.Left := PDFRect.Left * PointsToPixels;
  Result.Right := PDFRect.Right * PointsToPixels;

  Result.Top := (PageHeight - PDFRect.Top) * PointsToPixels;
  Result.Bottom := (PageHeight - PDFRect.Bottom) * PointsToPixels;
end;

function ConvertCanvasCoordsToPDF(const CanvasRect: TRectF; PageHeight: Double; CanvasDPI: Integer = 96): TRectF;
var
  PixelsToPoints: Double;
begin
  PixelsToPoints := 72.0 / CanvasDPI;

  Result.Left := CanvasRect.Left * PixelsToPoints;
  Result.Right := CanvasRect.Right * PixelsToPoints;

  Result.Top := PageHeight - (CanvasRect.Bottom * PixelsToPoints);
  Result.Bottom := PageHeight - (CanvasRect.Top * PixelsToPoints);
end;

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

procedure TPdfDocument.LoadFromStream(AStream: TStream; AOwnsStream: Boolean; const APassword: string);
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

procedure TPdfPage.AddSearchNotify(ASearch: TSearchNotify);
begin
  FSearchNotifies.Add(ASearch);
end;

function TPdfPage.CountRects(const AStartIndex, ACount: Integer): Integer;
begin
  Result := FPDFText_CountRects(FHandleText, AStartIndex, ACount);
end;

constructor TPdfPage.Create(ADocument: TPdfDocument; APageIndex: Integer);
begin
  inherited Create;
  FSearchNotifies := TList<TSearchNotify>.Create;
  FDocument := ADocument;
  FPageIndex := APageIndex;

  FHandle := FPDF_LoadPage(FDocument.Handle, FPageIndex);
  if FHandle = nil then
    raise EPdfPageException.CreateFmt('Failed to load page %d', [FPageIndex]);
  FHandleText := FPDFText_LoadPage(FHandle);
  if FHandleText = nil then
    raise EPdfPageException.CreateFmt('Failed to load text page %d', [FPageIndex]);

  FWidth := FPDF_GetPageWidth(FHandle);
  FHeight := FPDF_GetPageHeight(FHandle);
end;

destructor TPdfPage.Destroy;
begin
  if FHandleText <> nil then
    FPDFText_ClosePage(FHandleText);
  if FHandle <> nil then
    FPDF_ClosePage(FHandle);
  // Notify search instancies
  for var Notify in FSearchNotifies do
    Notify();
  FSearchNotifies.Free;
  inherited;
end;

function TPdfPage.FindStart(const AFindwhat: string; const AFlags: DWORD; const AStartIndex: Integer): IPageSearch;
begin
  Result := TPageSearch.Create(Self, AFindwhat, AFlags, AStartIndex);
end;

function TPdfPage.GetBoundedText(const ARect: TRectF; const ABuffer: string): Integer;
begin
  var FRect := ConvertCanvasCoordsToPDF(ARect, Height);
  Result := FPDFText_GetBoundedText(FHandleText, FRect.Left, FRect.Top, FRect.Right, FRect.Bottom, PWideChar(ABuffer), ABuffer.Length);
end;

function TPdfPage.GetCharBox(const AIndex: Integer): TRectF;
var
  Left, Right, Bottom, Top: Double;
begin
  FPDFText_GetCharBox(FHandleText, AIndex, Left, Right, Bottom, Top);
  Result := ConvertPDFCoordsToCanvas(TRectF.Create(Left, Top, Right, Bottom), Height);
end;

function TPdfPage.GetCharIndexAtPos(const AX, AY, AXTolerance, AYTolerance: Double): Integer;
begin
  Result := FPDFText_GetCharIndexAtPos(FHandleText, AX, AY, AXTolerance, AYTolerance);
end;

function TPdfPage.GetCharRect(const AIndex: Integer; var ARect: TRectF): Boolean;
var
  Left, Right, Bottom, Top: Double;
begin
  Result := FPDFText_GetRect(FHandleText, AIndex, Left, Top, Right, Bottom);
  ARect := ConvertPDFCoordsToCanvas(TRectF.Create(Left, Top, Right, Bottom), Height);
end;

function TPdfPage.GetRotation: Integer;
begin
  Result := FPDFPage_GetRotation(FHandle);
end;

procedure TPdfPage.RemoveSearchNotify(ASearch: TSearchNotify);
begin
  FSearchNotifies.Remove(ASearch);
end;

{ TPageSearch }

constructor TPageSearch.Create(APage: TPdfPage; const AFindwhat: string; const AFlags: DWORD; const AStartIndex: Integer);
begin
  inherited Create;
  FPage := APage;
  FHandleSearch := FPDFText_FindStart(FPage.FHandleText, PWideChar(AFindwhat), AFlags, AStartIndex);
  FPage.AddSearchNotify(NotifyHandle);
end;

destructor TPageSearch.Destroy;
begin
  if Assigned(FPage) then
    FPage.RemoveSearchNotify(NotifyHandle);
  inherited;
end;

function TPageSearch.FindNext: Boolean;
begin
  if FPage = nil then
    Exit(False);
  Result := FPDFText_FindNext(FHandleSearch);
end;

function TPageSearch.FindPrev: Boolean;
begin
  if FPage = nil then
    Exit(False);
  Result := FPDFText_FindPrev(FHandleSearch);
end;

function TPageSearch.GetCount: Integer;
begin
  if FPage = nil then
    Exit(0);
  Result := FPDFText_GetSchCount(FHandleSearch);
end;

function TPageSearch.GetResultIndex: Integer;
begin
  if FPage = nil then
    Exit(0);
  Result := FPDFText_GetSchResultIndex(FHandleSearch);
end;

procedure TPageSearch.NotifyHandle;
begin
  FPage := nil;
end;

end.

