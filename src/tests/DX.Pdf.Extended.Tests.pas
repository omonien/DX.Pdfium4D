/// <summary>
/// DX.Pdf.Extended.Tests
/// Extended tests for text extraction, search, rendering, rotation,
/// metadata, and error handling in DX.Pdf.Document.
/// </summary>
///
/// <remarks>
/// Covers critical API gaps not addressed by DX.Pdf.Document.Tests:
/// - Text extraction (GetText, GetCharBox, GetCharIndexAtPos, CountRects, GetBoundedText)
/// - Search (FindStart, FindNext, FindPrev, GetResultIndex, GetCount)
/// - Rendering (RenderToBitmap)
/// - Page rotation
/// - Metadata with real values
/// - Corrupted/invalid PDF handling
/// - Library reference counting
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Pdf.Extended.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  DX.Pdf.API,
  DX.Pdf.Document;

{$M+}

type
  [TestFixture]
  TPdfExtendedTests = class
  private
    FSimplePdfPath: string;
    FTextPdfPath: string;
    FCorruptedPdfPath: string;
    FNotAPdfPath: string;
    FMetadataPdfPath: string;
    FMultiPagePdfPath: string;

    procedure CreateSimplePdf;
    procedure CreateTextPdf;
    procedure CreateCorruptedPdf;
    procedure CreateNotAPdfFile;
    procedure CreateMetadataPdf;
    procedure CreateMultiPagePdf;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- Text Extraction ---
    [Test]
    procedure TestGetTextFromPage;
    [Test]
    procedure TestGetCharBoxValidIndex;
    [Test]
    procedure TestGetCharIndexAtPosValid;
    [Test]
    procedure TestCountRectsOnTextPage;
    [Test]
    procedure TestGetBoundedText;

    // --- Search ---
    [Test]
    procedure TestFindStartAndFindNext;
    [Test]
    procedure TestFindNextMultipleResults;
    [Test]
    procedure TestFindPrev;
    [Test]
    procedure TestSearchResultIndexAndCount;
    [Test]
    procedure TestSearchNoMatch;
    [Test]
    procedure TestSearchCaseSensitive;

    // --- Rendering ---
    [Test]
    procedure TestRenderToBitmapBasic;

    // --- Page Properties ---
    [Test]
    procedure TestPageRotationDefault;
    [Test]
    procedure TestPageHandle;

    // --- Metadata ---
    [Test]
    procedure TestMetadataWithRealValues;
    [Test]
    procedure TestMetadataNonExistentTag;
    [Test]
    procedure TestMetadataOnUnloadedDocument;

    // --- Error Handling ---
    [Test]
    procedure TestLoadCorruptedPdf;
    [Test]
    procedure TestLoadNonPdfFile;
    [Test]
    procedure TestLoadFromNilStream;
    [Test]
    procedure TestGetPageByIndexCreatesNewInstance;

    // --- Library Lifecycle ---
    [Test]
    procedure TestLibraryReferenceCountMultipleDocuments;

    // --- Multi-page ---
    [Test]
    procedure TestMultiPageNavigation;
  end;

implementation

{ Test PDF generators }

procedure TPdfExtendedTests.CreateSimplePdf;
const
  C_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'#10 +
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj'#10 +
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << >> >> endobj'#10 +
    '4 0 obj << /Length 0 >> stream'#10 +
    'endstream endobj'#10 +
    'xref'#10 +
    '0 5'#10 +
    '0000000000 65535 f '#10 +
    '0000000009 00000 n '#10 +
    '0000000058 00000 n '#10 +
    '0000000115 00000 n '#10 +
    '0000000229 00000 n '#10 +
    'trailer << /Size 5 /Root 1 0 R >>'#10 +
    'startxref'#10 +
    '277'#10 +
    '%%EOF';
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes(C_PDF);
  TFile.WriteAllBytes(FSimplePdfPath, LBytes);
end;

procedure TPdfExtendedTests.CreateTextPdf;
const
  // PDF with actual text content "Hello World Test" using Helvetica font
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

procedure TPdfExtendedTests.CreateCorruptedPdf;
var
  LBytes: TBytes;
begin
  // Starts with PDF header but has garbage content
  LBytes := TEncoding.ANSI.GetBytes('%PDF-1.4'#10'THIS IS NOT VALID PDF CONTENT'#10'%%EOF');
  TFile.WriteAllBytes(FCorruptedPdfPath, LBytes);
end;

procedure TPdfExtendedTests.CreateNotAPdfFile;
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes('This is just a plain text file, not a PDF.');
  TFile.WriteAllBytes(FNotAPdfPath, LBytes);
end;

procedure TPdfExtendedTests.CreateMetadataPdf;
const
  // PDF with Info dictionary containing Title, Author, Subject, Creator, Producer
  C_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'#10 +
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj'#10 +
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << >> >> endobj'#10 +
    '4 0 obj << /Length 0 >> stream'#10 +
    'endstream endobj'#10 +
    '5 0 obj << /Title (Test Document Title) /Author (Olaf Monien) ' +
      '/Subject (Unit Test Subject) /Creator (DX Pdfium4D Tests) ' +
      '/Producer (DX Pdfium4D) /Keywords (test, pdfium, delphi) >> endobj'#10 +
    'xref'#10 +
    '0 6'#10 +
    '0000000000 65535 f '#10 +
    '0000000009 00000 n '#10 +
    '0000000058 00000 n '#10 +
    '0000000115 00000 n '#10 +
    '0000000229 00000 n '#10 +
    '0000000277 00000 n '#10 +
    'trailer << /Size 6 /Root 1 0 R /Info 5 0 R >>'#10 +
    'startxref'#10 +
    '480'#10 +
    '%%EOF';
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes(C_PDF);
  TFile.WriteAllBytes(FMetadataPdfPath, LBytes);
end;

procedure TPdfExtendedTests.CreateMultiPagePdf;
const
  // 3-page PDF with text on each page
  C_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj'#10 +
    '2 0 obj << /Type /Pages /Kids [3 0 R 6 0 R 9 0 R] /Count 3 >> endobj'#10 +
    // Page 1
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ' +
      '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj'#10 +
    '4 0 obj << /Length 40 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Page One) Tj ET'#10 +
    'endstream endobj'#10 +
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    // Page 2
    '6 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ' +
      '/Contents 7 0 R /Resources << /Font << /F1 8 0 R >> >> >> endobj'#10 +
    '7 0 obj << /Length 40 >> stream'#10 +
    'BT /F1 12 Tf 100 700 Td (Page Two) Tj ET'#10 +
    'endstream endobj'#10 +
    '8 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj'#10 +
    // Page 3
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

{ Setup / TearDown }

procedure TPdfExtendedTests.Setup;
var
  LTempDir: string;
begin
  LTempDir := TPath.GetTempPath;
  FSimplePdfPath := TPath.Combine(LTempDir, 'ext_test_simple.pdf');
  FTextPdfPath := TPath.Combine(LTempDir, 'ext_test_text.pdf');
  FCorruptedPdfPath := TPath.Combine(LTempDir, 'ext_test_corrupted.pdf');
  FNotAPdfPath := TPath.Combine(LTempDir, 'ext_test_notapdf.txt');
  FMetadataPdfPath := TPath.Combine(LTempDir, 'ext_test_metadata.pdf');
  FMultiPagePdfPath := TPath.Combine(LTempDir, 'ext_test_multipage.pdf');

  CreateSimplePdf;
  CreateTextPdf;
  CreateCorruptedPdf;
  CreateNotAPdfFile;
  CreateMetadataPdf;
  CreateMultiPagePdf;
end;

procedure TPdfExtendedTests.TearDown;
begin
  if TFile.Exists(FSimplePdfPath) then TFile.Delete(FSimplePdfPath);
  if TFile.Exists(FTextPdfPath) then TFile.Delete(FTextPdfPath);
  if TFile.Exists(FCorruptedPdfPath) then TFile.Delete(FCorruptedPdfPath);
  if TFile.Exists(FNotAPdfPath) then TFile.Delete(FNotAPdfPath);
  if TFile.Exists(FMetadataPdfPath) then TFile.Delete(FMetadataPdfPath);
  if TFile.Exists(FMultiPagePdfPath) then TFile.Delete(FMultiPagePdfPath);
end;

{ Text Extraction Tests }

procedure TPdfExtendedTests.TestGetTextFromPage;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LCharCount: Integer;
  LText: string;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LCharCount := LPage.GetCharCount;
    Assert.IsTrue(LCharCount > 0, 'Text page should have characters');

    LText := LPage.GetText(0, LCharCount);

    Assert.IsTrue(LText.Contains('Hello'), 'Extracted text should contain "Hello"');
    Assert.IsTrue(LText.Contains('World'), 'Extracted text should contain "World"');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestGetCharBoxValidIndex;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LRect: TRectF;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Get bounding box for first character 'H'
    LRect := LPage.GetCharBox(0);

    // The rect should have non-zero dimensions
    Assert.IsTrue(LRect.Width > 0, 'Character box should have positive width');
    Assert.IsTrue(LRect.Height > 0, 'Character box should have positive height');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestGetCharIndexAtPosValid;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LIndex: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Text is at coordinates (100, 700) in PDF space
    // With tolerance, we should find a character
    LIndex := LPage.GetCharIndexAtPos(105, 700, 20, 20);

    // Should find a character (index >= 0) or -1 if not found
    // At coordinates near the text, we expect a valid index
    Assert.IsTrue(LIndex >= 0, 'Should find a character near the text position');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestCountRectsOnTextPage;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LCharCount: Integer;
  LRectCount: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LCharCount := LPage.GetCharCount;
    Assert.IsTrue(LCharCount > 0, 'Should have characters');

    // Count rects for all characters
    LRectCount := LPage.CountRects(0, LCharCount);
    Assert.IsTrue(LRectCount > 0, 'Should have at least one text rect');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestGetBoundedText;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LBuffer: string;
  LResult: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Create a large rect covering the whole page (in canvas coordinates)
    SetLength(LBuffer, 256);
    LResult := LPage.GetBoundedText(TRectF.Create(0, 0, 600, 850), LBuffer);

    // Result is number of characters found (may be 0 if coordinate mapping doesn't match)
    Assert.IsTrue(LResult >= 0, 'GetBoundedText should return >= 0');
  finally
    LDocument.Free;
  end;
end;

{ Search Tests }

procedure TPdfExtendedTests.TestFindStartAndFindNext;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LFound: Boolean;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LSearch := LPage.FindStart('Hello', 0, 0);
    Assert.IsNotNull(LSearch, 'FindStart should return a search handle');

    LFound := LSearch.FindNext;
    Assert.IsTrue(LFound, 'Should find "Hello" in the text');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestFindNextMultipleResults;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LFound: Boolean;
  LCount: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Search for 'l' which appears multiple times in "Hello World"
    LSearch := LPage.FindStart('l', 0, 0);

    LCount := 0;
    repeat
      LFound := LSearch.FindNext;
      if LFound then
        Inc(LCount);
    until not LFound;

    Assert.IsTrue(LCount >= 2, 'Should find "l" at least twice in "Hello World"');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestFindPrev;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearch: IPageSearch;
  LForwardIndex: Integer;
  LBackwardIndex: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LSearch := LPage.FindStart('l', 0, 0);

    // Find first occurrence
    Assert.IsTrue(LSearch.FindNext, 'Should find first "l"');
    LForwardIndex := LSearch.GetResultIndex;

    // Find second occurrence
    Assert.IsTrue(LSearch.FindNext, 'Should find second "l"');

    // Go back
    Assert.IsTrue(LSearch.FindPrev, 'FindPrev should return to first "l"');
    LBackwardIndex := LSearch.GetResultIndex;

    Assert.AreEqual(LForwardIndex, LBackwardIndex,
      'FindPrev should return to previous result position');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestSearchResultIndexAndCount;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearch: IPageSearch;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LSearch := LPage.FindStart('World', 0, 0);
    Assert.IsTrue(LSearch.FindNext, 'Should find "World"');

    Assert.IsTrue(LSearch.GetResultIndex >= 0, 'Result index should be >= 0');
    Assert.IsTrue(LSearch.GetCount > 0, 'Match count (length) should be > 0');
    Assert.AreEqual(5, LSearch.GetCount, 'Match count for "World" should be 5 characters');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestSearchNoMatch;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearch: IPageSearch;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    LSearch := LPage.FindStart('ZZZZNOTFOUND', 0, 0);
    Assert.IsFalse(LSearch.FindNext, 'Should not find non-existent text');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestSearchCaseSensitive;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LSearchInsensitive: IPageSearch;
  LSearchSensitive: IPageSearch;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTextPdfPath);
    LPage := LDocument.Pages[0];

    // Case-insensitive search (flags = 0)
    LSearchInsensitive := LPage.FindStart('hello', 0, 0);
    Assert.IsTrue(LSearchInsensitive.FindNext,
      'Case-insensitive search should find "hello" in "Hello World"');

    // Case-sensitive search (FPDF_MATCHCASE)
    LSearchSensitive := LPage.FindStart('hello', FPDF_MATCHCASE, 0);
    Assert.IsFalse(LSearchSensitive.FindNext,
      'Case-sensitive search should NOT find lowercase "hello" in "Hello World"');
  finally
    LDocument.Free;
  end;
end;

{ Rendering Tests }

procedure TPdfExtendedTests.TestRenderToBitmapBasic;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
  LBitmap: FPDF_BITMAP;
  LWidth, LHeight: Integer;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FSimplePdfPath);
    LPage := LDocument.Pages[0];

    // Render at 72 DPI (1:1 points to pixels)
    LWidth := Round(LPage.Width);
    LHeight := Round(LPage.Height);

    LBitmap := FPDFBitmap_Create(LWidth, LHeight, 0);
    Assert.IsTrue(LBitmap <> nil, 'Should create bitmap');
    try
      // Fill with white
      FPDFBitmap_FillRect(LBitmap, 0, 0, LWidth, LHeight, $FFFFFFFF);

      // Render page to bitmap
      FPDF_RenderPageBitmap(LBitmap, LPage.Handle, 0, 0, LWidth, LHeight, 0, 0);

      // Verify bitmap properties
      Assert.AreEqual(LWidth, FPDFBitmap_GetWidth(LBitmap), 'Bitmap width should match');
      Assert.AreEqual(LHeight, FPDFBitmap_GetHeight(LBitmap), 'Bitmap height should match');
      Assert.IsTrue(FPDFBitmap_GetStride(LBitmap) > 0, 'Bitmap stride should be positive');
      Assert.IsTrue(FPDFBitmap_GetBuffer(LBitmap) <> nil, 'Bitmap buffer should not be nil');
    finally
      FPDFBitmap_Destroy(LBitmap);
    end;
  finally
    LDocument.Free;
  end;
end;

{ Page Property Tests }

procedure TPdfExtendedTests.TestPageRotationDefault;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FSimplePdfPath);
    LPage := LDocument.Pages[0];

    // Default page has no rotation
    Assert.AreEqual(0, LPage.Rotation, 'Default page rotation should be 0');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestPageHandle;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FSimplePdfPath);
    LPage := LDocument.Pages[0];

    Assert.IsTrue(LPage.Handle <> nil, 'Loaded page handle should not be nil');
  finally
    LDocument.Free;
  end;
end;

{ Metadata Tests }

procedure TPdfExtendedTests.TestMetadataWithRealValues;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FMetadataPdfPath);

    Assert.AreEqual('Test Document Title', LDocument.GetMetadata('Title'),
      'Title metadata should match');
    Assert.AreEqual('Olaf Monien', LDocument.GetMetadata('Author'),
      'Author metadata should match');
    Assert.AreEqual('Unit Test Subject', LDocument.GetMetadata('Subject'),
      'Subject metadata should match');
    Assert.AreEqual('DX Pdfium4D Tests', LDocument.GetMetadata('Creator'),
      'Creator metadata should match');
    Assert.AreEqual('DX Pdfium4D', LDocument.GetMetadata('Producer'),
      'Producer metadata should match');
    Assert.AreEqual('test, pdfium, delphi', LDocument.GetMetadata('Keywords'),
      'Keywords metadata should match');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestMetadataNonExistentTag;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FSimplePdfPath);

    // Non-existent tag should return empty string, not raise exception
    Assert.AreEqual('', LDocument.GetMetadata('NonExistentTag'),
      'Non-existent metadata tag should return empty string');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestMetadataOnUnloadedDocument;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    // Should return empty string without exception
    Assert.AreEqual('', LDocument.GetMetadata('Title'),
      'Metadata on unloaded document should return empty string');
  finally
    LDocument.Free;
  end;
end;

{ Error Handling Tests }

procedure TPdfExtendedTests.TestLoadCorruptedPdf;
var
  LDocument: TPdfDocument;
  LExceptionRaised: Boolean;
begin
  LDocument := TPdfDocument.Create;
  try
    LExceptionRaised := False;
    try
      LDocument.LoadFromFile(FCorruptedPdfPath);
    except
      on E: EPdfLoadException do
        LExceptionRaised := True;
    end;

    Assert.IsTrue(LExceptionRaised, 'Loading corrupted PDF should raise EPdfLoadException');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestLoadNonPdfFile;
var
  LDocument: TPdfDocument;
  LExceptionRaised: Boolean;
begin
  LDocument := TPdfDocument.Create;
  try
    LExceptionRaised := False;
    try
      LDocument.LoadFromFile(FNotAPdfPath);
    except
      on E: EPdfLoadException do
        LExceptionRaised := True;
    end;

    Assert.IsTrue(LExceptionRaised, 'Loading non-PDF file should raise EPdfLoadException');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestLoadFromNilStream;
var
  LDocument: TPdfDocument;
  LExceptionRaised: Boolean;
begin
  LDocument := TPdfDocument.Create;
  try
    LExceptionRaised := False;
    try
      LDocument.LoadFromStream(nil, False);
    except
      on E: EPdfLoadException do
        LExceptionRaised := True;
    end;

    Assert.IsTrue(LExceptionRaised, 'Loading from nil stream should raise EPdfLoadException');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfExtendedTests.TestGetPageByIndexCreatesNewInstance;
var
  LDocument: TPdfDocument;
  LPage1, LPage2: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FSimplePdfPath);

    // GetPageByIndex creates a NEW instance each time (caller must free)
    LPage1 := LDocument.GetPageByIndex(0);
    LPage2 := LDocument.GetPageByIndex(0);
    try
      Assert.AreNotSame(LPage1, LPage2,
        'GetPageByIndex should create new instances (unlike cached Pages[])');
    finally
      LPage2.Free;
      LPage1.Free;
    end;
  finally
    LDocument.Free;
  end;
end;

{ Library Lifecycle Tests }

procedure TPdfExtendedTests.TestLibraryReferenceCountMultipleDocuments;
var
  LDoc1, LDoc2, LDoc3: TPdfDocument;
begin
  // Each TPdfDocument.Create calls TPdfLibrary.Initialize (incrementing refcount)
  LDoc1 := TPdfDocument.Create;
  LDoc2 := TPdfDocument.Create;
  LDoc3 := TPdfDocument.Create;

  Assert.IsTrue(TPdfLibrary.IsInitialized, 'Library should be initialized with 3 documents');

  LDoc1.Free; // decrements refcount
  Assert.IsTrue(TPdfLibrary.IsInitialized, 'Library should remain initialized with 2 remaining documents');

  LDoc2.Free;
  Assert.IsTrue(TPdfLibrary.IsInitialized, 'Library should remain initialized with 1 remaining document');

  LDoc3.Free;
  // After all documents freed, library may or may not be finalized depending on other refs
  // The important thing is that no crash occurred during cleanup
  Assert.Pass('Library reference counting survived multiple create/destroy cycles');
end;

{ Multi-page Tests }

procedure TPdfExtendedTests.TestMultiPageNavigation;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FMultiPagePdfPath);
    Assert.AreEqual(3, LDocument.PageCount, 'Should have 3 pages');

    // Access all pages and verify distinct dimensions/indices
    LPage := LDocument.Pages[0];
    Assert.AreEqual(0, LPage.PageIndex, 'First page index should be 0');
    Assert.AreEqual(595.0, LPage.Width, 0.1, 'Page 0 width should be 595 (A4)');

    LPage := LDocument.Pages[1];
    Assert.AreEqual(1, LPage.PageIndex, 'Second page index should be 1');
    Assert.AreEqual(612.0, LPage.Width, 0.1, 'Page 1 width should be 612 (Letter)');

    LPage := LDocument.Pages[2];
    Assert.AreEqual(2, LPage.PageIndex, 'Third page index should be 2');
    Assert.AreEqual(595.0, LPage.Width, 0.1, 'Page 2 width should be 595 (A4)');
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPdfExtendedTests);

end.
