{*******************************************************************************
  Unit: Main.Form

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Main application form for DX PDF Viewer.
    Provides a minimalistic interface for viewing PDF documents.
    Demonstrates the usage of DX Pdfium4D wrapper classes.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit Main.Form;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Menus,
  FMX.Objects,
  FMX.Controls.Presentation,
  System.IOUtils, //Name clash with TPath in FMX.Objects!!
  DX.Pdf.Viewer.FMX,
  DX.Pdf.Document;

type
  TMainForm = class(TForm)
    DropPanel: TPanel;
    StatusBar: TStatusBar;
    StatusLabel: TLabel;
    PageLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DropPanelClick(Sender: TObject);
    procedure StatusLabelClick(Sender: TObject);
    procedure MenuItemOpenFileClick(Sender: TObject);
  private
    FPdfViewer: TPdfViewer;
    FCurrentPdfPath: string;
    FOpenDialogActive: Boolean;
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
    procedure DragOver(const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation); override;
    procedure DragDrop(const Data: TDragObject; const Point: TPointF); override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := 'DX PDF Viewer 1.0';
  FCurrentPdfPath := '';

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
  FreeAndNil(FPdfViewer);
end;

procedure TMainForm.CreatePdfViewer;
begin
  FPdfViewer := TPdfViewer.Create(Self);
  FPdfViewer.Parent := Self;
  FPdfViewer.Align := TAlignLayout.Client;
  FPdfViewer.BackgroundColor := TAlphaColors.White;
  FPdfViewer.OnPageChanged := OnPdfViewerPageChanged;
  FPdfViewer.SendToBack; // Send behind DropPanel
end;

procedure TMainForm.HideDropPanel;
begin
  DropPanel.Visible := False;
  DropPanel.HitTest := False;
end;

procedure TMainForm.ShowDropPanel;
begin
  DropPanel.Visible := True;
  DropPanel.HitTest := True; // Enable click events
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
    Caption := 'DX PDF-Viewer 1.0 - ' + TPath.GetFileName(AFilePath);
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
    StatusLabel.Text := 'No document loaded';
    PageLabel.Text := '';
    Exit;
  end;

  // Get file name
  LFileName := TPath.GetFileName(FCurrentPdfPath);

  // Get PDF version
  LPdfVersion := FPdfViewer.Document.GetFileVersionString;

  // Get PDF/A information
  LPdfAInfo := FPdfViewer.Document.GetPdfAInfo;

  // Build status text (left side)
  LStatusText := Format('File: %s  |  PDF Version: %s', [LFileName, LPdfVersion]);

  // Add PDF/A info if available
  if LPdfAInfo <> '' then
    LStatusText := LStatusText + '  |  ' + LPdfAInfo;

  StatusLabel.Text := LStatusText;

  // Page info on the right side
  PageLabel.Text := Format('Page %d/%d', [FPdfViewer.CurrentPageIndex + 1, FPdfViewer.PageCount]);
end;

procedure TMainForm.OnPdfViewerPageChanged(Sender: TObject);
begin
  UpdateStatusBar;
end;

procedure TMainForm.DragOver(const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
begin
  // Check if we have files and if it's a PDF file
  if (Length(Data.Files) > 0) and
    (TPath.GetExtension(Data.Files[0]).ToLower = '.pdf') then
  begin
    Operation := TDragOperation.Copy;
  end
  else
  begin
    Operation := TDragOperation.None;
  end;
end;

procedure TMainForm.DragDrop(const Data: TDragObject; const Point: TPointF);
begin
  // Check if we have files
  if Length(Data.Files) > 0 then
  begin
    // Check if it's a PDF file
    if TPath.GetExtension(Data.Files[0]).ToLower = '.pdf' then
    begin
      LoadPdfFile(Data.Files[0]);
    end
    else
    begin
      ShowMessage('Please drop PDF files only.');
    end;
  end;
end;

procedure TMainForm.DropPanelClick(Sender: TObject);
begin
  // Prevent multiple dialogs from opening
  if not FOpenDialogActive then
    ShowOpenDialog;
end;

procedure TMainForm.ShowOpenDialog;
var
  LOpenDialog: TOpenDialog;
begin
  // Prevent multiple dialogs from opening simultaneously
  if FOpenDialogActive then
    Exit;

  FOpenDialogActive := True;
  try
    LOpenDialog := TOpenDialog.Create(nil);
    try
      LOpenDialog.Title := 'Open PDF File';
      LOpenDialog.Filter := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
      LOpenDialog.DefaultExt := 'pdf';
      LOpenDialog.Options := [TOpenOption.ofFileMustExist, TOpenOption.ofEnableSizing];

      if LOpenDialog.Execute then
      begin
        if TPath.GetExtension(LOpenDialog.FileName).ToLower = '.pdf' then
          LoadPdfFile(LOpenDialog.FileName)
        else
          ShowMessage('Please select a PDF file.');
      end;
    finally
      LOpenDialog.Free;
    end;
  finally
    FOpenDialogActive := False;
  end;
end;

procedure TMainForm.StatusLabelClick(Sender: TObject);
begin
  ShowOpenDialog;
end;

procedure TMainForm.MenuItemOpenFileClick(Sender: TObject);
begin
  ShowOpenDialog;
end;

end.

