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
  DX.Pdf.Document;

type
  /// <summary>
  /// FMX component for displaying PDF documents
  /// </summary>
  TPdfViewer = class(TControl)
  private
    FDocument: TPdfDocument;
    FCurrentPage: TPdfPage;
    FCurrentPageIndex: Integer;
    FImage: TImage;
    FLoadingPanel: TPanel;
    FLoadingLabel: TLabel;
    FLoadingArc: TArc;
    FBackgroundColor: TAlphaColor;
    FShowLoadingIndicator: Boolean;
    FOnPageChanged: TNotifyEvent;
    FIsRendering: Boolean;
    FRenderTask: ITask;
    procedure SetCurrentPageIndex(const AValue: Integer);
    procedure SetBackgroundColor(const AValue: TAlphaColor);
    procedure SetShowLoadingIndicator(const AValue: Boolean);
    function GetPageCount: Integer;
    procedure RenderCurrentPage;
    procedure RenderPageInBackground;
    procedure OnRenderComplete(ABitmap: TBitmap);
    procedure CreateImage;
    procedure CreateLoadingIndicator;
    procedure DoShowLoadingIndicator;
    procedure DoHideLoadingIndicator;
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
    /// <param name="AOwnsStream">If true, the viewer takes ownership and will free the stream on Close</param>
    /// <param name="APassword">Optional password for encrypted PDFs</param>
    procedure LoadFromStreamEx(AStream: TStream; AOwnsStream: Boolean = False; const APassword: string = '');

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
  published
    /// <summary>
    /// Background color for the viewer
    /// </summary>
    property BackgroundColor: TAlphaColor read FBackgroundColor write SetBackgroundColor default TAlphaColors.White;

    /// <summary>
    /// Show loading indicator overlay while rendering pages
    /// </summary>
    property ShowLoadingIndicator: Boolean read FShowLoadingIndicator write SetShowLoadingIndicator default True;

    /// <summary>
    /// Event fired when the current page changes
    /// </summary>
    property OnPageChanged: TNotifyEvent read FOnPageChanged write FOnPageChanged;

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

{ TPdfViewer }

constructor TPdfViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDocument := TPdfDocument.Create;
  FCurrentPage := nil;
  FCurrentPageIndex := -1;
  FBackgroundColor := TAlphaColors.White;
  FShowLoadingIndicator := True; // Default: enabled
  FIsRendering := False;

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
  Close;
  FreeAndNil(FDocument);
  inherited;
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

procedure TPdfViewer.LoadFromFile(const AFileName: string; const APassword: string = '');
begin
  Close;
  FDocument.LoadFromFile(AFileName, APassword);
  if FDocument.PageCount > 0 then
    SetCurrentPageIndex(0)
  else
    FCurrentPageIndex := -1;
end;

procedure TPdfViewer.LoadFromStream(AStream: TStream; const APassword: string = '');
begin
  Close;
  FDocument.LoadFromStream(AStream, APassword);
  if FDocument.PageCount > 0 then
    SetCurrentPageIndex(0)
  else
    FCurrentPageIndex := -1;
end;

procedure TPdfViewer.LoadFromStreamEx(AStream: TStream; AOwnsStream: Boolean; const APassword: string);
begin
  Close;
  FDocument.LoadFromStreamEx(AStream, AOwnsStream, APassword);
  if FDocument.PageCount > 0 then
    SetCurrentPageIndex(0)
  else
    FCurrentPageIndex := -1;
end;

procedure TPdfViewer.Close;
begin
  FreeAndNil(FCurrentPage);
  FCurrentPageIndex := -1;
  FDocument.Close;
  if FImage <> nil then
    FImage.Bitmap.Clear(FBackgroundColor);
  Repaint;
end;

function TPdfViewer.IsDocumentLoaded: Boolean;
begin
  Result := FDocument.IsLoaded;
end;

function TPdfViewer.GetPageCount: Integer;
begin
  if IsDocumentLoaded then
    Result := FDocument.PageCount
  else
    Result := 0;
end;

procedure TPdfViewer.SetCurrentPageIndex(const AValue: Integer);
begin
  if not IsDocumentLoaded then
    Exit;

  if (AValue < 0) or (AValue >= FDocument.PageCount) then
    Exit;

  if FCurrentPageIndex <> AValue then
  begin
    FCurrentPageIndex := AValue;
    RenderCurrentPage;
    if Assigned(FOnPageChanged) then
      FOnPageChanged(Self);
  end;
end;

procedure TPdfViewer.SetBackgroundColor(const AValue: TAlphaColor);
begin
  if FBackgroundColor <> AValue then
  begin
    FBackgroundColor := AValue;
    if IsDocumentLoaded then
      RenderCurrentPage
    else
      Repaint;
  end;
end;

procedure TPdfViewer.SetShowLoadingIndicator(const AValue: Boolean);
begin
  if FShowLoadingIndicator <> AValue then
  begin
    FShowLoadingIndicator := AValue;

    // If disabling while currently showing, hide it
    if not AValue and (FLoadingPanel <> nil) and FLoadingPanel.Visible then
      DoHideLoadingIndicator;
  end;
end;

procedure TPdfViewer.RenderCurrentPage;
begin
  if not IsDocumentLoaded then
    Exit;

  if (FCurrentPageIndex < 0) or (FCurrentPageIndex >= FDocument.PageCount) then
    Exit;

  if FIsRendering then
    Exit;

  FIsRendering := True;

  // Show loading indicator immediately
  DoShowLoadingIndicator;

  // Start background rendering
  RenderPageInBackground;
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
begin
  // Capture values in main thread
  LPageIndex := FCurrentPageIndex;
  LBackgroundColor := FBackgroundColor;

  // Get screen scale factor for high-DPI displays
  LScale := 1.0;
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, LScreenService) then
    LScale := LScreenService.GetScreenScale;

  // Get control size in pixels
  LControlWidth := Trunc(Width);
  LControlHeight := Trunc(Height);

  if (LControlWidth <= 0) or (LControlHeight <= 0) then
  begin
    FIsRendering := False;
    Exit;
  end;

  // Load page in main thread (PDFium is not thread-safe for loading)
  FreeAndNil(FCurrentPage);
  FCurrentPage := FDocument.GetPageByIndex(LPageIndex);

  if FCurrentPage = nil then
  begin
    FIsRendering := False;
    DoHideLoadingIndicator;
    Exit;
  end;

  // Calculate aspect ratio of PDF page
  LAspectRatio := FCurrentPage.Width / FCurrentPage.Height;

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
      LTempBitmap: TBitmap;
    begin
      LTempBitmap := TBitmap.Create;
      try
        LTempBitmap.SetSize(LRenderWidth, LRenderHeight);
        LTempBitmap.BitmapScale := LScale;

        // Render at exact size (this is the slow part)
        FCurrentPage.RenderToBitmap(LTempBitmap, LBackgroundColor);

        // Switch back to main thread to update UI
        TThread.Synchronize(nil,
          procedure
          begin
            OnRenderComplete(LTempBitmap);
          end);
      except
        LTempBitmap.Free;
        TThread.Synchronize(nil,
          procedure
          begin
            FIsRendering := False;
            DoHideLoadingIndicator;
          end);
      end;
    end);
end;

procedure TPdfViewer.OnRenderComplete(ABitmap: TBitmap);
begin
  try
    // Swap bitmaps (fast operation in main thread)
    FImage.Bitmap.Assign(ABitmap);

    // Hide loading indicator and show rendered page
    DoHideLoadingIndicator;
    Repaint;
  finally
    ABitmap.Free;
    FIsRendering := False;
  end;
end;

procedure TPdfViewer.NextPage;
begin
  if IsDocumentLoaded and (FCurrentPageIndex < FDocument.PageCount - 1) then
    SetCurrentPageIndex(FCurrentPageIndex + 1);
end;

procedure TPdfViewer.PreviousPage;
begin
  if IsDocumentLoaded and (FCurrentPageIndex > 0) then
    SetCurrentPageIndex(FCurrentPageIndex - 1);
end;

procedure TPdfViewer.FirstPage;
begin
  if IsDocumentLoaded then
    SetCurrentPageIndex(0);
end;

procedure TPdfViewer.LastPage;
begin
  if IsDocumentLoaded and (FDocument.PageCount > 0) then
    SetCurrentPageIndex(FDocument.PageCount - 1);
end;

procedure TPdfViewer.Resize;
begin
  inherited;
  if IsDocumentLoaded and (FCurrentPageIndex >= 0) then
    RenderCurrentPage;
end;

procedure TPdfViewer.Paint;
begin
  inherited;
  if not IsDocumentLoaded then
  begin
    Canvas.Fill.Color := FBackgroundColor;
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

procedure TPdfViewer.DoShowLoadingIndicator;
begin
  // Only show if enabled
  if FShowLoadingIndicator and (FLoadingPanel <> nil) then
  begin
    FLoadingPanel.Visible := True;
    FLoadingPanel.BringToFront;
    Application.ProcessMessages; // Force UI update
  end;
end;

procedure TPdfViewer.DoHideLoadingIndicator;
begin
  if FLoadingPanel <> nil then
  begin
    FLoadingPanel.Visible := False;
  end;
end;

end.

