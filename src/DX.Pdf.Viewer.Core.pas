{*******************************************************************************
  Unit: DX.Pdf.Viewer.Core

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Abstract base class for PDF Viewer components.
    Provides framework-independent core functionality for FMX and VCL viewers.
    Handles document management, page navigation, rendering coordination,
    and text selection on the current page.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Viewer.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  DX.Pdf.Document;

type
  /// <summary>
  /// Placement of a rendered PDF page.
  /// Device coordinates match FPDF_RenderPageBitmap / FPDF_DeviceToPage:
  /// StartX/StartY are the scroll origin, SizeX/SizeY are the zoomed pixel
  /// size, and Rotate is the same extra rotation (0..3) passed to PDFium.
  /// Screen coordinates are control-local pixels. ScreenScale is control
  /// pixels per device pixel (1 for an unscaled VCL bitmap, 1/BitmapScale
  /// for an FMX bitmap).
  /// </summary>
  TPdfPageViewMap = record
    StartX: Integer;
    StartY: Integer;
    SizeX: Integer;
    SizeY: Integer;
    Rotate: Integer;
    ScreenLeft: Double;
    ScreenTop: Double;
    ScreenScaleX: Double;
    ScreenScaleY: Double;
  end;

  /// <summary>
  /// Abstract base class for PDF viewer components
  /// </summary>
  /// <remarks>
  /// This class provides framework-independent functionality for PDF viewing.
  /// Derived classes (FMX, VCL) implement the rendering and UI-specific parts.
  /// </remarks>
  TPdfViewerCore = class(TComponent)
  private
    FDocument: TPdfDocument;
    FCurrentPage: TPdfPage;
    FCurrentPageIndex: Integer;
    FBackgroundColor: TAlphaColor;
    FShowLoadingIndicator: Boolean;
    FOnPageChanged: TNotifyEvent;
    FIsRendering: Boolean;
    FSelectionEnabled: Boolean;
    FSelectionAnchor: Integer;
    FSelectionFocus: Integer;
    FOnSelectionChanged: TNotifyEvent;
    procedure SetCurrentPageIndex(const AValue: Integer);
    procedure SetBackgroundColor(const AValue: TAlphaColor);
    procedure SetShowLoadingIndicator(const AValue: Boolean);
    procedure SetSelectionEnabled(const AValue: Boolean);
    function GetPageCount: Integer;
    function NormalizeSelection(out AStart, ACount: Integer): Boolean;
  strict protected
    /// <summary>
    /// Called when the current page needs to be rendered
    /// </summary>
    /// <remarks>
    /// Must be implemented by derived classes to perform actual rendering
    /// </remarks>
    procedure DoRenderCurrentPage; virtual; abstract;

    /// <summary>
    /// Called when the background color changes
    /// </summary>
    procedure DoBackgroundColorChanged; virtual;

    /// <summary>
    /// Called when the loading indicator visibility should change
    /// </summary>
    procedure DoShowLoadingIndicator(AShow: Boolean); virtual; abstract;

    /// <summary>
    /// Called after the selection anchor or focus changes.
    /// </summary>
    procedure DoSelectionChanged; virtual;
  protected
    /// <summary>
    /// Triggers page rendering
    /// </summary>
    procedure RenderCurrentPage;

    /// <summary>
    /// Flag indicating if rendering is in progress
    /// </summary>
    property IsRendering: Boolean read FIsRendering write FIsRendering;
  public
    constructor Create(AOwner: TComponent); override;
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
    /// <param name="AOwnsStream">If true, the viewer takes ownership and will free the stream on Close</param>
    /// <param name="APassword">Optional password for encrypted PDFs</param>
    procedure LoadFromStream(AStream: TStream; AOwnsStream: Boolean = False; const APassword: string = '');

    /// <summary>
    /// Closes the currently loaded document
    /// </summary>
    procedure Close; virtual;

    /// <summary>
    /// Navigates to the next page
    /// </summary>
    procedure NextPage;

    /// <summary>
    /// Navigates to the previous page
    /// </summary>
    procedure PreviousPage;

    /// <summary>
    /// Navigates to the first page
    /// </summary>
    procedure FirstPage;

    /// <summary>
    /// Navigates to the last page
    /// </summary>
    procedure LastPage;

    /// <summary>
    /// Checks if a document is currently loaded
    /// </summary>
    function IsDocumentLoaded: Boolean;

    /// <summary>
    /// Current page index (0-based)
    /// </summary>
    property CurrentPageIndex: Integer read FCurrentPageIndex write SetCurrentPageIndex;

    /// <summary>
    /// Number of pages in the document
    /// </summary>
    property PageCount: Integer read GetPageCount;

    /// <summary>
    /// The PDF document object
    /// </summary>
    property Document: TPdfDocument read FDocument;

    /// <summary>
    /// Current page object (can be nil)
    /// </summary>
    property CurrentPage: TPdfPage read FCurrentPage write FCurrentPage;

    /// <summary>
    /// Background color for the viewer
    /// </summary>
    property BackgroundColor: TAlphaColor read FBackgroundColor write SetBackgroundColor;

    /// <summary>
    /// Show loading indicator overlay while rendering pages
    /// </summary>
    property ShowLoadingIndicator: Boolean read FShowLoadingIndicator write SetShowLoadingIndicator;

    /// <summary>
    /// Event fired when the current page changes
    /// </summary>
    property OnPageChanged: TNotifyEvent read FOnPageChanged write FOnPageChanged;

    /// <summary>
    /// Enables mouse and keyboard text selection. Defaults to True.
    /// Turning it off clears the current selection.
    /// </summary>
    property SelectionEnabled: Boolean read FSelectionEnabled write SetSelectionEnabled;

    /// <summary>
    /// Fired when the selected character range changes.
    /// </summary>
    property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;

    /// <summary>
    /// Anchor character index, or -1 when nothing is selected.
    /// </summary>
    property SelectionAnchor: Integer read FSelectionAnchor;

    /// <summary>
    /// Focus character index, or -1 when nothing is selected.
    /// The selected range is inclusive of both anchor and focus.
    /// </summary>
    property SelectionFocus: Integer read FSelectionFocus;

    /// <summary>
    /// True when a character range is selected on the current page.
    /// </summary>
    function HasSelection: Boolean;

    /// <summary>
    /// Sets the inclusive selection. Indices are clamped to the current
    /// page. A negative index clears the selection. Ignored when
    /// selection is disabled.
    /// </summary>
    procedure SetSelection(AAnchor, AFocus: Integer);

    /// <summary>
    /// Clears the selection. Does nothing when it is already clear.
    /// </summary>
    procedure ClearSelection;

    /// <summary>
    /// Selects every character on the current page.
    /// </summary>
    procedure SelectAll;

    /// <summary>
    /// Expands the selection to the word that contains ACharIndex.
    /// A word is a run of letters, digits, or non-ASCII characters.
    /// </summary>
    procedure SelectWordAt(ACharIndex: Integer);

    /// <summary>
    /// Text covered by the current selection, or an empty string.
    /// </summary>
    function GetSelectedText: string;

    /// <summary>
    /// Selection rectangles in PDF page coordinates (origin bottom-left, Y up).
    /// </summary>
    function GetSelectionRects: TArray<TRectF>;

    /// <summary>
    /// Selection rectangles in control-local screen pixels (Y down).
    /// </summary>
    function GetSelectionScreenRects(const AMap: TPdfPageViewMap): TArray<TRectF>;

    /// <summary>
    /// Character under a control-local point, using AMap for zoom, scroll,
    /// rotation and the PDF bottom-up Y axis. Tolerance is a few device
    /// pixels expressed in page units, with a nearest-character fallback.
    /// Returns -1 when selection is disabled or no character is close.
    /// </summary>
    function CharIndexAtScreenPoint(const AMap: TPdfPageViewMap; AScreenX, AScreenY: Double): Integer;
  end;

  /// <summary>
  /// Converts a control-local point to device pixels for AMap.
  /// </summary>
function PdfScreenToDevice(const AMap: TPdfPageViewMap; AScreenX, AScreenY: Double;
    out ADeviceX, ADeviceY: Integer): Boolean;

  /// <summary>
  /// Converts device pixels to a control-local point for AMap.
  /// </summary>
function PdfDeviceToScreen(const AMap: TPdfPageViewMap; ADeviceX, ADeviceY: Integer;
    out AScreenX, AScreenY: Double): Boolean;

  /// <summary>
  /// Maps a PDF-space rectangle (Y up) to a normalized screen rectangle (Y down).
  /// All four corners are converted so rotation is covered.
  /// </summary>
function PdfRectToScreen(APage: TPdfPage; const AMap: TPdfPageViewMap; const APdfRect: TRectF;
    out AScreenRect: TRectF): Boolean;

implementation

uses
  System.Math;

function PdfScreenToDevice(const AMap: TPdfPageViewMap; AScreenX, AScreenY: Double;
  out ADeviceX, ADeviceY: Integer): Boolean;
begin
  ADeviceX := 0;
  ADeviceY := 0;
  Result := (AMap.SizeX > 0) and (AMap.SizeY > 0) and
    (AMap.ScreenScaleX <> 0) and (AMap.ScreenScaleY <> 0);
  if not Result then
    Exit;
  ADeviceX := Round((AScreenX - AMap.ScreenLeft) / AMap.ScreenScaleX);
  ADeviceY := Round((AScreenY - AMap.ScreenTop) / AMap.ScreenScaleY);
end;

function PdfDeviceToScreen(const AMap: TPdfPageViewMap; ADeviceX, ADeviceY: Integer;
  out AScreenX, AScreenY: Double): Boolean;
begin
  AScreenX := 0;
  AScreenY := 0;
  Result := (AMap.SizeX > 0) and (AMap.SizeY > 0) and
    (AMap.ScreenScaleX <> 0) and (AMap.ScreenScaleY <> 0);
  if not Result then
    Exit;
  AScreenX := AMap.ScreenLeft + (ADeviceX * AMap.ScreenScaleX);
  AScreenY := AMap.ScreenTop + (ADeviceY * AMap.ScreenScaleY);
end;

function PdfRectToScreen(APage: TPdfPage; const AMap: TPdfPageViewMap; const APdfRect: TRectF;
  out AScreenRect: TRectF): Boolean;
var
  LCorners: array[0..3] of TPointF;
  LDeviceX, LDeviceY: Integer;
  LScreenX, LScreenY: Double;
  LMinX, LMinY, LMaxX, LMaxY: Double;
  I: Integer;
begin
  AScreenRect := TRectF.Empty;
  Result := (APage <> nil) and (AMap.SizeX > 0) and (AMap.SizeY > 0);
  if not Result then
    Exit;

  LCorners[0] := TPointF.Create(APdfRect.Left, APdfRect.Top);
  LCorners[1] := TPointF.Create(APdfRect.Right, APdfRect.Top);
  LCorners[2] := TPointF.Create(APdfRect.Right, APdfRect.Bottom);
  LCorners[3] := TPointF.Create(APdfRect.Left, APdfRect.Bottom);

  LMinX := MaxDouble;
  LMinY := MaxDouble;
  LMaxX := -MaxDouble;
  LMaxY := -MaxDouble;
  for I := 0 to 3 do
  begin
    if not APage.PageToDevice(AMap.StartX, AMap.StartY, AMap.SizeX, AMap.SizeY, AMap.Rotate,
      LCorners[I].X, LCorners[I].Y, LDeviceX, LDeviceY) then
      Exit(False);
    if not PdfDeviceToScreen(AMap, LDeviceX, LDeviceY, LScreenX, LScreenY) then
      Exit(False);
    if LScreenX < LMinX then
      LMinX := LScreenX;
    if LScreenY < LMinY then
      LMinY := LScreenY;
    if LScreenX > LMaxX then
      LMaxX := LScreenX;
    if LScreenY > LMaxY then
      LMaxY := LScreenY;
  end;

  if (LMaxX <= LMinX) or (LMaxY <= LMinY) then
    Exit(False);

  AScreenRect.Left := LMinX;
  AScreenRect.Top := LMinY;
  AScreenRect.Right := LMaxX;
  AScreenRect.Bottom := LMaxY;
  Result := True;
end;

function IsPdfWordCodePoint(ACode: Cardinal): Boolean;
begin
  if (ACode = 0) or (ACode <= 32) then
    Exit(False);
  if ACode < 128 then
    Result := ((ACode >= Ord('0')) and (ACode <= Ord('9'))) or
      ((ACode >= Ord('A')) and (ACode <= Ord('Z'))) or
      ((ACode >= Ord('a')) and (ACode <= Ord('z'))) or
      (ACode = Ord('_')) or (ACode = Ord(''''))
  else
    Result := True;
end;

{ TPdfViewerCore }

constructor TPdfViewerCore.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDocument := TPdfDocument.Create;
  FCurrentPage := nil;
  FCurrentPageIndex := -1;
  FBackgroundColor := TAlphaColors.White;
  FShowLoadingIndicator := True;
  FIsRendering := False;
  FSelectionEnabled := True;
  FSelectionAnchor := -1;
  FSelectionFocus := -1;
end;

destructor TPdfViewerCore.Destroy;
begin
  Close;
  FreeAndNil(FDocument);
  inherited;
end;

procedure TPdfViewerCore.LoadFromFile(const AFileName: string; const APassword: string);
begin
  Close;
  FDocument.LoadFromFile(AFileName, APassword);
  if FDocument.PageCount > 0 then
    SetCurrentPageIndex(0)
  else
    FCurrentPageIndex := -1;
end;

procedure TPdfViewerCore.LoadFromStream(AStream: TStream; AOwnsStream: Boolean; const APassword: string);
begin
  Close;
  FDocument.LoadFromStream(AStream, AOwnsStream, APassword);
  if FDocument.PageCount > 0 then
    SetCurrentPageIndex(0)
  else
    FCurrentPageIndex := -1;
end;

procedure TPdfViewerCore.Close;
begin
  ClearSelection;
  FreeAndNil(FCurrentPage);
  FCurrentPageIndex := -1;
  FDocument.Close;
end;

function TPdfViewerCore.IsDocumentLoaded: Boolean;
begin
  Result := FDocument.IsLoaded;
end;

function TPdfViewerCore.GetPageCount: Integer;
begin
  if IsDocumentLoaded then
    Result := FDocument.PageCount
  else
    Result := 0;
end;

procedure TPdfViewerCore.SetCurrentPageIndex(const AValue: Integer);
begin
  if not IsDocumentLoaded then
    Exit;

  if (AValue < 0) or (AValue >= FDocument.PageCount) then
    Exit;

  if FCurrentPageIndex <> AValue then
  begin
    FCurrentPageIndex := AValue;
    ClearSelection;
    RenderCurrentPage;
    if Assigned(FOnPageChanged) then
      FOnPageChanged(Self);
  end;
end;

procedure TPdfViewerCore.SetBackgroundColor(const AValue: TAlphaColor);
begin
  if FBackgroundColor <> AValue then
  begin
    FBackgroundColor := AValue;
    DoBackgroundColorChanged;
  end;
end;

procedure TPdfViewerCore.SetShowLoadingIndicator(const AValue: Boolean);
begin
  if FShowLoadingIndicator <> AValue then
  begin
    FShowLoadingIndicator := AValue;

    // If disabling while currently showing, hide it
    if not AValue then
      DoShowLoadingIndicator(False);
  end;
end;

procedure TPdfViewerCore.DoBackgroundColorChanged;
begin
  if IsDocumentLoaded then
    RenderCurrentPage;
end;

procedure TPdfViewerCore.RenderCurrentPage;
begin
  if not IsDocumentLoaded then
    Exit;

  if (FCurrentPageIndex < 0) or (FCurrentPageIndex >= FDocument.PageCount) then
    Exit;

  if FIsRendering then
    Exit;

  FIsRendering := True;

  // Show loading indicator
  DoShowLoadingIndicator(True);

  // Delegate to derived class
  DoRenderCurrentPage;
end;

procedure TPdfViewerCore.NextPage;
begin
  if IsDocumentLoaded and (FCurrentPageIndex < FDocument.PageCount - 1) then
    SetCurrentPageIndex(FCurrentPageIndex + 1);
end;

procedure TPdfViewerCore.PreviousPage;
begin
  if IsDocumentLoaded and (FCurrentPageIndex > 0) then
    SetCurrentPageIndex(FCurrentPageIndex - 1);
end;

procedure TPdfViewerCore.FirstPage;
begin
  if IsDocumentLoaded then
    SetCurrentPageIndex(0);
end;

procedure TPdfViewerCore.LastPage;
begin
  if IsDocumentLoaded and (FDocument.PageCount > 0) then
    SetCurrentPageIndex(FDocument.PageCount - 1);
end;

procedure TPdfViewerCore.DoSelectionChanged;
begin
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(Self);
end;

procedure TPdfViewerCore.SetSelectionEnabled(const AValue: Boolean);
begin
  if FSelectionEnabled = AValue then
    Exit;
  FSelectionEnabled := AValue;
  if not AValue then
    ClearSelection;
end;

function TPdfViewerCore.HasSelection: Boolean;
begin
  Result := FSelectionEnabled and (FCurrentPage <> nil) and
    (FSelectionAnchor >= 0) and (FSelectionFocus >= 0);
end;

function TPdfViewerCore.NormalizeSelection(out AStart, ACount: Integer): Boolean;
var
  LStart, LEnd, LCharCount: Integer;
begin
  AStart := 0;
  ACount := 0;
  Result := HasSelection;
  if not Result then
    Exit;
  LCharCount := FCurrentPage.GetCharCount;
  if LCharCount <= 0 then
    Exit(False);
  LStart := Min(FSelectionAnchor, FSelectionFocus);
  LEnd := Max(FSelectionAnchor, FSelectionFocus);
  if LStart < 0 then
    LStart := 0;
  if LEnd >= LCharCount then
    LEnd := LCharCount - 1;
  if LEnd < LStart then
    Exit(False);
  AStart := LStart;
  ACount := LEnd - LStart + 1;
  Result := True;
end;

procedure TPdfViewerCore.SetSelection(AAnchor, AFocus: Integer);
var
  LCharCount: Integer;
begin
  if not FSelectionEnabled then
    Exit;
  if (FCurrentPage = nil) or (AAnchor < 0) or (AFocus < 0) then
  begin
    ClearSelection;
    Exit;
  end;

  LCharCount := FCurrentPage.GetCharCount;
  if LCharCount <= 0 then
  begin
    ClearSelection;
    Exit;
  end;

  if AAnchor >= LCharCount then
    AAnchor := LCharCount - 1;
  if AFocus >= LCharCount then
    AFocus := LCharCount - 1;

  if (FSelectionAnchor = AAnchor) and (FSelectionFocus = AFocus) then
    Exit;

  FSelectionAnchor := AAnchor;
  FSelectionFocus := AFocus;
  DoSelectionChanged;
end;

procedure TPdfViewerCore.ClearSelection;
begin
  if (FSelectionAnchor < 0) and (FSelectionFocus < 0) then
    Exit;
  FSelectionAnchor := -1;
  FSelectionFocus := -1;
  DoSelectionChanged;
end;

procedure TPdfViewerCore.SelectAll;
var
  LCharCount: Integer;
begin
  if not FSelectionEnabled then
    Exit;
  if FCurrentPage = nil then
    Exit;
  LCharCount := FCurrentPage.GetCharCount;
  if LCharCount <= 0 then
  begin
    ClearSelection;
    Exit;
  end;
  SetSelection(0, LCharCount - 1);
end;

procedure TPdfViewerCore.SelectWordAt(ACharIndex: Integer);
var
  LCharCount, LStart, LEnd: Integer;
begin
  if not FSelectionEnabled then
    Exit;
  if FCurrentPage = nil then
    Exit;
  LCharCount := FCurrentPage.GetCharCount;
  if (ACharIndex < 0) or (ACharIndex >= LCharCount) then
    Exit;

  if not IsPdfWordCodePoint(FCurrentPage.GetUnicode(ACharIndex)) then
  begin
    SetSelection(ACharIndex, ACharIndex);
    Exit;
  end;

  LStart := ACharIndex;
  while (LStart > 0) and IsPdfWordCodePoint(FCurrentPage.GetUnicode(LStart - 1)) do
    Dec(LStart);

  LEnd := ACharIndex;
  while (LEnd < LCharCount - 1) and IsPdfWordCodePoint(FCurrentPage.GetUnicode(LEnd + 1)) do
    Inc(LEnd);

  SetSelection(LStart, LEnd);
end;

function TPdfViewerCore.GetSelectedText: string;
var
  LStart, LCount: Integer;
begin
  Result := '';
  if not NormalizeSelection(LStart, LCount) then
    Exit;
  Result := FCurrentPage.GetText(LStart, LCount);
end;

function TPdfViewerCore.GetSelectionRects: TArray<TRectF>;
var
  LStart, LCount, LRectCount, I, LOut: Integer;
  LRect: TRectF;
begin
  Result := nil;
  if not NormalizeSelection(LStart, LCount) then
    Exit;
  LRectCount := FCurrentPage.CountRects(LStart, LCount);
  if LRectCount <= 0 then
    Exit;

  SetLength(Result, LRectCount);
  LOut := 0;
  for I := 0 to LRectCount - 1 do
  begin
    if FCurrentPage.GetRect(I, LRect) then
    begin
      Result[LOut] := LRect;
      Inc(LOut);
    end;
  end;
  SetLength(Result, LOut);
end;

function TPdfViewerCore.GetSelectionScreenRects(const AMap: TPdfPageViewMap): TArray<TRectF>;
var
  LPdfRects: TArray<TRectF>;
  LScreen: TRectF;
  I, LOut: Integer;
begin
  LPdfRects := GetSelectionRects;
  SetLength(Result, Length(LPdfRects));
  LOut := 0;
  for I := 0 to High(LPdfRects) do
  begin
    if PdfRectToScreen(FCurrentPage, AMap, LPdfRects[I], LScreen) then
    begin
      Result[LOut] := LScreen;
      Inc(LOut);
    end;
  end;
  SetLength(Result, LOut);
end;

function TPdfViewerCore.CharIndexAtScreenPoint(const AMap: TPdfPageViewMap;
  AScreenX, AScreenY: Double): Integer;
var
  LDeviceX, LDeviceY, LRotate: Integer;
  LPageX, LPageY, LTolX, LTolY: Double;
begin
  Result := -1;
  if (not FSelectionEnabled) or (FCurrentPage = nil) then
    Exit;
  if not PdfScreenToDevice(AMap, AScreenX, AScreenY, LDeviceX, LDeviceY) then
    Exit;
  if not FCurrentPage.DeviceToPage(AMap.StartX, AMap.StartY, AMap.SizeX, AMap.SizeY, AMap.Rotate,
    LDeviceX, LDeviceY, LPageX, LPageY) then
    Exit;

  // A few device pixels, expressed in page units, so the hit target grows
  // when the page is zoomed out. Swap axes when the render rotation turns
  // device X into page Y.
  LTolX := 2.0;
  LTolY := 2.0;
  LRotate := AMap.Rotate mod 4;
  if LRotate < 0 then
    Inc(LRotate, 4);
  if LRotate in [1, 3] then
  begin
    if (AMap.SizeY > 0) and (FCurrentPage.Width > 0) then
      LTolX := Max(2.0, 4.0 * FCurrentPage.Width / AMap.SizeY);
    if (AMap.SizeX > 0) and (FCurrentPage.Height > 0) then
      LTolY := Max(2.0, 4.0 * FCurrentPage.Height / AMap.SizeX);
  end
  else
  begin
    if (AMap.SizeX > 0) and (FCurrentPage.Width > 0) then
      LTolX := Max(2.0, 4.0 * FCurrentPage.Width / AMap.SizeX);
    if (AMap.SizeY > 0) and (FCurrentPage.Height > 0) then
      LTolY := Max(2.0, 4.0 * FCurrentPage.Height / AMap.SizeY);
  end;

  Result := FCurrentPage.CharIndexNearPos(LPageX, LPageY, LTolX, LTolY);
end;

end.

