{*******************************************************************************
  Unit: DX.Pdf.Viewer.VCL

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    VCL PDF Viewer Component.
    Provides a visual component for displaying PDF documents in VCL applications.
    Supports navigation, zooming, drag-and-drop, and text selection.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Viewer.VCL;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Threading,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Forms,
  DX.Pdf.API,
  DX.Pdf.Document,
  DX.Pdf.Renderer.VCL,  // VCL-specific renderer
  DX.Pdf.Viewer.Core;

type
  /// <summary>
  /// VCL component for displaying PDF documents
  /// </summary>
  TPdfViewer = class(TCustomControl)
  private
    FCore: TPdfViewerCore;
    FImage: TImage;
    FLoadingPanel: TPanel;
    FLoadingLabel: TLabel;
    FSelectionOverlay: TPaintBox;
    FRenderTask: ITask;
    FPageViewMap: TPdfPageViewMap;
    FSelecting: Boolean;
    function GetCurrentPageIndex: Integer;
    procedure SetCurrentPageIndex(const AValue: Integer);
    function GetBackgroundColor: TColor;
    procedure SetBackgroundColor(const AValue: TColor);
    function GetShowLoadingIndicator: Boolean;
    procedure SetShowLoadingIndicator(const AValue: Boolean);
    function GetPageCount: Integer;
    function GetDocument: TPdfDocument;
    function GetOnPageChanged: TNotifyEvent;
    procedure SetOnPageChanged(const AValue: TNotifyEvent);
    function GetSelectionEnabled: Boolean;
    procedure SetSelectionEnabled(const AValue: Boolean);
    function GetOnSelectionChanged: TNotifyEvent;
    procedure SetOnSelectionChanged(const AValue: TNotifyEvent);
    procedure RenderPageInBackground;
    procedure OnRenderComplete(ABitmap: Vcl.Graphics.TBitmap; AImageWidth, AImageHeight, AControlWidth, AControlHeight: Integer);
    procedure CreateImage;
    procedure CreateLoadingIndicator;
    procedure CreateSelectionOverlay;
    procedure SelectionOverlayPaint(Sender: TObject);
    procedure DoShowLoadingIndicatorInternal(AShow: Boolean);
    procedure UpdatePageViewMap(AImageLeft, AImageTop, AImageWidth, AImageHeight: Integer);
    function CharIndexAtLocalPoint(X, Y: Integer): Integer;
    function IsPointOnPage(X, Y: Integer): Boolean;
    procedure InvalidateSelection;
  protected
    procedure Resize; override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
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
    procedure Close;

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
    /// The PDF document object
    /// </summary>
    property Document: TPdfDocument read GetDocument;

    /// <summary>
    /// Clears the text selection on the current page.
    /// </summary>
    procedure ClearSelection;

    /// <summary>
    /// Selects every character on the current page.
    /// </summary>
    procedure SelectAll;

    /// <summary>
    /// Selects the word that contains ACharIndex.
    /// </summary>
    procedure SelectWordAt(ACharIndex: Integer);

    /// <summary>
    /// True when a character range is selected.
    /// </summary>
    function HasSelection: Boolean;

    /// <summary>
    /// Text covered by the current selection.
    /// </summary>
    function GetSelectedText: string;

    /// <summary>
    /// Copies the current selection to the clipboard.
    /// </summary>
    procedure CopySelection;
  published
    /// <summary>
    /// Current page index (0-based)
    /// </summary>
    property CurrentPageIndex: Integer read GetCurrentPageIndex write SetCurrentPageIndex default -1;

    /// <summary>
    /// Number of pages in the document
    /// </summary>
    property PageCount: Integer read GetPageCount stored False;

    /// <summary>
    /// Background color for the viewer
    /// </summary>
    property BackgroundColor: TColor read GetBackgroundColor write SetBackgroundColor default clWhite;

    /// <summary>
    /// Show loading indicator overlay while rendering pages
    /// </summary>
    property ShowLoadingIndicator: Boolean read GetShowLoadingIndicator write SetShowLoadingIndicator default True;

    /// <summary>
    /// Event fired when the current page changes
    /// </summary>
    property OnPageChanged: TNotifyEvent read GetOnPageChanged write SetOnPageChanged;

    /// <summary>
    /// Enables text selection and copy. Defaults to True.
    /// </summary>
    property SelectionEnabled: Boolean read GetSelectionEnabled write SetSelectionEnabled default True;

    /// <summary>
    /// Fired when the selected character range changes.
    /// </summary>
    property OnSelectionChanged: TNotifyEvent read GetOnSelectionChanged write SetOnSelectionChanged;

    // Inherited published properties
    property Align;
    property Anchors;
    property Color default clWhite;
    property ParentColor;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnResize;
  end;

implementation

uses
  System.Math,
  Vcl.Clipbrd,
  Vcl.Dialogs;

type
  /// <summary>
  /// VCL-specific implementation of TPdfViewerCore
  /// </summary>
  TPdfViewerCoreVCL = class(TPdfViewerCore)
  private
    FViewer: TPdfViewer;
  protected
    procedure DoRenderCurrentPage; override;
    procedure DoShowLoadingIndicator(AShow: Boolean); override;
    procedure DoSelectionChanged; override;
  public
    constructor Create(AViewer: TPdfViewer); reintroduce;

    // Public accessors for protected members (for TPdfViewer)
    function GetCurrentPage: TPdfPage;
    procedure SetCurrentPage(const AValue: TPdfPage);
    function GetIsRendering: Boolean;
    procedure SetIsRendering(const AValue: Boolean);
    procedure CallRenderCurrentPage;
  end;

{ TPdfViewerCoreVCL }

constructor TPdfViewerCoreVCL.Create(AViewer: TPdfViewer);
begin
  inherited Create(AViewer);
  FViewer := AViewer;
end;

procedure TPdfViewerCoreVCL.DoRenderCurrentPage;
begin
  FViewer.RenderPageInBackground;
end;

procedure TPdfViewerCoreVCL.DoShowLoadingIndicator(AShow: Boolean);
begin
  FViewer.DoShowLoadingIndicatorInternal(AShow);
end;

function TPdfViewerCoreVCL.GetCurrentPage: TPdfPage;
begin
  Result := CurrentPage;
end;

procedure TPdfViewerCoreVCL.SetCurrentPage(const AValue: TPdfPage);
begin
  CurrentPage := AValue;
end;

function TPdfViewerCoreVCL.GetIsRendering: Boolean;
begin
  Result := IsRendering;
end;

procedure TPdfViewerCoreVCL.SetIsRendering(const AValue: Boolean);
begin
  IsRendering := AValue;
end;

procedure TPdfViewerCoreVCL.CallRenderCurrentPage;
begin
  RenderCurrentPage;
end;

procedure TPdfViewerCoreVCL.DoSelectionChanged;
begin
  inherited;
  if FViewer <> nil then
    FViewer.InvalidateSelection;
end;

{ TPdfViewer }

constructor TPdfViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCore := TPdfViewerCoreVCL.Create(Self);

  // Enable keyboard and mouse input
  TabStop := True;
  Color := $00F0F0F0; // Light gray background
  ControlStyle := ControlStyle + [csOpaque];

  CreateImage;
  CreateLoadingIndicator;
  CreateSelectionOverlay;
  FSelecting := False;
  FPageViewMap := Default(TPdfPageViewMap);
end;

destructor TPdfViewer.Destroy;
begin
  FreeAndNil(FLoadingLabel);
  FreeAndNil(FLoadingPanel);
  FreeAndNil(FCore);
  inherited;
end;

function TPdfViewer.GetCurrentPageIndex: Integer;
begin
  Result := FCore.CurrentPageIndex;
end;

procedure TPdfViewer.SetCurrentPageIndex(const AValue: Integer);
begin
  FCore.CurrentPageIndex := AValue;
end;

function TPdfViewer.GetBackgroundColor: TColor;
begin
  Result := TColor(FCore.BackgroundColor);
end;

procedure TPdfViewer.SetBackgroundColor(const AValue: TColor);
begin
  FCore.BackgroundColor := TAlphaColor(AValue) or $FF000000; // Add alpha channel
end;

function TPdfViewer.GetShowLoadingIndicator: Boolean;
begin
  Result := FCore.ShowLoadingIndicator;
end;

procedure TPdfViewer.SetShowLoadingIndicator(const AValue: Boolean);
begin
  FCore.ShowLoadingIndicator := AValue;
end;

function TPdfViewer.GetPageCount: Integer;
begin
  Result := FCore.PageCount;
end;

function TPdfViewer.GetDocument: TPdfDocument;
begin
  Result := FCore.Document;
end;

function TPdfViewer.GetOnPageChanged: TNotifyEvent;
begin
  Result := FCore.OnPageChanged;
end;

procedure TPdfViewer.SetOnPageChanged(const AValue: TNotifyEvent);
begin
  FCore.OnPageChanged := AValue;
end;

function TPdfViewer.GetSelectionEnabled: Boolean;
begin
  Result := FCore.SelectionEnabled;
end;

procedure TPdfViewer.SetSelectionEnabled(const AValue: Boolean);
begin
  FCore.SelectionEnabled := AValue;
  if not AValue then
    FSelecting := False;
end;

function TPdfViewer.GetOnSelectionChanged: TNotifyEvent;
begin
  Result := FCore.OnSelectionChanged;
end;

procedure TPdfViewer.SetOnSelectionChanged(const AValue: TNotifyEvent);
begin
  FCore.OnSelectionChanged := AValue;
end;

procedure TPdfViewer.ClearSelection;
begin
  FSelecting := False;
  FCore.ClearSelection;
end;

procedure TPdfViewer.SelectAll;
begin
  FCore.SelectAll;
end;

procedure TPdfViewer.SelectWordAt(ACharIndex: Integer);
begin
  FCore.SelectWordAt(ACharIndex);
end;

function TPdfViewer.HasSelection: Boolean;
begin
  Result := FCore.HasSelection;
end;

function TPdfViewer.GetSelectedText: string;
begin
  Result := FCore.GetSelectedText;
end;

procedure TPdfViewer.CopySelection;
var
  LText: string;
begin
  LText := GetSelectedText;
  if LText = '' then
    Exit;
  Clipboard.AsText := LText;
end;

function TPdfViewer.CharIndexAtLocalPoint(X, Y: Integer): Integer;
begin
  Result := FCore.CharIndexAtScreenPoint(FPageViewMap, X, Y);
end;

function TPdfViewer.IsPointOnPage(X, Y: Integer): Boolean;
var
  LRight, LBottom: Double;
begin
  Result := (FPageViewMap.SizeX > 0) and (FPageViewMap.SizeY > 0) and
    (FPageViewMap.ScreenScaleX <> 0) and (FPageViewMap.ScreenScaleY <> 0);
  if not Result then
    Exit;
  LRight := FPageViewMap.ScreenLeft + (FPageViewMap.SizeX * FPageViewMap.ScreenScaleX);
  LBottom := FPageViewMap.ScreenTop + (FPageViewMap.SizeY * FPageViewMap.ScreenScaleY);
  Result := (X >= FPageViewMap.ScreenLeft) and (Y >= FPageViewMap.ScreenTop) and
    (X <= LRight) and (Y <= LBottom);
end;

procedure TPdfViewer.InvalidateSelection;
begin
  if FSelectionOverlay <> nil then
    FSelectionOverlay.Invalidate;
end;

procedure TPdfViewer.UpdatePageViewMap(AImageLeft, AImageTop, AImageWidth, AImageHeight: Integer);
begin
  FPageViewMap := Default(TPdfPageViewMap);
  if (AImageWidth <= 0) or (AImageHeight <= 0) then
    Exit;

  // The VCL viewer draws the bitmap 1:1, centered in the control.
  // Render uses start (0, 0), the bitmap size, and no extra rotation.
  FPageViewMap.StartX := 0;
  FPageViewMap.StartY := 0;
  FPageViewMap.SizeX := AImageWidth;
  FPageViewMap.SizeY := AImageHeight;
  FPageViewMap.Rotate := FPDF_ROTATE_0;
  FPageViewMap.ScreenScaleX := 1;
  FPageViewMap.ScreenScaleY := 1;
  FPageViewMap.ScreenLeft := AImageLeft;
  FPageViewMap.ScreenTop := AImageTop;
end;

procedure TPdfViewer.CreateImage;
begin
  if FImage = nil then
  begin
    FImage := TImage.Create(Self);
    FImage.Parent := Self;
    FImage.Align := alNone; // Manual positioning
    FImage.Center := False;
    FImage.Proportional := False;
    FImage.Stretch := False;
    FImage.AutoSize := True; // Image sizes itself to bitmap
  end;
end;

procedure TPdfViewer.CreateLoadingIndicator;
begin
  // Create semi-transparent panel as background
  FLoadingPanel := TPanel.Create(Self);
  FLoadingPanel.Parent := Self;
  FLoadingPanel.Width := 200;
  FLoadingPanel.Height := 100;
  FLoadingPanel.Left := (Width - FLoadingPanel.Width) div 2;
  FLoadingPanel.Top := (Height - FLoadingPanel.Height) div 2;
  FLoadingPanel.Anchors := [akLeft, akTop];
  FLoadingPanel.BevelOuter := bvRaised;
  FLoadingPanel.Color := clWhite;
  FLoadingPanel.Visible := False;

  // Create loading label
  FLoadingLabel := TLabel.Create(FLoadingPanel);
  FLoadingLabel.Parent := FLoadingPanel;
  FLoadingLabel.Align := alClient;
  FLoadingLabel.Alignment := taCenter;
  FLoadingLabel.Layout := tlCenter;
  FLoadingLabel.Font.Size := 12;
  FLoadingLabel.Caption := 'Loading...';
end;

procedure TPdfViewer.CreateSelectionOverlay;
begin
  if FSelectionOverlay <> nil then
    Exit;
  // TPaintBox is a graphic control, so it paints on this control after
  // TImage (created first) and does not take mouse capture away from us.
  FSelectionOverlay := TPaintBox.Create(Self);
  FSelectionOverlay.Parent := Self;
  FSelectionOverlay.Align := alClient;
  FSelectionOverlay.OnPaint := SelectionOverlayPaint;
  FSelectionOverlay.BringToFront;
end;

procedure TPdfViewer.SelectionOverlayPaint(Sender: TObject);
var
  LRects: TArray<TRectF>;
  LRect: TRectF;
  LDest: TRect;
  LBmp: Vcl.Graphics.TBitmap;
  LBlend: TBlendFunction;
  I: Integer;
begin
  if not IsDocumentLoaded then
    Exit;
  if TPdfViewerCoreVCL(FCore).GetIsRendering then
    Exit;

  LRects := FCore.GetSelectionScreenRects(FPageViewMap);
  LBlend.BlendOp := AC_SRC_OVER;
  LBlend.BlendFlags := 0;
  LBlend.SourceConstantAlpha := 90;
  LBlend.AlphaFormat := 0;

  for I := 0 to High(LRects) do
  begin
    LRect := LRects[I];
    LDest := Rect(
      Round(LRect.Left - FSelectionOverlay.Left),
      Round(LRect.Top - FSelectionOverlay.Top),
      Round(LRect.Right - FSelectionOverlay.Left),
      Round(LRect.Bottom - FSelectionOverlay.Top));
    if ((LDest.Right - LDest.Left) <= 0) or ((LDest.Bottom - LDest.Top) <= 0) then
      Continue;

    LBmp := Vcl.Graphics.TBitmap.Create;
    try
      LBmp.PixelFormat := pf32bit;
      LBmp.SetSize(LDest.Right - LDest.Left, LDest.Bottom - LDest.Top);
      // COLORREF is 0x00BBGGRR. Dodger-blue-like RGB(51, 153, 255).
      LBmp.Canvas.Brush.Color := $00FF9933;
      LBmp.Canvas.FillRect(Rect(0, 0, LDest.Right - LDest.Left, LDest.Bottom - LDest.Top));
      Winapi.Windows.AlphaBlend(FSelectionOverlay.Canvas.Handle,
        LDest.Left, LDest.Top, LDest.Right - LDest.Left, LDest.Bottom - LDest.Top,
        LBmp.Canvas.Handle, 0, 0, LDest.Right - LDest.Left, LDest.Bottom - LDest.Top, LBlend);
    finally
      LBmp.Free;
    end;
  end;
end;

procedure TPdfViewer.LoadFromFile(const AFileName: string; const APassword: string);
begin
  FCore.LoadFromFile(AFileName, APassword);
end;

procedure TPdfViewer.LoadFromStream(AStream: TStream; AOwnsStream: Boolean; const APassword: string);
begin
  FCore.LoadFromStream(AStream, AOwnsStream, APassword);
end;

procedure TPdfViewer.Close;
begin
  FSelecting := False;
  FCore.Close;
  FPageViewMap := Default(TPdfPageViewMap);
  if FImage <> nil then
  begin
    FImage.Picture.Bitmap.SetSize(0, 0);
    Invalidate;
  end;
  InvalidateSelection;
end;

function TPdfViewer.IsDocumentLoaded: Boolean;
begin
  Result := FCore.IsDocumentLoaded;
end;

procedure TPdfViewer.NextPage;
begin
  FCore.NextPage;
end;

procedure TPdfViewer.PreviousPage;
begin
  FCore.PreviousPage;
end;

procedure TPdfViewer.FirstPage;
begin
  FCore.FirstPage;
end;

procedure TPdfViewer.LastPage;
begin
  FCore.LastPage;
end;

procedure TPdfViewer.Resize;
begin
  inherited;

  // Center loading panel
  if FLoadingPanel <> nil then
  begin
    FLoadingPanel.Left := (Width - FLoadingPanel.Width) div 2;
    FLoadingPanel.Top := (Height - FLoadingPanel.Height) div 2;
  end;

  if IsDocumentLoaded and (FCore.CurrentPageIndex >= 0) then
    TPdfViewerCoreVCL(FCore).CallRenderCurrentPage;
end;

procedure TPdfViewer.Paint;
begin
  // Always paint background to avoid artifacts
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  inherited;
end;

procedure TPdfViewer.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  // Prevent flicker
  Message.Result := 1;
end;

procedure TPdfViewer.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;

  if (ssCtrl in Shift) and (Key = Ord('C')) and HasSelection then
  begin
    CopySelection;
    Key := 0;
    Exit;
  end;
  if (ssCtrl in Shift) and (Key = Ord('A')) and SelectionEnabled then
  begin
    SelectAll;
    Key := 0;
    Exit;
  end;

  case Key of
    VK_UP, VK_LEFT:
    begin
      PreviousPage;
      Key := 0; // Mark as handled
    end;
    VK_DOWN, VK_RIGHT:
    begin
      NextPage;
      Key := 0; // Mark as handled
    end;
    VK_HOME:
    begin
      FirstPage;
      Key := 0; // Mark as handled
    end;
    VK_END:
    begin
      LastPage;
      Key := 0; // Mark as handled
    end;
    VK_PRIOR: // Page Up
    begin
      PreviousPage;
      Key := 0; // Mark as handled
    end;
    VK_NEXT: // Page Down
    begin
      NextPage;
      Key := 0; // Mark as handled
    end;
  end;
end;

procedure TPdfViewer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LIndex: Integer;
begin
  inherited;

  if (Button <> mbLeft) or not SelectionEnabled or not IsDocumentLoaded then
    Exit;
  // PDFium is not thread-safe. Skip hit testing while a page is rendering.
  if TPdfViewerCoreVCL(FCore).GetIsRendering then
    Exit;

  if CanFocus and HandleAllocated then
    SetFocus;

  // Clicks outside the rendered page keep the current selection.
  if not IsPointOnPage(X, Y) then
    Exit;

  LIndex := CharIndexAtLocalPoint(X, Y);
  if ssDouble in Shift then
  begin
    FSelecting := False;
    MouseCapture := False;
    if LIndex >= 0 then
      SelectWordAt(LIndex)
    else
      ClearSelection;
    Exit;
  end;

  if LIndex < 0 then
  begin
    FSelecting := False;
    ClearSelection;
    Exit;
  end;

  FSelecting := True;
  FCore.SetSelection(LIndex, LIndex);
  MouseCapture := True;
end;

procedure TPdfViewer.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  LIndex: Integer;
begin
  inherited;

  if not FSelecting or not (ssLeft in Shift) or not SelectionEnabled then
  begin
    if not SelectionEnabled then
      FSelecting := False;
    Exit;
  end;
  if TPdfViewerCoreVCL(FCore).GetIsRendering then
    Exit;

  LIndex := CharIndexAtLocalPoint(X, Y);
  if LIndex >= 0 then
    FCore.SetSelection(FCore.SelectionAnchor, LIndex);
end;

procedure TPdfViewer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
  begin
    FSelecting := False;
    MouseCapture := False;
  end;
end;

function TPdfViewer.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);

  if not IsDocumentLoaded then
    Exit;

  // Scroll up (positive delta) = previous page
  // Scroll down (negative delta) = next page
  if WheelDelta > 0 then
    PreviousPage
  else if WheelDelta < 0 then
    NextPage;

  Result := True;
end;

procedure TPdfViewer.DoShowLoadingIndicatorInternal(AShow: Boolean);
begin
  if FLoadingPanel <> nil then
  begin
    FLoadingPanel.Visible := AShow;
    if AShow then
    begin
      FLoadingPanel.BringToFront;
      // Hide image while loading to avoid artifacts
      if FImage <> nil then
        FImage.Visible := False;
    end;
  end;
end;

procedure TPdfViewer.RenderPageInBackground;
var
  LCoreVCL: TPdfViewerCoreVCL;
  LCurrentPage: TPdfPage;
  LPageIndex: Integer;
  LRenderWidth: Integer;
  LRenderHeight: Integer;
  LBackgroundColor: TAlphaColor;
  LAspectRatio: Double;
  LControlWidth: Integer;
  LControlHeight: Integer;
begin
  LCoreVCL := TPdfViewerCoreVCL(FCore);

  // Note: IsRendering check is already done in TPdfViewerCore.RenderCurrentPage
  // Note: Document loaded check is already done in TPdfViewerCore.RenderCurrentPage

  LPageIndex := FCore.CurrentPageIndex;
  if (LPageIndex < 0) or (LPageIndex >= FCore.PageCount) then
  begin
    LCoreVCL.SetIsRendering(False);
    DoShowLoadingIndicatorInternal(False);
    Exit;
  end;

  // Get control size
  LControlWidth := Width;
  LControlHeight := Height;

  if (LControlWidth <= 0) or (LControlHeight <= 0) then
  begin
    LCoreVCL.SetIsRendering(False);
    DoShowLoadingIndicatorInternal(False);
    Exit;
  end;

  LBackgroundColor := FCore.BackgroundColor;

  // Load page in main thread (PDFium requires this)
  LCoreVCL.SetCurrentPage(FCore.Document.GetPageByIndex(LPageIndex));
  LCurrentPage := LCoreVCL.GetCurrentPage;

  if LCurrentPage = nil then
  begin
    LCoreVCL.SetIsRendering(False);
    DoShowLoadingIndicatorInternal(False);
    Exit;
  end;

  // Calculate aspect ratio of PDF page
  LAspectRatio := LCurrentPage.Width / LCurrentPage.Height;

  // Calculate render size to fit control while maintaining aspect ratio
  if LControlWidth / LControlHeight > LAspectRatio then
  begin
    // Height is limiting factor
    LRenderHeight := LControlHeight;
    LRenderWidth := Round(LRenderHeight * LAspectRatio);
  end
  else
  begin
    // Width is limiting factor
    LRenderWidth := LControlWidth;
    LRenderHeight := Round(LRenderWidth / LAspectRatio);
  end;

  // Render in background thread
  FRenderTask := TTask.Run(
    procedure
    var
      LTempBitmap: Vcl.Graphics.TBitmap;
      LErrorMsg: string;
    begin
      LTempBitmap := nil;
      LErrorMsg := '';
      try
        // Create bitmap at calculated size (proportional to page)
        LTempBitmap := Vcl.Graphics.TBitmap.Create;
        LTempBitmap.PixelFormat := pf32bit;
        LTempBitmap.SetSize(LRenderWidth, LRenderHeight);

        // Render PDF page to bitmap (this is the slow part)
        LCurrentPage.RenderToBitmap(LTempBitmap, LBackgroundColor);

        // Switch back to main thread to update UI
        TThread.Synchronize(nil,
          procedure
          begin
            OnRenderComplete(LTempBitmap, LRenderWidth, LRenderHeight, LControlWidth, LControlHeight);
          end);
      except
        on E: Exception do
        begin
          LErrorMsg := E.Message;
          if LTempBitmap <> nil then
            LTempBitmap.Free;
          TThread.Synchronize(nil,
            procedure
            begin
              LCoreVCL.SetIsRendering(False);
              DoShowLoadingIndicatorInternal(False);
              ShowMessage('Render error: ' + LErrorMsg);
            end);
        end;
      end;
    end);
end;

procedure TPdfViewer.OnRenderComplete(ABitmap: Vcl.Graphics.TBitmap; AImageWidth, AImageHeight, AControlWidth, AControlHeight: Integer);
begin
  try
    // Assign bitmap to image (fast operation in main thread)
    FImage.Picture.Bitmap.Assign(ABitmap);

    // Center the image in the control
    // AutoSize will make the TImage the same size as the bitmap
    FImage.Left := (AControlWidth - AImageWidth) div 2;
    FImage.Top := (AControlHeight - AImageHeight) div 2;
    UpdatePageViewMap(FImage.Left, FImage.Top, AImageWidth, AImageHeight);

    // Show image (was hidden in DoShowLoadingIndicatorInternal)
    FImage.Visible := True;

    // Hide loading indicator and show rendered page
    DoShowLoadingIndicatorInternal(False);

    // Repaint to clear any artifacts
    Invalidate;
  finally
    ABitmap.Free;
    TPdfViewerCoreVCL(FCore).SetIsRendering(False);
    InvalidateSelection;
  end;
end;

end.

