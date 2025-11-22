{*******************************************************************************
  Project: DX.PdfViewerVCL

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    VCL PDF Viewer Demo Application.
    Demonstrates the usage of DX Pdfium4D wrapper with VCL.
    Supports drag-and-drop, keyboard navigation, and command-line parameters.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
program DX.PdfViewerVCL;

uses
  Vcl.Forms,
  Main.Form in 'Main.Form.pas' {MainForm},
  DX.Pdf.API in '..\DX.Pdf.API.pas',
  DX.Pdf.Document in '..\DX.Pdf.Document.pas',
  DX.Pdf.Viewer.Core in '..\DX.Pdf.Viewer.Core.pas',
  DX.Pdf.Viewer.VCL in '..\DX.Pdf.Viewer.VCL.pas',
  DX.Pdf.Renderer.VCL in '..\DX.Pdf.Renderer.VCL.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

