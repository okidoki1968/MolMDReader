program MolMDReader;

{$MODE Delphi}

uses
  SysUtils, Interfaces, Forms, fMain, uFileAssoc;

begin
  if (ParamCount >= 1) and SameText(ParamStr(1), '--register') then
  begin
    Halt(Ord(not RegisterMdAssociation(ParamStr(0))));
  end;
  if (ParamCount >= 1) and SameText(ParamStr(1), '--unregister') then
  begin
    Halt(Ord(not UnregisterMdAssociation));
  end;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
