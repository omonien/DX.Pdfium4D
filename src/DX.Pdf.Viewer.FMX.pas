{*******************************************************************************
  Unit: DX.Pdf.Viewer.FMX

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    FMX PDF Viewer Component.
    Provides a visual component for displaying PDF documents in FMX applications.
    Supports navigation, zooming, and drag-and-drop.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Viewer.FMX;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Threading,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Forms,
  FMX.Layouts,
  DX.Pdf.API,
  DX.Pdf.Document,
  DX.Pdf.Renderer.FMX,  // FMX-specific renderer
  DX.Pdf.Viewer.Core;

type
  /// <summary>
  /// FMX component for displaying PDF documents
  /// </summary>
  TPdfViewer = class(TControl)
  private
    FCore: TPdfViewerCore;
    FImage: TImage;
    FLoadingPanel: TPanel;
    FLoadingLabel: TLabel;
    FLoadingArc: TArc;
    FRenderTask: ITask;
    FHLRect: TRectF;
    function GetCurrentPageIndex: Integer;
    procedure SetCurrentPageIndex(const AValue: Integer);
    function GetBackgroundColor: TAlphaColor;
    procedure SetBackgroundColor(const AValue: TAlphaColor);
    function GetShowLoadingIndicator: Boolean;
    procedure SetShowLoadingIndicator(const AValue: Boolean);
    function GetPageCount: Integer;
    function GetDocument: TPdfDocument;
    function GetOnPageChanged: TNotifyEvent;
    procedure SetOnPageChanged(const AValue: TNotifyEvent);
    procedure RenderPageInBackground;
    procedure OnRenderComplete(ABitmap: FMX.Graphics.TBitmap);
    procedure CreateImage;
    procedure CreateLoadingIndicator;
    procedure DoShowLoadingIndicatorInternal(AShow: Boolean);
    function GetCurrentPage: TPdfPage;
  protected
    procedure Resize; override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
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
    ///  Get current page
    /// </summary>
    property CurrentPage: TPdfPage read GetCurrentPage;
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
    property BackgroundColor: TAlphaColor read GetBackgroundColor write SetBackgroundColor default TAlphaColors.White;

    /// <summary>
    /// Show loading indicator overlay while rendering pages
    /// </summary>
    property ShowLoadingIndicator: Boolean read GetShowLoadingIndicator write SetShowLoadingIndicator default True;

    /// <summary>
    /// Event fired when the current page changes
    /// </summary>
    property OnPageChanged: TNotifyEvent read GetOnPageChanged write SetOnPageChanged;

    procedure HighlightRect(ARect: TRectF);
    procedure Rerender;

    // Inherited published properties
    property Align;
    property Anchors;
    property ClipChildren default False;
    property ClipParent default False;
    property Cursor default crDefault;
    property DragMode default TDragMode.dmManual;
    property EnableDragHighlight default True;
    property Enabled default True;
    property Locked default False;
    property Height;
    property HitTest default True;
    property Padding;
    property Opacity;
    property Margins;
    property PopupMenu;
    property Position;
    property RotationAngle;
    property RotationCenter;
    property Scale;
    property Size;
    property TabOrder;
    property TabStop;
    property Visible default True;
    property Width;

    // Events
    property OnDragEnter;
    property OnDragLeave;
    property OnDragOver;
    property OnDragDrop;
    property OnDragEnd;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnPainting;
    property OnPaint;
    property OnResize;
  end;

implementation

uses
  System.Math,
  FMX.Platform;

type
  /// <summary>
  /// FMX-specific implementation of TPdfViewerCore
  /// </summary>
  TPdfViewerCoreFMX = class(TPdfViewerCore)
  private
    FViewer: TPdfViewer;
  protected
    procedure DoRenderCurrentPage; override;
    procedure DoShowLoadingIndicator(AShow: Boolean); override;
  public
    constructor Create(AViewer: TPdfViewer); reintroduce;

    // Public accessors for protected members (for TPdfViewer)
    function GetCurrentPage: TPdfPage;
    procedure SetCurrentPage(const AValue: TPdfPage);
    function GetIsRendering: Boolean;
    procedure SetIsRendering(const AValue: Boolean);
    procedure CallRenderCurrentPage;
  end;

function ConvertPDFToRenderedRect(const CanvasRect: TRectF;
                                 PageWidth, PageHeight: Double;
                                 const RenderedBounds: TRectF;
                                 CanvasDPI: Integer = 96): TRectF;
var
  ScaleX, ScaleY: Single;
  ExpectedWidth, ExpectedHeight: Single;
  RenderedWidth, RenderedHeight: Single;
begin
  ExpectedWidth := PageWidth * CanvasDPI / 72.0;
  ExpectedHeight := PageHeight * CanvasDPI / 72.0;

  RenderedWidth := RenderedBounds.Width;
  RenderedHeight := RenderedBounds.Height;

  ScaleX := RenderedWidth / ExpectedWidth;
  ScaleY := RenderedHeight / ExpectedHeight;

  Result.Left := CanvasRect.Left * ScaleX + RenderedBounds.Left;
  Result.Top := CanvasRect.Top * ScaleY + RenderedBounds.Top;
  Result.Right := CanvasRect.Right * ScaleX + RenderedBounds.Left;
  Result.Bottom := CanvasRect.Bottom * ScaleY + RenderedBounds.Top;
end;

{ TPdfViewerCoreFMX }

constructor TPdfViewerCoreFMX.Create(AViewer: TPdfViewer);
begin
  inherited Create(AViewer);
  FViewer := AViewer;
end;

procedure TPdfViewerCoreFMX.DoRenderCurrentPage;
begin
  FViewer.RenderPageInBackground;
end;

procedure TPdfViewerCoreFMX.DoShowLoadingIndicator(AShow: Boolean);
begin
  FViewer.DoShowLoadingIndicatorInternal(AShow);
end;

function TPdfViewerCoreFMX.GetCurrentPage: TPdfPage;
begin
  Result := CurrentPage;
end;

procedure TPdfViewerCoreFMX.SetCurrentPage(const AValue: TPdfPage);
begin
  CurrentPage := AValue;
end;

function TPdfViewerCoreFMX.GetIsRendering: Boolean;
begin
  Result := IsRendering;
end;

procedure TPdfViewerCoreFMX.SetIsRendering(const AValue: Boolean);
begin
  IsRendering := AValue;
end;

procedure TPdfViewerCoreFMX.CallRenderCurrentPage;
begin
  RenderCurrentPage;
end;

{ TPdfViewer }

constructor TPdfViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCore := TPdfViewerCoreFMX.Create(Self);

  // Enable keyboard and mouse input
  CanFocus := True;
  TabStop := True;

  CreateImage;
  CreateLoadingIndicator;
end;

destructor TPdfViewer.Destroy;
begin
  FreeAndNil(FLoadingArc);
  FreeAndNil(FLoadingLabel);
  FreeAndNil(FLoadingPanel);
  FreeAndNil(FCore);
  inherited;
end;

function TPdfViewer.GetCurrentPage: TPdfPage;
begin
  Result := FCore.CurrentPage;
end;

function TPdfViewer.GetCurrentPageIndex: Integer;
begin
  Result := FCore.CurrentPageIndex;
end;

procedure TPdfViewer.SetCurrentPageIndex(const AValue: Integer);
begin
  FCore.CurrentPageIndex := AValue;
end;

function TPdfViewer.GetBackgroundColor: TAlphaColor;
begin
  Result := FCore.BackgroundColor;
end;

procedure TPdfViewer.SetBackgroundColor(const AValue: TAlphaColor);
begin
  FCore.BackgroundColor := AValue;
end;

function TPdfViewer.GetShowLoadingIndicator: Boolean;
begin
  Result := FCore.ShowLoadingIndicator;
end;

procedure TPdfViewer.HighlightRect(ARect: TRectF);
begin
  FHLRect := ARect;
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

procedure TPdfViewer.CreateImage;
begin
  if FImage = nil then
  begin
    FImage := TImage.Create(Self);
    FImage.Parent := Self;
    FImage.Align := TAlignLayout.Client;
    FImage.HitTest := False;
    // Use Center mode to display bitmap at exact size without scaling
    FImage.WrapMode := TImageWrapMode.Center;
  end;
end;

procedure TPdfViewer.CreateLoadingIndicator;
begin
  // Create semi-transparent panel as background
  FLoadingPanel := TPanel.Create(Self);
  FLoadingPanel.Parent := Self;
  FLoadingPanel.Align := TAlignLayout.Center;
  FLoadingPanel.Width := 200;
  FLoadingPanel.Height := 100;
  FLoadingPanel.Opacity := 0.9;
  FLoadingPanel.Visible := False;
  FLoadingPanel.HitTest := False;

  // Create animated arc (spinner)
  FLoadingArc := TArc.Create(FLoadingPanel);
  FLoadingArc.Parent := FLoadingPanel;
  FLoadingArc.Align := TAlignLayout.Top;
  FLoadingArc.Height := 50;
  FLoadingArc.Margins.Top := 10;
  FLoadingArc.Margins.Left := 75;
  FLoadingArc.Margins.Right := 75;
  FLoadingArc.StartAngle := 0;
  FLoadingArc.EndAngle := 270;
  FLoadingArc.Stroke.Color := TAlphaColors.Dodgerblue;
  FLoadingArc.Stroke.Thickness := 3;
  FLoadingArc.Fill.Kind := TBrushKind.None;
  FLoadingArc.HitTest := False;

  // Create loading label
  FLoadingLabel := TLabel.Create(FLoadingPanel);
  FLoadingLabel.Parent := FLoadingPanel;
  FLoadingLabel.Align := TAlignLayout.Client;
  FLoadingLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FLoadingLabel.TextSettings.VertAlign := TTextAlign.Center;
  FLoadingLabel.TextSettings.Font.Size := 14;
  FLoadingLabel.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  FLoadingLabel.TextSettings.FontColor := TAlphaColors.Black;
  FLoadingLabel.Text := 'Loading...';
  FLoadingLabel.HitTest := False;
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
  FCore.Close;
  if FImage <> nil then
    FImage.Bitmap.Clear(FCore.BackgroundColor);
  Repaint;
end;

function TPdfViewer.IsDocumentLoaded: Boolean;
begin
  Result := FCore.IsDocumentLoaded;
end;

procedure TPdfViewer.RenderPageInBackground;
var
  LRenderWidth: Integer;
  LRenderHeight: Integer;
  LAspectRatio: Double;
  LControlWidth: Integer;
  LControlHeight: Integer;
  LScreenService: IFMXScreenService;
  LScale: Single;
  LPageIndex: Integer;
  LBackgroundColor: TAlphaColor;
  LCurrentPage: TPdfPage;
  LCoreFMX: TPdfViewerCoreFMX;
begin
  LCoreFMX := TPdfViewerCoreFMX(FCore);

  // Capture values in main thread
  LPageIndex := FCore.CurrentPageIndex;
  LBackgroundColor := FCore.BackgroundColor;

  // Get screen scale factor for high-DPI displays
  LScale := 1.0;
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, LScreenService) then
    LScale := LScreenService.GetScreenScale;

  // Get control size in pixels
  LControlWidth := Trunc(Width);
  LControlHeight := Trunc(Height);

  if (LControlWidth <= 0) or (LControlHeight <= 0) then
  begin
    LCoreFMX.SetIsRendering(False);
    Exit;
  end;

  // Load page in main thread (PDFium is not thread-safe for loading)
  LCoreFMX.SetCurrentPage(FCore.Document.GetPageByIndex(LPageIndex));
  LCurrentPage := LCoreFMX.GetCurrentPage;

  if LCurrentPage = nil then
  begin
    LCoreFMX.SetIsRendering(False);
    DoShowLoadingIndicatorInternal(False);
    Exit;
  end;

  // Calculate aspect ratio of PDF page
  LAspectRatio := LCurrentPage.Width / LCurrentPage.Height;

  // Calculate render size to fit control while maintaining aspect ratio
  if LControlWidth / LControlHeight > LAspectRatio then
  begin
    // Height is limiting factor
    LRenderHeight := Round(LControlHeight * LScale);
    LRenderWidth := Round(LRenderHeight * LAspectRatio);
  end
  else
  begin
    // Width is limiting factor
    LRenderWidth := Round(LControlWidth * LScale);
    LRenderHeight := Round(LRenderWidth / LAspectRatio);
  end;

  // Render in background thread
  FRenderTask := TTask.Run(
    procedure
    var
      LTempBitmap: FMX.Graphics.TBitmap;
    begin
      LTempBitmap := FMX.Graphics.TBitmap.Create;
      try
        LTempBitmap.SetSize(LRenderWidth, LRenderHeight);
        LTempBitmap.BitmapScale := LScale;

        // Render at exact size (this is the slow part)
        LCurrentPage.RenderToBitmap(LTempBitmap, LBackgroundColor);

        // Switch back to main thread to update UI
        TThread.Queue(TThread.Current,
          procedure
          begin
            OnRenderComplete(LTempBitmap);
          end);
      except
        LTempBitmap.Free;
        TThread.Queue(TThread.Current,
          procedure
          begin
            LCoreFMX.SetIsRendering(False);
            DoShowLoadingIndicatorInternal(False);
          end);
      end;
    end);
end;

procedure TPdfViewer.Rerender;
begin
  RenderPageInBackground;
end;

procedure TPdfViewer.OnRenderComplete(ABitmap: FMX.Graphics.TBitmap);
begin
  try
    // test show selection
    if FHLRect <> TRectF.Empty then
    begin
      ABitmap.Canvas.BeginScene;
      try
        var Page := GetDocument.GetPageByIndex(CurrentPageIndex);
        var R := ConvertPDFToRenderedRect(FHLRect, Page.Width, Page.Height, TRectF.Create(0, 0, ABitmap.Width, ABitmap.Height));
        ABitmap.Canvas.Fill.Kind := TBrushKind.Solid;
        ABitmap.Canvas.Fill.Color := TAlphaColorRec.Red;
        ABitmap.Canvas.FillRect(R, 0.5);
      finally
        ABitmap.Canvas.EndScene;
      end;
    end;
    // Swap bitmaps (fast operation in main thread)
    FImage.Bitmap.Assign(ABitmap);

    // Hide loading indicator and show rendered page
    DoShowLoadingIndicatorInternal(False);
    Repaint;
  finally
    ABitmap.Free;
    TPdfViewerCoreFMX(FCore).SetIsRendering(False);
  end;
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
  if IsDocumentLoaded and (FCore.CurrentPageIndex >= 0) then
    TPdfViewerCoreFMX(FCore).CallRenderCurrentPage;
end;

procedure TPdfViewer.Paint;
begin
  inherited;
  if not IsDocumentLoaded then
  begin
    Canvas.Fill.Color := FCore.BackgroundColor;
    Canvas.FillRect(LocalRect, 0, 0, [], 1.0);
  end;
end;

procedure TPdfViewer.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  inherited;

  case Key of
    vkUp, vkLeft:
    begin
      PreviousPage;
      Key := 0; // Mark as handled
    end;
    vkDown, vkRight:
    begin
      NextPage;
      Key := 0; // Mark as handled
    end;
    vkHome:
    begin
      FirstPage;
      Key := 0; // Mark as handled
    end;
    vkEnd:
    begin
      LastPage;
      Key := 0; // Mark as handled
    end;
    vkPrior: // Page Up
    begin
      PreviousPage;
      Key := 0; // Mark as handled
    end;
    vkNext: // Page Down
    begin
      NextPage;
      Key := 0; // Mark as handled
    end;
  end;
end;

procedure TPdfViewer.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;

  if not IsDocumentLoaded then
    Exit;

  // Scroll up (positive delta) = previous page
  // Scroll down (negative delta) = next page
  if WheelDelta > 0 then
    PreviousPage
  else if WheelDelta < 0 then
    NextPage;

  Handled := True;
end;

procedure TPdfViewer.DoShowLoadingIndicatorInternal(AShow: Boolean);
begin
  if FLoadingPanel <> nil then
  begin
    if AShow and FCore.ShowLoadingIndicator then
    begin
      FLoadingPanel.Visible := True;
      FLoadingPanel.BringToFront;
      Application.ProcessMessages; // Force UI update
    end
    else
    begin
      FLoadingPanel.Visible := False;
    end;
  end;
end;

end.

