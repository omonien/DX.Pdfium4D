{*******************************************************************************
  Unit: DX.Pdf.Viewer.VCL

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    VCL PDF Viewer Component.
    Provides a visual component for displaying PDF documents in VCL applications.
    Supports navigation, zooming, and drag-and-drop.

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
    FRenderTask: ITask;
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
    procedure RenderPageInBackground;
    procedure OnRenderComplete(ABitmap: Vcl.Graphics.TBitmap; AImageWidth, AImageHeight, AControlWidth, AControlHeight: Integer);
    procedure CreateImage;
    procedure CreateLoadingIndicator;
    procedure DoShowLoadingIndicatorInternal(AShow: Boolean);
  protected
    procedure Resize; override;
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
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
  begin
    FImage.Picture.Bitmap.SetSize(0, 0);
    Invalidate;
  end;
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

    // Show image (was hidden in DoShowLoadingIndicatorInternal)
    FImage.Visible := True;

    // Hide loading indicator and show rendered page
    DoShowLoadingIndicatorInternal(False);

    // Repaint to clear any artifacts
    Invalidate;
  finally
    ABitmap.Free;
    TPdfViewerCoreVCL(FCore).SetIsRendering(False);
  end;
end;

end.

