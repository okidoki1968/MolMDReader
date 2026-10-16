program MolMDReader;

{$MODE Delphi}

uses
  Interfaces, Forms, fMain;

begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
