program MolMDReaderTests;

{$MODE Delphi}

uses
  Classes, LazUTF8, consoletestrunner,
  uTestSettings, uTestFileTree, uTestNavHistory, uTestMdPrepare, uTestSearch;

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
