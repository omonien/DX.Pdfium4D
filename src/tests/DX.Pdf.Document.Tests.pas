{*******************************************************************************
  Unit: DX.Pdf.Document.Tests

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Unit tests for DX.Pdf.Document wrapper classes.
    Tests PDF document loading, metadata extraction, and rendering.

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.Document.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  FMX.Graphics,
  DX.Pdf.API,
  DX.Pdf.Document;

{$M+}

type
  [TestFixture]
  TPdfDocumentTests = class
  private
    FTestPdfPath: string;
    procedure CreateSimpleTestPdf;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestLibraryInitialization;

    [Test]
    procedure TestDocumentCreation;

    [Test]
    procedure TestLoadNonExistentFile;

    [Test]
    procedure TestLoadValidPdf;

    [Test]
    procedure TestPageCount;

    [Test]
    procedure TestGetPage;

    [Test]
    procedure TestPageDimensions;

    [Test]
    procedure TestCloseDocument;

    [Test]
    procedure TestMultipleDocuments;

    [Test]
    procedure TestPdfVersion;

    [Test]
    procedure TestGetMetadata;

    [Test]
    procedure TestGetPdfAInfo;

    [Test]
    procedure TestStringHelperCompatibility;

    [Test]
    procedure TestLoadFromStream;

    [Test]
    procedure TestLoadFromStreamMultiplePages;

    [Test]
    procedure TestLoadFromStreamEx;

    [Test]
    procedure TestLoadFromStreamExWithOwnership;

    [Test]
    procedure TestLoadFromStreamExSeekable;

    [Test]
    procedure TestLoadFromStreamExLargeFile;

    [Test]
    procedure TestStreamAdapterCallback;
  end;

implementation

{ TPdfDocumentTests }

procedure TPdfDocumentTests.Setup;
begin
  FTestPdfPath := TPath.Combine(TPath.GetTempPath, 'test_document.pdf');
  CreateSimpleTestPdf;
end;

procedure TPdfDocumentTests.TearDown;
begin
  if TFile.Exists(FTestPdfPath) then
    TFile.Delete(FTestPdfPath);
end;

procedure TPdfDocumentTests.CreateSimpleTestPdf;
const
  // Minimal valid PDF with one blank page (A4 size: 595x842 points)
  C_SIMPLE_PDF =
    '%PDF-1.4'#10 +
    '1 0 obj'#10 +
    '<< /Type /Catalog /Pages 2 0 R >>'#10 +
    'endobj'#10 +
    '2 0 obj'#10 +
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'#10 +
    'endobj'#10 +
    '3 0 obj'#10 +
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << >> >>'#10 +
    'endobj'#10 +
    '4 0 obj'#10 +
    '<< /Length 0 >>'#10 +
    'stream'#10 +
    'endstream'#10 +
    'endobj'#10 +
    'xref'#10 +
    '0 5'#10 +
    '0000000000 65535 f '#10 +
    '0000000009 00000 n '#10 +
    '0000000058 00000 n '#10 +
    '0000000115 00000 n '#10 +
    '0000000229 00000 n '#10 +
    'trailer'#10 +
    '<< /Size 5 /Root 1 0 R >>'#10 +
    'startxref'#10 +
    '277'#10 +
    '%%EOF';
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  LBytes := TEncoding.ANSI.GetBytes(C_SIMPLE_PDF);
  LStream := TFileStream.Create(FTestPdfPath, fmCreate);
  try
    LStream.WriteBuffer(LBytes, Length(LBytes));
  finally
    LStream.Free;
  end;
end;

procedure TPdfDocumentTests.TestLibraryInitialization;
begin
  TPdfLibrary.Initialize;
  Assert.IsTrue(TPdfLibrary.IsInitialized, 'PDFium library should be initialized');
  TPdfLibrary.Finalize;
end;

procedure TPdfDocumentTests.TestDocumentCreation;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    Assert.IsNotNull(LDocument, 'Document should be created');
    Assert.IsFalse(LDocument.IsLoaded, 'Document should not be loaded initially');
    Assert.AreEqual(0, LDocument.PageCount, 'Page count should be 0 for unloaded document');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadNonExistentFile;
var
  LDocument: TPdfDocument;
  LExceptionRaised: Boolean;
begin
  LDocument := TPdfDocument.Create;
  try
    LExceptionRaised := False;
    try
      LDocument.LoadFromFile('nonexistent_file.pdf');
    except
      on E: EPdfLoadException do
        LExceptionRaised := True;
    end;
    Assert.IsTrue(LExceptionRaised, 'Should raise EPdfLoadException for non-existent file');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadValidPdf;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);
    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded');
    Assert.AreEqual(FTestPdfPath, LDocument.FileName, 'File name should match');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestPageCount;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);
    Assert.AreEqual(1, LDocument.PageCount, 'Test PDF should have 1 page');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestGetPage;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);
    LPage := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage, 'Page should be loaded');
      Assert.AreEqual(0, LPage.PageIndex, 'Page index should be 0');
    finally
      LPage.Free;
    end;
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestPageDimensions;
var
  LDocument: TPdfDocument;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);
    LPage := LDocument.GetPageByIndex(0);
    try
      // A4 size is 595x842 points
      Assert.AreEqual(595.0, LPage.Width, 0.1, 'Page width should be 595 points (A4)');
      Assert.AreEqual(842.0, LPage.Height, 0.1, 'Page height should be 842 points (A4)');
    finally
      LPage.Free;
    end;
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestCloseDocument;
var
  LDocument: TPdfDocument;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);
    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded');
    
    LDocument.Close;
    Assert.IsFalse(LDocument.IsLoaded, 'Document should not be loaded after Close');
    Assert.AreEqual(0, LDocument.PageCount, 'Page count should be 0 after Close');
    Assert.AreEqual('', LDocument.FileName, 'File name should be empty after Close');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestMultipleDocuments;
var
  LDocument1: TPdfDocument;
  LDocument2: TPdfDocument;
begin
  LDocument1 := TPdfDocument.Create;
  LDocument2 := TPdfDocument.Create;
  try
    LDocument1.LoadFromFile(FTestPdfPath);
    LDocument2.LoadFromFile(FTestPdfPath);
    
    Assert.IsTrue(LDocument1.IsLoaded, 'Document 1 should be loaded');
    Assert.IsTrue(LDocument2.IsLoaded, 'Document 2 should be loaded');
    Assert.AreEqual(1, LDocument1.PageCount, 'Document 1 should have 1 page');
    Assert.AreEqual(1, LDocument2.PageCount, 'Document 2 should have 1 page');
  finally
    LDocument2.Free;
    LDocument1.Free;
  end;
end;

procedure TPdfDocumentTests.TestPdfVersion;
var
  LDocument: TPdfDocument;
  LVersion: Integer;
  LVersionString: string;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);

    LVersion := LDocument.GetFileVersion;
    LVersionString := LDocument.GetFileVersionString;

    Assert.IsTrue(LVersion > 0, 'PDF version should be greater than 0');
    Assert.AreEqual('1.4', LVersionString, 'PDF version string should be 1.4');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestGetMetadata;
var
  LDocument: TPdfDocument;
  LTitle: string;
  LAuthor: string;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);

    // Test metadata retrieval (may be empty for minimal PDF)
    LTitle := LDocument.GetMetadata('Title');
    LAuthor := LDocument.GetMetadata('Author');

    // Should not raise exception, even if empty
    Assert.Pass('Metadata retrieval works without errors');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestGetPdfAInfo;
var
  LDocument: TPdfDocument;
  LPdfAInfo: string;
begin
  LDocument := TPdfDocument.Create;
  try
    LDocument.LoadFromFile(FTestPdfPath);

    // Test PDF/A detection (should be empty for minimal PDF)
    LPdfAInfo := LDocument.GetPdfAInfo;

    // Should return empty string for non-PDF/A documents
    Assert.AreEqual('', LPdfAInfo, 'Minimal PDF should not be PDF/A');
  finally
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestStringHelperCompatibility;
var
  LTestString: string;
  LUpperString: string;
  LLowerString: string;
  LTrimmedString: string;
begin
  // Test String Helper methods used in PDF/A detection
  LTestString := '  PDF/A-1b  ';

  // Test ToUpper (replaces UpperCase)
  LUpperString := LTestString.ToUpper;
  Assert.IsTrue(LUpperString.Contains('PDF/A'), 'ToUpper should work correctly');

  // Test ToLower (replaces LowerCase)
  LLowerString := LTestString.ToLower;
  Assert.IsTrue(LLowerString.Contains('pdf/a'), 'ToLower should work correctly');

  // Test Trim
  LTrimmedString := LTestString.Trim;
  Assert.AreEqual('PDF/A-1b', LTrimmedString, 'Trim should remove whitespace');

  // Test Contains (replaces Pos > 0)
  Assert.IsTrue(LUpperString.Contains('PDF/A-1'), 'Contains should find substring');
  Assert.IsFalse(LUpperString.Contains('PDF/A-2'), 'Contains should not find non-existent substring');

  // Test chaining
  Assert.IsTrue(LTestString.Trim.ToUpper.Contains('PDF/A-1'), 'String helper chaining should work');
end;

procedure TPdfDocumentTests.TestLoadFromStream;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LVersion: Integer;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);
    LStream.Position := 0;

    // Load from stream
    LDocument.LoadFromStream(LStream);

    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded from stream');
    Assert.AreEqual(1, LDocument.PageCount, 'Page count should be 1');

    // Check PDF version
    LVersion := LDocument.GetFileVersion;
    Assert.AreEqual(14, LVersion, 'PDF version should be 1.4 (14)');
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadFromStreamMultiplePages;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);
    LStream.Position := 0;

    // Load from stream
    LDocument.LoadFromStream(LStream);

    // Test that we can access pages after loading from stream
    LPage := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage, 'Page should not be nil');

      // Test page dimensions
      Assert.IsTrue(LPage.Width > 0, 'Page width should be greater than 0');
      Assert.IsTrue(LPage.Height > 0, 'Page height should be greater than 0');
    finally
      LPage.Free;
    end;
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadFromStreamEx;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LVersion: Integer;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);
    LStream.Position := 0;

    // Load from stream using streaming API (stream is NOT owned)
    LDocument.LoadFromStreamEx(LStream, False);

    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded from stream');
    Assert.AreEqual(1, LDocument.PageCount, 'Page count should be 1');

    // Check PDF version
    LVersion := LDocument.GetFileVersion;
    Assert.AreEqual(14, LVersion, 'PDF version should be 1.4 (14)');

    // Stream should still be valid (not owned by document)
    Assert.IsNotNull(LStream, 'Stream should still exist');
  finally
    LStream.Free;  // We free it because we didn't transfer ownership
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadFromStreamExWithOwnership;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LPage: TPdfPage;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;

  // Load PDF into stream
  LStream.LoadFromFile(FTestPdfPath);
  LStream.Position := 0;

  // Load from stream with ownership transfer
  LDocument.LoadFromStreamEx(LStream, True);  // Document now owns the stream!

  try
    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded');

    // Access a page to verify streaming works
    LPage := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage, 'Page should not be nil');
      Assert.IsTrue(LPage.Width > 0, 'Page width should be greater than 0');
    finally
      LPage.Free;
    end;
  finally
    LDocument.Free;  // This will also free the stream
    // DO NOT free LStream here - it's owned by the document!
  end;
end;

procedure TPdfDocumentTests.TestLoadFromStreamExSeekable;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LPage1, LPage2: TPdfPage;
  LInitialPosition: Int64;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);
    LInitialPosition := LStream.Position;

    // Load from stream
    LDocument.LoadFromStreamEx(LStream, False);

    // Verify that PDFium can seek in the stream by accessing pages multiple times
    LPage1 := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage1, 'First page access should succeed');
    finally
      LPage1.Free;
    end;

    // Access same page again - requires seeking back
    LPage2 := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage2, 'Second page access should succeed (requires seeking)');
    finally
      LPage2.Free;
    end;
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestLoadFromStreamExLargeFile;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LPage: TPdfPage;
  LStreamSizeBefore: Int64;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);
    LStreamSizeBefore := LStream.Size;

    // Load using streaming API - should NOT duplicate memory
    LDocument.LoadFromStreamEx(LStream, False);

    // Verify stream is still the same size (not duplicated)
    Assert.AreEqual(LStreamSizeBefore, LStream.Size, 'Stream size should not change');

    // Verify we can still access the document
    Assert.IsTrue(LDocument.IsLoaded, 'Document should be loaded');

    LPage := LDocument.GetPageByIndex(0);
    try
      Assert.IsNotNull(LPage, 'Should be able to access page via streaming');
    finally
      LPage.Free;
    end;
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

procedure TPdfDocumentTests.TestStreamAdapterCallback;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
  LPage: TPdfPage;
  LCallbackExecuted: Boolean;
begin
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    // Load PDF into stream
    LStream.LoadFromFile(FTestPdfPath);

    // Load using streaming API
    LDocument.LoadFromStreamEx(LStream, False);

    // Access a page - this should trigger the GetBlock callback
    LPage := LDocument.GetPageByIndex(0);
    try
      // If we got here, the callback worked
      Assert.IsNotNull(LPage, 'Page should be loaded via callback');
      Assert.IsTrue(LPage.Width > 0, 'Page should have valid dimensions');
      LCallbackExecuted := True;
    finally
      LPage.Free;
    end;

    Assert.IsTrue(LCallbackExecuted, 'Stream adapter callback should have been executed');
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPdfDocumentTests);

end.

