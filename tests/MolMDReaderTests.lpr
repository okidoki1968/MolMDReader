program MolMDReaderTests;

{$MODE Delphi}

uses
  Classes, consoletestrunner,
  uTestSettings, uTestFileTree, uTestNavHistory;

type
  TMyRunner = class(TTestRunner)
  end;

var
  App: TMyRunner;

begin
  App := TMyRunner.Create(nil);
  App.Initialize;
  App.Title := 'MolMDReader tests';
  App.Run;
  App.Free;
end.
