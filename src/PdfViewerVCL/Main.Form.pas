{*******************************************************************************
  Unit: Main.Form

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Main application form for DX PDF Viewer (VCL).
    Provides a minimalistic interface for viewing PDF documents.
    Demonstrates the usage of DX Pdfium4D wrapper classes with VCL.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit Main.Form;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  DX.Pdf.Viewer.VCL,
  DX.Pdf.Document;

type
  TMainForm = class(TForm)
    StatusBar: TStatusBar;
    DropPanel: TPanel;
    DropLabel: TLabel;
    OpenDialog: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DropPanelClick(Sender: TObject);
  private
    FPdfViewer: TPdfViewer;
    FCurrentPdfPath: string;
    procedure HideDropPanel;
    procedure ShowDropPanel;
    procedure CreatePdfViewer;
    procedure UpdateStatusBar;
    procedure OnPdfViewerPageChanged(Sender: TObject);
    procedure ShowOpenDialog;
  protected
    procedure LoadPdfFile(const AFilePath: string);
    procedure ProcessCommandLineParams;
  public
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.IOUtils,
  Winapi.ShellAPI;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := 'DX PDF Viewer 1.1 (VCL)';
  FCurrentPdfPath := '';

  // Enable drag and drop
  DragAcceptFiles(Handle, True);

  // Create PDF viewer dynamically
  CreatePdfViewer;

  // Initialize status bar
  UpdateStatusBar;

  // Show drop panel initially
  ShowDropPanel;

  // Process command line parameters
  ProcessCommandLineParams;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  DragAcceptFiles(Handle, False);
  FreeAndNil(FPdfViewer);
end;

procedure TMainForm.CreatePdfViewer;
begin
  FPdfViewer := TPdfViewer.Create(Self);
  FPdfViewer.Parent := Self;
  FPdfViewer.Align := alClient;
  FPdfViewer.BackgroundColor := clWhite;
  FPdfViewer.OnPageChanged := OnPdfViewerPageChanged;
  FPdfViewer.SendToBack; // Send behind DropPanel
end;

procedure TMainForm.HideDropPanel;
begin
  DropPanel.Visible := False;
end;

procedure TMainForm.ShowDropPanel;
begin
  DropPanel.Visible := True;
  DropPanel.BringToFront;
end;

procedure TMainForm.ProcessCommandLineParams;
var
  LFilePath: string;
begin
  // Check if a parameter was passed
  if ParamCount > 0 then
  begin
    LFilePath := ParamStr(1);

    // Check if the file exists and is a PDF
    if TFile.Exists(LFilePath) and
      (TPath.GetExtension(LFilePath).ToLower = '.pdf') then
    begin
      LoadPdfFile(LFilePath);
    end;
  end;
end;

procedure TMainForm.LoadPdfFile(const AFilePath: string);
begin
  if not TFile.Exists(AFilePath) then
  begin
    ShowMessage('File not found: ' + AFilePath);
    Exit;
  end;

  try
    // Load PDF in viewer
    FPdfViewer.LoadFromFile(AFilePath);

    FCurrentPdfPath := AFilePath;

    // Hide drop panel when PDF is loaded
    HideDropPanel;

    // Update window title and status bar
    Caption := 'DX PDF Viewer 1.1 (VCL) - ' + TPath.GetFileName(AFilePath);
    UpdateStatusBar;

    // Set focus to viewer for keyboard navigation
    FPdfViewer.SetFocus;
  except
    on E: EPdfException do
    begin
      ShowMessage('Error loading PDF: ' + E.Message);
      ShowDropPanel;
      UpdateStatusBar;
    end;
  end;
end;

procedure TMainForm.UpdateStatusBar;
var
  LFileName: string;
  LPdfVersion: string;
  LPdfAInfo: string;
  LStatusText: string;
begin
  if (FCurrentPdfPath = '') or (FPdfViewer.Document = nil) or not FPdfViewer.Document.IsLoaded then
  begin
    StatusBar.SimpleText := 'No document loaded';
    Exit;
  end;

  // Get file name
  LFileName := TPath.GetFileName(FCurrentPdfPath);

  // Get PDF version
  LPdfVersion := FPdfViewer.Document.GetFileVersionString;

  // Get PDF/A information
  LPdfAInfo := FPdfViewer.Document.GetPdfAInfo;

  // Build status text
  LStatusText := Format('File: %s  |  PDF Version: %s', [LFileName, LPdfVersion]);

  // Add PDF/A info if available
  if LPdfAInfo <> '' then
    LStatusText := LStatusText + '  |  ' + LPdfAInfo;

  // Add page info
  LStatusText := LStatusText + Format('  |  Page %d/%d', [FPdfViewer.CurrentPageIndex + 1, FPdfViewer.PageCount]);

  StatusBar.SimpleText := LStatusText;
end;

procedure TMainForm.OnPdfViewerPageChanged(Sender: TObject);
begin
  UpdateStatusBar;
end;

procedure TMainForm.WMDropFiles(var Msg: TWMDropFiles);
var
  LFileName: array[0..MAX_PATH] of Char;
  LFilePath: string;
begin
  try
    if DragQueryFile(Msg.Drop, 0, LFileName, MAX_PATH) > 0 then
    begin
      LFilePath := LFileName;

      // Check if it's a PDF file
      if TPath.GetExtension(LFilePath).ToLower = '.pdf' then
        LoadPdfFile(LFilePath)
      else
        ShowMessage('Please drop PDF files only.');
    end;
  finally
    DragFinish(Msg.Drop);
  end;
end;

procedure TMainForm.DropPanelClick(Sender: TObject);
begin
  ShowOpenDialog;
end;

procedure TMainForm.ShowOpenDialog;
begin
  OpenDialog.Title := 'Open PDF File';
  OpenDialog.Filter := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
  OpenDialog.DefaultExt := 'pdf';
  OpenDialog.Options := [ofFileMustExist, ofEnableSizing];

  if OpenDialog.Execute then
  begin
    if TPath.GetExtension(OpenDialog.FileName).ToLower = '.pdf' then
      LoadPdfFile(OpenDialog.FileName)
    else
      ShowMessage('Please select a PDF file.');
  end;
end;

end.

