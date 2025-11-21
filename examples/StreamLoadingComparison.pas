unit StreamLoadingComparison;

{*******************************************************************************
  Demonstrates the three different methods for loading PDFs in DX.Pdfium4D:
  1. LoadFromFile - Direct file loading
  2. LoadFromStream - Legacy stream loading (loads entire PDF into memory)
  3. LoadFromStreamEx - True streaming support (efficient, on-demand loading)
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  DX.Pdf.Document,
  DX.Pdf.Viewer.FMX;

type
  TPdfLoadingExamples = class
  public
    /// <summary>
    /// Method 1: Load from file (recommended for local files)
    /// </summary>
    class procedure LoadFromFileExample(APdfViewer: TPdfViewer);

    /// <summary>
    /// Method 2: Load from stream - LEGACY (loads entire PDF into memory)
    /// </summary>
    class procedure LoadFromStreamLegacyExample(APdfViewer: TPdfViewer);

    /// <summary>
    /// Method 3: Load from stream - NEW (true streaming, efficient)
    /// </summary>
    class procedure LoadFromStreamExExample(APdfViewer: TPdfViewer);

    /// <summary>
    /// Comparison: Memory usage for different methods
    /// </summary>
    class procedure CompareMemoryUsage;
  end;

implementation

{ TPdfLoadingExamples }

class procedure TPdfLoadingExamples.LoadFromFileExample(APdfViewer: TPdfViewer);
begin
  // ✅ Method 1: Load from file
  // - Simplest method
  // - PDFium handles file access internally
  // - Implementation unknown (could be memory-mapped, buffered, or streaming)
  // - Best for: Local files that already exist on disk
  
  APdfViewer.LoadFromFile('C:\Documents\report.pdf');
  
  // That's it! No stream management needed.
end;

class procedure TPdfLoadingExamples.LoadFromStreamLegacyExample(APdfViewer: TPdfViewer);
var
  LStream: TMemoryStream;
begin
  // ⚠️ Method 2: LoadFromStream (LEGACY - DEPRECATED)
  // - Loads ENTIRE stream into memory (TBytes buffer)
  // - Buffer remains in memory for document lifetime
  // - Uses FPDF_LoadMemDocument internally
  // - Best for: Small PDFs only (<10 MB)
  // - NOT recommended for large files!
  
  LStream := TMemoryStream.Create;
  try
    // Example: Load from HTTP
    // LHttpClient.Get('https://example.com/document.pdf', LStream);
    LStream.LoadFromFile('C:\Documents\report.pdf');
    LStream.Position := 0;
    
    // ⚠️ WARNING: Entire stream is copied into internal buffer!
    APdfViewer.LoadFromStream(LStream);
    
    // Stream can be freed immediately - data is already copied
  finally
    LStream.Free;
  end;
  
  // Memory impact: PDF size + internal buffer = 2x PDF size (temporarily)
  // After stream is freed: PDF size remains in TPdfDocument.FMemoryBuffer
end;

class procedure TPdfLoadingExamples.LoadFromStreamExExample(APdfViewer: TPdfViewer);
var
  LStream: TMemoryStream;
begin
  // ✅ Method 3: LoadFromStreamEx (RECOMMENDED for streams)
  // - TRUE streaming support via FPDF_LoadCustomDocument
  // - PDFium reads blocks on-demand via callback
  // - Stream is NOT duplicated in memory
  // - Stream must remain valid for document lifetime
  // - Best for: Large PDFs, network streams, memory-constrained scenarios
  
  LStream := TMemoryStream.Create;
  
  // Example: Load from HTTP, database, encrypted container, etc.
  LStream.LoadFromFile('C:\Documents\large_report.pdf');
  LStream.Position := 0;
  
  // Option A: Keep ownership of stream (you manage lifetime)
  APdfViewer.LoadFromStreamEx(LStream, False);  // AOwnsStream = False
  // You MUST keep LStream alive until document is closed!
  // You MUST free LStream yourself later
  
  // Option B: Transfer ownership to viewer (recommended)
  // APdfViewer.LoadFromStreamEx(LStream, True);  // AOwnsStream = True
  // Viewer will free the stream when document is closed
  // DO NOT free LStream yourself!
  
  // Memory impact: Only 1x PDF size (the stream itself)
  // PDFium reads blocks on-demand - no duplication!
end;

class procedure TPdfLoadingExamples.CompareMemoryUsage;
var
  LDocument: TPdfDocument;
  LStream: TMemoryStream;
begin
  // Comparison for a 100 MB PDF file:
  //
  // ┌─────────────────────────────────────────────────────────────┐
  // │ Method              │ Memory Usage    │ Recommendation      │
  // ├─────────────────────────────────────────────────────────────┤
  // │ LoadFromFile        │ Unknown*        │ ✅ Good for local   │
  // │                     │                 │    files            │
  // ├─────────────────────────────────────────────────────────────┤
  // │ LoadFromStream      │ ~200 MB         │ ⚠️ Only for small   │
  // │ (Legacy)            │ (2x during load)│    PDFs (<10 MB)    │
  // │                     │ ~100 MB after   │                     │
  // ├─────────────────────────────────────────────────────────────┤
  // │ LoadFromStreamEx    │ ~100 MB         │ ✅ Best for streams │
  // │ (Recommended)       │ (1x, no copy)   │    and large files  │
  // └─────────────────────────────────────────────────────────────┘
  //
  // * PDFium's internal implementation is not documented
  //   Could be memory-mapped, buffered, or streaming
  
  LDocument := TPdfDocument.Create;
  LStream := TMemoryStream.Create;
  try
    LStream.LoadFromFile('large_file.pdf');
    
    // Use LoadFromStreamEx for efficient streaming
    LDocument.LoadFromStreamEx(LStream, False);
    
    // Stream is NOT duplicated - PDFium reads on-demand
    // Memory usage = stream size only
  finally
    LStream.Free;
    LDocument.Free;
  end;
end;

end.

