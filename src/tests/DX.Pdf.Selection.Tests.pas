{*******************************************************************************
  Unit: DX.Pdf.Selection.Tests

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    DUnitX tests for text selection and page/screen coordinate mapping.
    Covers selected text, selection rectangles, word expansion, and
    FPDF_DeviceToPage / FPDF_PageToDevice under zoom, scroll and rotation.

  Author: Olaf Monien
  Copyright (c) 2026 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Selection.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  DX.Pdf.API,
  DX.Pdf.Document,
  DX.Pdf.Viewer.Core;

{$M+}

type
  [TestFixture]
  TPdfSelectionTests = class
  private
    FTextPdfPath: string;
    FMultiPagePdfPath: string;
    FSelectionChanges: Integer;
    procedure CreateTextPdf;
    procedure CreateMultiPagePdf;
    procedure HandleSelectionChanged(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestScreenDeviceRoundTrip;
    [Test]
    procedure TestScreenDeviceRejectsZeroScale;

    [Test]
    procedure TestDeviceToPageIsBottomUp;
    [Test]
    procedure TestPageDeviceRoundTripAllRotations;
    [Test]
    procedure TestZoomScalesDeviceCoordinates;
    [Test]
    procedure TestScrollOffsetsDeviceCoordinates;
    [Test]
    procedure TestRotationMovesPagePoint;

    [Test]
    procedure TestGetRectAfterCountRects;
    [Test]
    procedure TestCharIndexNearPosFallback;
    [Test]
    procedure TestCharIndexNearPosRejectsDistantPoint;

    [Test]
    procedure TestSelectionTextInclusiveAndReversed;
    [Test]
    procedure TestSelectAllAndClear;
    [Test]
    procedure TestSelectionDisabled;
    [Test]
    procedure TestSelectionChangedEvent;
    [Test]
    procedure TestSelectWord;
    [Test]
    procedure TestSetSelectionClampsAndNegativeClears;
    [Test]
    procedure TestSelectionRectsInPageSpace;
    [Test]
    procedure TestSelectionScreenRectsInsideView;
    [Test]
    procedure TestCharIndexAtScreenPointWithZoomScroll;
    [Test]
    procedure TestPageChangeClearsSelection;
  end;

implementation

type
  /// <summary>
  /// Concrete core used by tests. Render is synchronous and the current
  /// page is the document-owned Pages[] instance, so Close must not free it.
  /// </summary>
  TSelectionViewer = class(TPdfViewerCore)
  protected
    procedure DoRenderCurrentPage; override;
    procedure DoShowLoadingIndicator(AShow: Boolean); override;
  public
    procedure Close; override;
  end;

procedure TSelectionViewer.DoRenderCurrentPage;
begin
  if (Document <> nil) and Document.IsLoaded and (CurrentPageIndex >= 0) and
    (CurrentPageIndex < Document.PageCount) then
    CurrentPage := Document.Pages[CurrentPageIndex];
  IsRendering := False;
end;

procedure TSelectionViewer.DoShowLoadingIndicator(AShow: Boolean);
begin
  // No UI in the test core.
end;

procedure TSelectionViewer.Close;
begin
  // Pages[] are owned by the document. Drop the reference first so the
  // inherited Close does not free that instance.
  CurrentPage := nil;
  inherited;
end;

function OpenTextViewer(const APath: string): TSelectionViewer;
begin
  Result := TSelectionViewer.Create(nil);
  try
    Result.LoadFromFile(APath);
  except
    Result.Free;
    raise;
  end;
end;

{ TPdfSelectionTests }

procedure TPdfSelectionTests.CreateTextPdf;
const
  // Same "Hello World" page used by DX.Pdf.Extended.Tests.
  C_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'#10 +
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj'#10 +
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ' +
      '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj'#10 +
    '4 0 obj << /Length 44 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Hello World) Tj ET'#10 +
    'endstream endobj'#10 +
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    'xref'#10 +
    '0 6'#10 +
    '0000000000 65535 f '#10 +
    '0000000009 00000 n '#10 +
    '0000000058 00000 n '#10 +
    '0000000115 00000 n '#10 +
    '0000000268 00000 n '#10 +
    '0000000360 00000 n '#10 +
    'trailer << /Size 6 /Root 1 0 R >>'#10 +
    'startxref'#10 +
    '441'#10 +
    '%%EOF';
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes(C_PDF);
  TFile.WriteAllBytes(FTextPdfPath, LBytes);
end;

procedure TPdfSelectionTests.CreateMultiPagePdf;
const
  // Same 3-page document used by DX.Pdf.Extended.Tests.
  C_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'#10 +
    '2 0 obj << /Type /Pages /Kids [3 0 R 6 0 R 9 0 R] /Count 3 >> endobj'#10 +
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ' +
      '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj'#10 +
    '4 0 obj << /Length 40 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Page One) Tj ET'#10 +
    'endstream endobj'#10 +
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    '6 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ' +
      '/Contents 7 0 R /Resources << /Font << /F1 8 0 R >> >> >> endobj'#10 +
    '7 0 obj << /Length 40 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Page Two) Tj ET'#10 +
    'endstream endobj'#10 +
    '8 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    '9 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ' +
      '/Contents 10 0 R /Resources << /Font << /F1 11 0 R >> >> >> endobj'#10 +
    '10 0 obj << /Length 42 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Page Three) Tj ET'#10 +
    'endstream endobj'#10 +
    '11 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    'xref'#10 +
    '0 12'#10 +
    '0000000000 65535 f '#10 +
    '0000000009 00000 n '#10 +
    '0000000058 00000 n '#10 +
    '0000000131 00000 n '#10 +
    '0000000292 00000 n '#10 +
    '0000000383 00000 n '#10 +
    '0000000464 00000 n '#10 +
    '0000000625 00000 n '#10 +
    '0000000716 00000 n '#10 +
    '0000000797 00000 n '#10 +
    '0000000960 00000 n '#10 +
    '0000001053 00000 n '#10 +
    'trailer << /Size 12 /Root 1 0 R >>'#10 +
    'startxref'#10 +
    '1134'#10 +
    '%%EOF';
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes(C_PDF);
  TFile.WriteAllBytes(FMultiPagePdfPath, LBytes);
end;

procedure TPdfSelectionTests.HandleSelectionChanged(Sender: TObject);
begin
  Inc(FSelectionChanges);
end;

procedure TPdfSelectionTests.Setup;
var
  LTempDir: string;
begin
  LTempDir := TPath.GetTempPath;
  FTextPdfPath := TPath.Combine(LTempDir, 'sel_test_text.pdf');
  FMultiPagePdfPath := TPath.Combine(LTempDir, 'sel_test_multipage.pdf');
  CreateTextPdf;
  CreateMultiPagePdf;
  FSelectionChanges := 0;
end;

procedure TPdfSelectionTests.TearDown;
begin
  if TFile.Exists(FTextPdfPath) then
    TFile.Delete(FTextPdfPath);
  if TFile.Exists(FMultiPagePdfPath) then
    TFile.Delete(FMultiPagePdfPath);
end;

procedure TPdfSelectionTests.TestScreenDeviceRoundTrip;
var
  LMap: TPdfPageViewMap;
  LDeviceX, LDeviceY: Integer;
  LScreenX, LScreenY: Double;
begin
  LMap := Default(TPdfPageViewMap);
  LMap.StartX := 0;
  LMap.StartY := 0;
  LMap.SizeX := 200;
  LMap.SizeY := 400;
  LMap.Rotate := 0;
  LMap.ScreenLeft := 15;
  LMap.ScreenTop := 30;
  LMap.ScreenScaleX := 0.5;
  LMap.ScreenScaleY := 0.5;

  // screen = origin + device * scale
  Assert.IsTrue(PdfScreenToDevice(LMap, 15 + 10 * 0.5, 30 + 20 * 0.5, LDeviceX, LDeviceY));
  Assert.AreEqual(10, LDeviceX, 'Device X');
  Assert.AreEqual(20, LDeviceY, 'Device Y');

  Assert.IsTrue(PdfDeviceToScreen(LMap, 10, 20, LScreenX, LScreenY));
  Assert.AreEqual(20.0, LScreenX, 0.001, 'Screen X');
  Assert.AreEqual(40.0, LScreenY, 0.001, 'Screen Y');
end;

procedure TPdfSelectionTests.TestScreenDeviceRejectsZeroScale;
var
  LMap: TPdfPageViewMap;
  LDeviceX, LDeviceY: Integer;
  LScreenX, LScreenY: Double;
  LScreenRect: TRectF;
begin
  LMap := Default(TPdfPageViewMap);
  LMap.SizeX := 100;
  LMap.SizeY := 100;
  LMap.ScreenScaleX := 0;
  LMap.ScreenScaleY := 1;

  Assert.IsFalse(PdfScreenToDevice(LMap, 10, 10, LDeviceX, LDeviceY));
  Assert.IsFalse(PdfDeviceToScreen(LMap, 10, 10, LScreenX, LScreenY));
  Assert.IsFalse(PdfRectToScreen(nil, LMap, TRectF.Create(0, 10, 10, 0), LScreenRect));
end;

procedure TPdfSelectionTests.TestDeviceToPageIsBottomUp;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LWidth, LHeight: Integer;
  LTopX, LTopY, LBottomX, LBottomY: Double;
  LDeviceXHigh, LDeviceYHigh, LDeviceXLow, LDeviceYLow: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    Assert.IsTrue(LPage.DeviceToPage(0, 0, LWidth, LHeight, 0, 0, 0, LTopX, LTopY),
      'Top-left device point should convert');
    Assert.IsTrue(LPage.DeviceToPage(0, 0, LWidth, LHeight, 0, 0, LHeight - 1, LBottomX, LBottomY),
      'Bottom-left device point should convert');

    // PDF Y grows upward, so the top of the device is a larger page Y.
    Assert.IsTrue(LTopY > LBottomY, 'Top of the device must map above the bottom');
    Assert.IsTrue(LTopY > LPage.Height * 0.75, 'Top-left device Y should sit near the top of the page');
    Assert.IsTrue(LBottomY < LPage.Height * 0.25, 'Bottom device Y should sit near the bottom of the page');
    Assert.IsTrue(Abs(LTopX) < 2, 'Top-left device X should sit on the left edge');
    Assert.IsTrue(Abs(LBottomX) < 2, 'Bottom-left device X should sit on the left edge');

    // A larger page Y (700, near the top) maps to a smaller device Y than page Y 100.
    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, 0, 100, 700,
      LDeviceXHigh, LDeviceYHigh));
    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, 0, 100, 100,
      LDeviceXLow, LDeviceYLow));
    Assert.IsTrue(LDeviceYHigh < LDeviceYLow, 'PageToDevice keeps PDF Y bottom-up');
    Assert.IsTrue(Abs(LDeviceXHigh - LDeviceXLow) <= 2, 'The same page X stays on the same device column');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestPageDeviceRoundTripAllRotations;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LWidth, LHeight, LRotate, LDeviceX, LDeviceY, LBackX, LBackY: Integer;
  LPageX, LPageY: Double;
  LSampleX, LSampleY: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    for LRotate := 0 to 3 do
      for LSampleX := 0 to 2 do
        for LSampleY := 0 to 2 do
        begin
          LDeviceX := (LSampleX * (LWidth - 1)) div 2;
          LDeviceY := (LSampleY * (LHeight - 1)) div 2;
          Assert.IsTrue(LPage.DeviceToPage(0, 0, LWidth, LHeight, LRotate, LDeviceX, LDeviceY, LPageX, LPageY),
            'DeviceToPage rotate ' + IntToStr(LRotate));
          Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, LRotate, LPageX, LPageY, LBackX, LBackY),
            'PageToDevice rotate ' + IntToStr(LRotate));
          Assert.IsTrue(Abs(LBackX - LDeviceX) <= 2, 'Round-trip X rotate ' + IntToStr(LRotate));
          Assert.IsTrue(Abs(LBackY - LDeviceY) <= 2, 'Round-trip Y rotate ' + IntToStr(LRotate));
        end;
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestZoomScalesDeviceCoordinates;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LWidth, LHeight: Integer;
  LDeviceX1, LDeviceY1, LDeviceX2, LDeviceY2: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, 0,
      LPage.Width / 2, LPage.Height / 2, LDeviceX1, LDeviceY1));
    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth * 2, LHeight * 2, 0,
      LPage.Width / 2, LPage.Height / 2, LDeviceX2, LDeviceY2));

    Assert.IsTrue(Abs(LDeviceX2 - (LDeviceX1 * 2)) <= 2, 'Zoom doubles device X');
    Assert.IsTrue(Abs(LDeviceY2 - (LDeviceY1 * 2)) <= 2, 'Zoom doubles device Y');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestScrollOffsetsDeviceCoordinates;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LWidth, LHeight: Integer;
  LDeviceX1, LDeviceY1, LDeviceX2, LDeviceY2: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    // Page (0, height) is the top-left corner when rotation is 0.
    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, 0, 0, LPage.Height, LDeviceX1, LDeviceY1));
    Assert.IsTrue(LPage.PageToDevice(40, 25, LWidth, LHeight, 0, 0, LPage.Height, LDeviceX2, LDeviceY2));

    Assert.IsTrue(Abs(LDeviceX2 - (LDeviceX1 + 40)) <= 1, 'start_x scrolls device X');
    Assert.IsTrue(Abs(LDeviceY2 - (LDeviceY1 + 25)) <= 1, 'start_y scrolls device Y');

    // The same scroll is applied in device space when the page is rotated.
    Assert.IsTrue(LPage.PageToDevice(0, 0, LWidth, LHeight, 1, 0, 0, LDeviceX1, LDeviceY1));
    Assert.IsTrue(LPage.PageToDevice(40, 25, LWidth, LHeight, 1, 0, 0, LDeviceX2, LDeviceY2));
    Assert.IsTrue(Abs(LDeviceX2 - (LDeviceX1 + 40)) <= 1, 'Rotated start_x scrolls device X');
    Assert.IsTrue(Abs(LDeviceY2 - (LDeviceY1 + 25)) <= 1, 'Rotated start_y scrolls device Y');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestRotationMovesPagePoint;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LWidth, LHeight: Integer;
  X0, Y0, X1, Y1: Double;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    Assert.IsTrue(LPage.DeviceToPage(0, 0, LWidth, LHeight, 0, 0, 0, X0, Y0));
    Assert.IsTrue(LPage.DeviceToPage(0, 0, LWidth, LHeight, 1, 0, 0, X1, Y1));

    // 90-degree clockwise rotation maps that device corner to another page corner.
    Assert.IsTrue((Abs(X1 - X0) > LPage.Width * 0.25) or (Abs(Y1 - Y0) > LPage.Height * 0.25),
      'Rotation must change the page point for the same device corner');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestGetRectAfterCountRects;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LCount, I: Integer;
  LRect: TRectF;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];
    LCount := LPage.CountRects(0, LPage.GetCharCount);
    Assert.IsTrue(LCount > 0, 'CountRects should return at least one rectangle');
    Assert.IsTrue(LPage.GetRect(0, LRect), 'GetRect(0) should succeed after CountRects');
    Assert.IsTrue(LRect.Right > LRect.Left, 'PDF rect has positive width');
    Assert.IsTrue(LRect.Top > LRect.Bottom, 'PDF rect keeps bottom-up Y (top > bottom)');
    Assert.IsFalse(LPage.GetRect(-1, LRect), 'Negative rect index should fail');
    Assert.IsFalse(LPage.GetRect(LCount + 5, LRect), 'Rect index past CountRects should fail');

    for I := 0 to LCount - 1 do
    begin
      Assert.IsTrue(LPage.GetRect(I, LRect), 'GetRect index ' + IntToStr(I));
      Assert.IsTrue(LRect.Left >= -1, 'Rect left inside the page');
      Assert.IsTrue(LRect.Right <= LPage.Width + 1, 'Rect right inside the page');
    end;
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestCharIndexNearPosFallback;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LLeft, LRight, LBottom, LTop, LCenterX, LProbeY: Double;
  LStep, LHit, LDirect: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    Assert.IsTrue(FPDFText_GetCharBox(LPage.TextHandle, 0, LLeft, LRight, LBottom, LTop),
      'First character should have a box');
    LCenterX := (LLeft + LRight) * 0.5;

    // Walk upward from the glyph until the strict hit test misses, then
    // the nearest-character fallback should still return that character.
    LHit := -1;
    for LStep := 4 to 30 do
    begin
      LProbeY := LTop + LStep;
      LDirect := LPage.GetCharIndexAtPos(LCenterX, LProbeY, 0.5, 0.5);
      if LDirect < 0 then
      begin
        LHit := LPage.CharIndexNearPos(LCenterX, LProbeY, 0.5, 0.5, 36);
        Break;
      end;
    end;

    Assert.IsTrue(LHit >= 0, 'A point just outside the glyph should snap to a character');
    Assert.AreEqual(0, LHit, 'The point above the first glyph should snap to character 0');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestCharIndexNearPosRejectsDistantPoint;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LIndex: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Text sits near y = 700. The bottom-left of the page is far away.
    LIndex := LPage.CharIndexNearPos(10, 10, 1, 1, 36);
    Assert.AreEqual(-1, LIndex, 'A distant point must not snap to a character');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectionTextInclusiveAndReversed;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LIndex, LCount: Integer;
  LExpected, LForward: string;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LPage := LViewer.CurrentPage;
    Assert.IsNotNull(LPage, 'Viewer should expose the current page');
    Assert.IsTrue(LViewer.SelectionEnabled, 'Selection is enabled by default');
    Assert.AreEqual('', LViewer.GetSelectedText, 'Nothing is selected after load');

    LSearch := LPage.FindStart('Hello', 0, 0);
    Assert.IsTrue(LSearch.FindNext, 'The page contains Hello');
    LIndex := LSearch.GetResultIndex;
    LCount := LSearch.GetCount;
    Assert.IsTrue(LCount > 0, 'Hello match has a length');

    LExpected := LPage.GetText(LIndex, LCount);
    LViewer.SetSelection(LIndex, LIndex + LCount - 1);
    LForward := LViewer.GetSelectedText;
    Assert.AreEqual(LExpected, LForward, 'Inclusive range returns the matched text');
    Assert.IsTrue(LForward.Contains('Hello'), 'Selected text contains Hello');

    LViewer.SetSelection(LIndex + LCount - 1, LIndex);
    Assert.AreEqual(LForward, LViewer.GetSelectedText, 'Reversed anchor and focus return the same text');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectAllAndClear;
var
  LViewer: TSelectionViewer;
  LText: string;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LViewer.SelectAll;
    Assert.IsTrue(LViewer.HasSelection, 'SelectAll selects the page');
    LText := LViewer.GetSelectedText;
    Assert.IsTrue(LText.Contains('Hello'), 'SelectAll includes Hello');
    Assert.IsTrue(LText.Contains('World'), 'SelectAll includes World');

    LViewer.ClearSelection;
    Assert.IsFalse(LViewer.HasSelection, 'ClearSelection drops the range');
    Assert.AreEqual('', LViewer.GetSelectedText);
    Assert.AreEqual(Integer(0), Integer(Length(LViewer.GetSelectionRects)), 'No rectangles after clear');

    // Clearing an empty selection is a no-op.
    LViewer.OnSelectionChanged := HandleSelectionChanged;
    FSelectionChanges := 0;
    LViewer.ClearSelection;
    Assert.AreEqual(0, FSelectionChanges, 'Clearing an empty selection does not notify');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectionDisabled;
var
  LViewer: TSelectionViewer;
  LMap: TPdfPageViewMap;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LViewer.SelectAll;
    Assert.IsTrue(LViewer.HasSelection);

    LViewer.SelectionEnabled := False;
    Assert.IsFalse(LViewer.HasSelection, 'Disabling selection clears it');
    Assert.AreEqual('', LViewer.GetSelectedText);

    LViewer.SelectAll;
    LViewer.SetSelection(0, 4);
    Assert.IsFalse(LViewer.HasSelection, 'SelectAll and SetSelection are ignored while disabled');

    LMap := Default(TPdfPageViewMap);
    LMap.SizeX := Round(LViewer.CurrentPage.Width);
    LMap.SizeY := Round(LViewer.CurrentPage.Height);
    LMap.ScreenScaleX := 1;
    LMap.ScreenScaleY := 1;
    Assert.AreEqual(-1, LViewer.CharIndexAtScreenPoint(LMap, 100, 100),
      'Hit testing is off while selection is disabled');

    LViewer.SelectionEnabled := True;
    LViewer.SelectAll;
    Assert.IsTrue(LViewer.HasSelection, 'Selection works again after it is re-enabled');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectionChangedEvent;
var
  LViewer: TSelectionViewer;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LViewer.OnSelectionChanged := HandleSelectionChanged;
    FSelectionChanges := 0;

    LViewer.SelectAll;
    Assert.AreEqual(1, FSelectionChanges, 'SelectAll notifies once');

    LViewer.SelectAll;
    Assert.AreEqual(1, FSelectionChanges, 'Selecting the same range does not notify again');

    LViewer.ClearSelection;
    Assert.AreEqual(2, FSelectionChanges, 'Clear notifies');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectWord;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LIndex, LCount: Integer;
  LExpected: string;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LPage := LViewer.CurrentPage;
    LSearch := LPage.FindStart('Hello', 0, 0);
    Assert.IsTrue(LSearch.FindNext);
    LIndex := LSearch.GetResultIndex;
    LCount := LSearch.GetCount;
    LExpected := LPage.GetText(LIndex, LCount);

    LViewer.SelectWordAt(LIndex + (LCount div 2));
    Assert.AreEqual(LExpected, LViewer.GetSelectedText, 'Double-click word covers Hello');
    Assert.IsFalse(LViewer.GetSelectedText.Contains('World'), 'The word does not include World');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSetSelectionClampsAndNegativeClears;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LText: string;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LPage := LViewer.CurrentPage;
    LViewer.SetSelection(0, 100000);
    Assert.AreEqual(0, LViewer.SelectionAnchor);
    Assert.AreEqual(LPage.GetCharCount - 1, LViewer.SelectionFocus, 'Focus is clamped to the last character');
    LText := LViewer.GetSelectedText;
    Assert.IsTrue(LText.Contains('Hello'));
    Assert.IsTrue(LText.Contains('World'));

    LViewer.SetSelection(-1, 2);
    Assert.IsFalse(LViewer.HasSelection, 'A negative index clears the selection');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectionRectsInPageSpace;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LIndex, LCount, I: Integer;
  LRects: TArray<TRectF>;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LPage := LViewer.CurrentPage;
    LSearch := LPage.FindStart('Hello', 0, 0);
    Assert.IsTrue(LSearch.FindNext);
    LIndex := LSearch.GetResultIndex;
    LCount := LSearch.GetCount;

    LViewer.SetSelection(LIndex, LIndex + LCount - 1);
    LRects := LViewer.GetSelectionRects;
    Assert.IsTrue(Length(LRects) >= 1, 'The word produces at least one rectangle');

    for I := 0 to High(LRects) do
    begin
      Assert.IsTrue(LRects[I].Right > LRects[I].Left, 'Width is positive');
      Assert.IsTrue(LRects[I].Top > LRects[I].Bottom, 'PDF Y is bottom-up');
      Assert.IsTrue(LRects[I].Left > 40, 'Hello starts to the right of the left margin');
      Assert.IsTrue(LRects[I].Left < 180, 'Hello starts near x = 100');
      Assert.IsTrue(LRects[I].Right <= LPage.Width + 1);
      Assert.IsTrue(LRects[I].Bottom >= -1);
      Assert.IsTrue(LRects[I].Top <= LPage.Height + 1);
    end;

    LViewer.SetSelection(LIndex + LCount - 1, LIndex);
    Assert.AreEqual(Length(LRects), Length(LViewer.GetSelectionRects),
      'Reversed selection yields the same rectangles');
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestSelectionScreenRectsInsideView;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LMap: TPdfPageViewMap;
  LRects: TArray<TRectF>;
  LViewRight, LViewBottom: Double;
  LRotate, I: Integer;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LViewer.SelectAll;
    LPage := LViewer.CurrentPage;

    for LRotate := 0 to 3 do
    begin
      LMap := Default(TPdfPageViewMap);
      LMap.StartX := 0;
      LMap.StartY := 0;
      LMap.SizeX := Round(LPage.Width);
      LMap.SizeY := Round(LPage.Height);
      LMap.Rotate := LRotate;
      LMap.ScreenLeft := 12;
      LMap.ScreenTop := 18;
      LMap.ScreenScaleX := 1;
      LMap.ScreenScaleY := 1;

      LRects := LViewer.GetSelectionScreenRects(LMap);
      Assert.IsTrue(Length(LRects) >= 1, 'Screen rectangles for rotate ' + IntToStr(LRotate));

      LViewRight := LMap.ScreenLeft + LMap.SizeX * LMap.ScreenScaleX;
      LViewBottom := LMap.ScreenTop + LMap.SizeY * LMap.ScreenScaleY;
      for I := 0 to High(LRects) do
      begin
        Assert.IsTrue(LRects[I].Right > LRects[I].Left, 'Screen width');
        Assert.IsTrue(LRects[I].Bottom > LRects[I].Top, 'Screen Y grows downward');
        Assert.IsTrue(LRects[I].Left >= LMap.ScreenLeft - 2, 'Inside view, left');
        Assert.IsTrue(LRects[I].Top >= LMap.ScreenTop - 2, 'Inside view, top');
        Assert.IsTrue(LRects[I].Right <= LViewRight + 2, 'Inside view, right');
        Assert.IsTrue(LRects[I].Bottom <= LViewBottom + 2, 'Inside view, bottom');
      end;
    end;
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestCharIndexAtScreenPointWithZoomScroll;
var
  LViewer: TSelectionViewer;
  LPage: TPdfPage;
  LMap: TPdfPageViewMap;
  LLeft, LRight, LBottom, LTop, LCenterX, LCenterY, LBackX, LBackY, LScreenX, LScreenY: Double;
  LDeviceX, LDeviceY, LBackDeviceX, LBackDeviceY, LRotate, LHit: Integer;
begin
  LViewer := OpenTextViewer(FTextPdfPath);
  try
    LPage := LViewer.CurrentPage;
    Assert.IsTrue(FPDFText_GetCharBox(LPage.TextHandle, 0, LLeft, LRight, LBottom, LTop));
    LCenterX := (LLeft + LRight) * 0.5;
    LCenterY := (LBottom + LTop) * 0.5;

    for LRotate := 0 to 3 do
    begin
      LMap := Default(TPdfPageViewMap);
      LMap.StartX := 17;
      LMap.StartY := 9;
      LMap.SizeX := Round(LPage.Width * 2);
      LMap.SizeY := Round(LPage.Height * 2);
      LMap.Rotate := LRotate;
      LMap.ScreenLeft := 30;
      LMap.ScreenTop := 40;
      LMap.ScreenScaleX := 0.5;
      LMap.ScreenScaleY := 0.5;

      Assert.IsTrue(LPage.PageToDevice(LMap.StartX, LMap.StartY, LMap.SizeX, LMap.SizeY, LRotate,
        LCenterX, LCenterY, LDeviceX, LDeviceY), 'PageToDevice rotate ' + IntToStr(LRotate));
      Assert.IsTrue(PdfDeviceToScreen(LMap, LDeviceX, LDeviceY, LScreenX, LScreenY));
      Assert.IsTrue(PdfScreenToDevice(LMap, LScreenX, LScreenY, LBackDeviceX, LBackDeviceY));
      Assert.IsTrue(Abs(LBackDeviceX - LDeviceX) <= 1, 'Screen round-trip X');
      Assert.IsTrue(Abs(LBackDeviceY - LDeviceY) <= 1, 'Screen round-trip Y');

      Assert.IsTrue(LPage.DeviceToPage(LMap.StartX, LMap.StartY, LMap.SizeX, LMap.SizeY, LRotate,
        LDeviceX, LDeviceY, LBackX, LBackY));
      Assert.AreEqual(LCenterX, LBackX, 1.5, 'Zoomed page X');
      Assert.AreEqual(LCenterY, LBackY, 1.5, 'Zoomed page Y');

      LHit := LViewer.CharIndexAtScreenPoint(LMap, LScreenX, LScreenY);
      Assert.AreEqual(0, LHit, 'Hit test finds character 0 at rotate ' + IntToStr(LRotate));
    end;
  finally
    LViewer.Free;
  end;
end;

procedure TPdfSelectionTests.TestPageChangeClearsSelection;
var
  LViewer: TSelectionViewer;
begin
  LViewer := OpenTextViewer(FMultiPagePdfPath);
  try
    Assert.IsTrue(LViewer.PageCount >= 2, 'Fixture has more than one page');
    LViewer.SelectAll;
    Assert.IsTrue(LViewer.GetSelectedText.Contains('Page'));
    Assert.IsTrue(LViewer.HasSelection);

    // Setting the same page keeps the selection.
    LViewer.CurrentPageIndex := 0;
    Assert.IsTrue(LViewer.HasSelection, 'Staying on the same page keeps the selection');

    LViewer.OnSelectionChanged := HandleSelectionChanged;
    FSelectionChanges := 0;
    LViewer.CurrentPageIndex := 1;
    Assert.IsFalse(LViewer.HasSelection, 'Changing page clears the selection');
    Assert.AreEqual(1, FSelectionChanges, 'Clearing on page change notifies');

    LViewer.SelectAll;
    Assert.IsTrue(LViewer.GetSelectedText.Contains('Two'), 'Page 2 text can be selected');
  finally
    LViewer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPdfSelectionTests);

end.
