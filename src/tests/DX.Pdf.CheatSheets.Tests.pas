unit DX.Pdf.CheatSheets.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  DX.Pdf.Document;

type
  [TestFixture]
  TPdfCheatSheetsTests = class
  private
    FTestDataDir: string;
    FHttpClient: THTTPClient;
    
    function DownloadPdf(const AURL: string; const AFileName: string): Boolean;
    function GetCheatSheetUrls: TArray<string>;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure TestDownloadAndLoadCheatSheets;
  end;

implementation

uses
  System.IOUtils;

{ TPdfCheatSheetsTests }

procedure TPdfCheatSheetsTests.Setup;
begin
  // Create temporary directory for test PDFs
  FTestDataDir := TPath.Combine(TPath.GetTempPath, 'DX.Pdfium4D.CheatSheets');
  if not TDirectory.Exists(FTestDataDir) then
    TDirectory.CreateDirectory(FTestDataDir);
    
  FHttpClient := THTTPClient.Create;
  FHttpClient.UserAgent := 'DX.Pdfium4D Test Suite';
end;

procedure TPdfCheatSheetsTests.TearDown;
begin
  FHttpClient.Free;
  
  // Clean up downloaded PDFs
  if TDirectory.Exists(FTestDataDir) then
  begin
    try
      TDirectory.Delete(FTestDataDir, True);
    except
      // Ignore cleanup errors
    end;
  end;
end;

function TPdfCheatSheetsTests.GetCheatSheetUrls: TArray<string>;
begin
  // PDF Association Cheat Sheets (2nd edition)
  // These are publicly available educational resources
  // Source: https://pdfa.org/resource/pdf-cheat-sheets/

  Result := [
    'https://pdfa.org/download-area/cheat-sheets/Basics.pdf',
    'https://pdfa.org/download-area/cheat-sheets/Color.pdf',
    'https://pdfa.org/download-area/cheat-sheets/OperatorsAndOperands.pdf',
    'https://pdfa.org/download-area/cheat-sheets/Arlington.pdf',
    'https://pdfa.org/download-area/cheat-sheets/CommonObjects.pdf',
    'https://pdfa.org/download-area/cheat-sheets/LogicalStructureObjects.pdf',
    'https://pdfa.org/download-area/cheat-sheets/StructureAttributes.pdf',
    'https://pdfa.org/download-area/cheat-sheets/StandardStructureElements.pdf',
    'https://pdfa.org/download-area/cheat-sheets/Math.pdf',
    'https://pdfa.org/download-area/cheat-sheets/CheatSheetCollection.pdf'
  ];
end;

function TPdfCheatSheetsTests.DownloadPdf(const AURL: string; const AFileName: string): Boolean;
var
  LResponse: IHTTPResponse;
  LFileStream: TFileStream;
  LContentStream: TStream;
  LFilePath: string;
begin
  Result := False;
  LFilePath := TPath.Combine(FTestDataDir, AFileName);

  try
    WriteLn(Format('Downloading: %s', [AURL]));

    LResponse := FHttpClient.Get(AURL);

    if LResponse.StatusCode = 200 then
    begin
      LContentStream := LResponse.ContentStream;
      if (LContentStream <> nil) and (LContentStream.Size > 0) then
      begin
        LFileStream := TFileStream.Create(LFilePath, fmCreate);
        try
          LContentStream.Position := 0;
          LFileStream.CopyFrom(LContentStream, LContentStream.Size);
          WriteLn(Format('  -> Saved to: %s (%d bytes)', [AFileName, LFileStream.Size]));
          Result := True;
        finally
          LFileStream.Free;
        end;
      end
      else
      begin
        WriteLn('  -> Error: Empty response');
      end;
    end
    else
    begin
      WriteLn(Format('  -> HTTP Error: %d %s', [LResponse.StatusCode, LResponse.StatusText]));
    end;
  except
    on E: Exception do
    begin
      WriteLn(Format('  -> Download failed: %s', [E.Message]));
    end;
  end;
end;

procedure TPdfCheatSheetsTests.TestDownloadAndLoadCheatSheets;
var
  LUrls: TArray<string>;
  LURL: string;
  LFileName: string;
  LFilePath: string;
  LPdfDocument: TPdfDocument;
  LSuccessCount: Integer;
  LFailCount: Integer;
  LTotalCount: Integer;
begin
  LUrls := GetCheatSheetUrls;
  LSuccessCount := 0;
  LFailCount := 0;
  LTotalCount := Length(LUrls);
  
  WriteLn('');
  WriteLn('========================================');
  WriteLn('PDF Association Cheat Sheets Test');
  WriteLn('========================================');
  WriteLn(Format('Testing %d cheat sheets...', [LTotalCount]));
  WriteLn('');
  
  for LURL in LUrls do
  begin
    LFileName := TPath.GetFileName(LURL);
    
    // Download PDF
    if not DownloadPdf(LURL, LFileName) then
    begin
      Inc(LFailCount);
      Continue;
    end;

    // Try to load PDF
    LFilePath := TPath.Combine(FTestDataDir, LFileName);
    LPdfDocument := TPdfDocument.Create;
    try
      WriteLn(Format('  -> Loading PDF: %s', [LFileName]));

      try
        LPdfDocument.LoadFromFile(LFilePath);

        WriteLn(Format('  -> SUCCESS: Loaded %d pages', [LPdfDocument.PageCount]));

        Assert.IsTrue(LPdfDocument.PageCount > 0,
          Format('PDF should have at least one page: %s', [LFileName]));

        Inc(LSuccessCount);
      except
        on E: Exception do
        begin
          WriteLn(Format('  -> FAILED: %s', [E.Message]));
          Inc(LFailCount);
          Assert.Fail(Format('Failed to load PDF %s: %s', [LFileName, E.Message]));
        end;
      end;
    finally
      LPdfDocument.Free;
    end;

    WriteLn('');
  end;

  WriteLn('========================================');
  WriteLn(Format('Results: %d/%d successful, %d failed',
    [LSuccessCount, LTotalCount, LFailCount]));
  WriteLn('========================================');
  WriteLn('');

  Assert.AreEqual(LTotalCount, LSuccessCount,
    Format('All cheat sheets should load successfully. %d failed.', [LFailCount]));
end;

end.

