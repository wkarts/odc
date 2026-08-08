program OdcStudio;

uses
  Vcl.Forms,
  OdcStudioMain in 'OdcStudioMain.pas',
  OdcContainer in '..\OdcContainer.pas';


begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'ODC Studio Delphi';
  Application.CreateForm(TOdcStudioForm, OdcStudioForm);
  Application.Run;
end.
