{*******************************************************************************
  DX Pdfium4D Tests

  Unit tests for DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
program DxPdfium4dTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  DUnitX.FilterBuilder,
  DX.Pdf.API in '..\DX.Pdf.API.pas',
  DX.Pdf.Document in '..\DX.Pdf.Document.pas',
  DX.Pdf.Viewer.Core in '..\DX.Pdf.Viewer.Core.pas',
  {$IF not Defined(LINUX) or Defined(HAS_FMXLINUX)}
  // FMX is not part of the stock Delphi RTL on Linux. The viewer unit is
  // only pulled in here to keep it compile-checked alongside the core
  // binding. On Linux it is excluded by default; define HAS_FMXLINUX
  // (and make FMXLinux available on the Library Path) to include it.
  DX.Pdf.Viewer.FMX in '..\DX.Pdf.Viewer.FMX.pas',
  {$ENDIF}
  DX.Pdf.Document.Tests in 'DX.Pdf.Document.Tests.pas',
  DX.Pdf.CheatSheets.Tests in 'DX.Pdf.CheatSheets.Tests.pas',
  DX.Pdf.Extended.Tests in 'DX.Pdf.Extended.Tests.pas',
  DX.Pdf.ABI.Tests in 'DX.Pdf.ABI.Tests.pas',
  DX.Pdf.Selection.Tests in 'DX.Pdf.Selection.Tests.pas';

{$IFNDEF TESTINSIGHT}
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  LNUnitLogger : ITestLogger;
{$ENDIF}

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;

    // Tests in the category 'Network' need internet access and are opt-in.
    // They are excluded from the default run and only run when requested
    // explicitly: categories selected with --include (e.g. --include:Network),
    // tests selected by name with --run (e.g.
    // --run:DX.Pdf.CheatSheets.Tests), or the environment variable
    // DX_PDFIUM4D_NETWORK_TESTS set to 1.
    if (TDUnitX.Options.Include = '') and (TDUnitX.Options.Run.Count = 0) and
      (TDUnitX.Options.RunListFile = '') and
      (GetEnvironmentVariable('DX_PDFIUM4D_NETWORK_TESTS') <> '1') then
    begin
      if TDUnitX.Options.Exclude = '' then
        TDUnitX.Options.Exclude := 'Network'
      else
        TDUnitX.Options.Exclude := TDUnitX.Options.Exclude + ',Network';
      // CheckCommandLine has already built the filter, so rebuild it.
      TDUnitX.Filter := TDUnitXFilterBuilder.BuildFilter(TDUnitX.Options);
    end;

    // Create the test runner
    LRunner := TDUnitX.CreateRunner;

    // Tell the runner to use RTTI to find Fixtures
    LRunner.UseRTTI := True;

    // When true, Assertions must be made during tests
    LRunner.FailsOnNoAsserts := False;

    // Tell the runner how we will log things
    // Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      LLogger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      LRunner.AddLogger(LLogger);
    end;

    // Generate an NUnit compatible XML File
    LNUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNUnitLogger);

    // Run tests
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    // We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.

