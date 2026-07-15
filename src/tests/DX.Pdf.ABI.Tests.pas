{*******************************************************************************
  Unit: DX.Pdf.ABI.Tests

  Part of DX Pdfium4D - Delphi Cross-Platform Wrapper für Pdfium
  https://github.com/omonien/DX-Pdfium4D

  Description:
    Compile-time and runtime ABI guards for the PDFium binding types.
    PDFium declares 'unsigned long' for FPDF_DWORD, which is 32-bit on
    Windows (LLP64) and 32-bit POSIX, but 64-bit on 64-bit POSIX (LP64).
    These tests lock the layout down so a future refactor cannot silently
    re-introduce a 32-bit value on LP64 (issue #4 regression class).

  Author: Olaf Monien
  Copyright (c) 2025 Olaf Monien
  License: MIT - see LICENSE file
*******************************************************************************}
unit DX.Pdf.ABI.Tests;

interface

uses
  DUnitX.TestFramework,
  DX.Pdf.API;

{$M+}

type
  [TestFixture]
  TPdfABITests = class
  public
    [Test]
    procedure FPDF_DWORD_HasCorrectPlatformWidth;

    [Test]
    procedure FPDF_FILEACCESS_FieldsMatchPDFiumABI;

    [Test]
    procedure FPDF_LIBRARY_CONFIG_V8EmbedderSlotIs32Bit;
  end;

implementation

// Compile-time guards. If any of these fires, the unit will not compile -
// catching ABI breakage before tests even run.
{$IFDEF MSWINDOWS}
  {$IF SizeOf(FPDF_DWORD) <> 4}
    {$MESSAGE FATAL 'FPDF_DWORD must be 32-bit on Windows (LLP64)'}
  {$IFEND}
{$ELSE}
  {$IFDEF CPU64BITS}
    {$IF SizeOf(FPDF_DWORD) <> 8}
      {$MESSAGE FATAL 'FPDF_DWORD must be 64-bit on 64-bit POSIX (LP64)'}
    {$IFEND}
  {$ELSE}
    {$IF SizeOf(FPDF_DWORD) <> 4}
      {$MESSAGE FATAL 'FPDF_DWORD must be 32-bit on 32-bit POSIX'}
    {$IFEND}
  {$ENDIF}
{$ENDIF}

procedure TPdfABITests.FPDF_DWORD_HasCorrectPlatformWidth;
var
  LActual: Integer;
begin
  LActual := SizeOf(FPDF_DWORD);
{$IFDEF MSWINDOWS}
  Assert.AreEqual(4, LActual, 'FPDF_DWORD must be 32-bit on Windows');
{$ELSE}
  {$IFDEF CPU64BITS}
  Assert.AreEqual(8, LActual, 'FPDF_DWORD must be 64-bit on 64-bit POSIX (LP64)');
  {$ELSE}
  Assert.AreEqual(4, LActual, 'FPDF_DWORD must be 32-bit on 32-bit POSIX');
  {$ENDIF}
{$ENDIF}
end;

procedure TPdfABITests.FPDF_FILEACCESS_FieldsMatchPDFiumABI;
var
  LCallbackSize, LRecSize: Integer;
begin
  // The callback type must be pointer-sized (it's a procedural type).
  LCallbackSize := SizeOf(TFPDFFileAccessGetBlock);
  Assert.AreEqual(SizeOf(Pointer), LCallbackSize,
    'TFPDFFileAccessGetBlock must be a pointer-sized procedural type');

  // FPDF_FILEACCESS layout matches PDFium's C struct: m_FileLen (FPDF_DWORD)
  // + m_GetBlock (pointer) + m_Param (pointer), aligned to pointer boundary.
  // On Win64: 4 + 8 + 8 = 20, padded to 24.
  // On Win32: 4 + 4 + 4 = 12.
  // On POSIX64: 8 + 8 + 8 = 24.
  LRecSize := SizeOf(FPDF_FILEACCESS);
{$IFDEF MSWINDOWS}
  {$IFDEF WIN64}
  Assert.AreEqual(24, LRecSize, 'FPDF_FILEACCESS size on Win64');
  {$ELSE}
  Assert.AreEqual(12, LRecSize, 'FPDF_FILEACCESS size on Win32');
  {$ENDIF}
{$ELSE}
  {$IFDEF CPU64BITS}
  Assert.AreEqual(24, LRecSize, 'FPDF_FILEACCESS size on 64-bit POSIX');
  {$ELSE}
  Assert.AreEqual(12, LRecSize, 'FPDF_FILEACCESS size on 32-bit POSIX');
  {$ENDIF}
{$ENDIF}
end;

procedure TPdfABITests.FPDF_LIBRARY_CONFIG_V8EmbedderSlotIs32Bit;
var
  LCfg: FPDF_LIBRARY_CONFIG;
  LActual: Integer;
begin
  LActual := SizeOf(LCfg.V8EmbedderSlot);
  // Silence H2164: SizeOf on a field reference doesn't count as use.
  LCfg := Default(FPDF_LIBRARY_CONFIG);

  // V8EmbedderSlot is C 'unsigned int' - always 32-bit on every supported
  // platform, NOT 'unsigned long'. Must NOT track FPDF_DWORD on LP64.
  Assert.AreEqual(4, LActual,
    'FPDF_LIBRARY_CONFIG.V8EmbedderSlot must be 32-bit on every platform');
end;

initialization
  TDUnitX.RegisterTestFixture(TPdfABITests);

end.
