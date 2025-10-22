program DxPdfViewer;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main.Form in 'Main.Form.pas' {Form48};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm48, Form48);
  Application.Run;
end.
