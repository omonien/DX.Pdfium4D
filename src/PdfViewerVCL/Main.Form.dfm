object MainForm: TMainForm
  Left = 0
  Top = 0
  Margins.Left = 6
  Margins.Top = 6
  Margins.Right = 6
  Margins.Bottom = 6
  Caption = 'DX PDF Viewer 1.1 (VCL)'
  ClientHeight = 1200
  ClientWidth = 1600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -24
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 192
  DesignSize = (
    1600
    1200)
  TextHeight = 32
  object StatusBar: TStatusBar
    Left = 0
    Top = 1162
    Width = 1600
    Height = 38
    Margins.Left = 6
    Margins.Top = 6
    Margins.Right = 6
    Margins.Bottom = 6
    Panels = <>
    SimplePanel = True
    SimpleText = 'No document loaded'
  end
  object DropPanel: TPanel
    Left = 400
    Top = 300
    Width = 800
    Height = 600
    Margins.Left = 6
    Margins.Top = 6
    Margins.Right = 6
    Margins.Bottom = 6
    Anchors = []
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Color = clWhite
    ParentBackground = False
    TabOrder = 1
    OnClick = DropPanelClick
    object DropLabel: TLabel
      AlignWithMargins = True
      Left = 40
      Top = 40
      Width = 716
      Height = 516
      Margins.Left = 40
      Margins.Top = 40
      Margins.Right = 40
      Margins.Bottom = 40
      Align = alClient
      Alignment = taCenter
      Caption = 
        'Drop PDF file here'#13#10#13#10'or'#13#10#13#10'Click to open file'#13#10#13#10'Keyboard Short' +
        'cuts:'#13#10'Arrow Keys / Page Up/Down: Navigate pages'#13#10'Home/End: Firs' +
        't/Last page'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -32
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      WordWrap = True
      OnClick = DropPanelClick
    end
  end
  object OpenDialog: TOpenDialog
    DefaultExt = 'pdf'
    Filter = 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Open PDF File'
    Left = 40
    Top = 40
  end
end
