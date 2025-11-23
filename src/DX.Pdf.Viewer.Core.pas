{*******************************************************************************
  Unit: DX.Pdf.Viewer.Core

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Abstract base class for PDF Viewer components.
    Provides framework-independent core functionality for FMX and VCL viewers.
    Handles document management, page navigation, and rendering coordination.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Viewer.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DX.Pdf.Document;

type
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
    procedure SetCurrentPageIndex(const AValue: Integer);
    procedure SetBackgroundColor(const AValue: TAlphaColor);
    procedure SetShowLoadingIndicator(const AValue: Boolean);
    function GetPageCount: Integer;
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
  end;

implementation

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

end.

