unit uTestNavHistory;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uNavHistory;

type
  TTestNavHistory = class(TTestCase)
  published
    procedure TestBackForward;
    procedure TestVisitClearsForward;
    procedure TestSameFileTwiceIgnored;
    procedure TestEmptyHistory;
  end;

implementation

procedure TTestNavHistory.TestBackForward;
var
  H: TNavHistory;
begin
  H := TNavHistory.Create;
  try
    H.Visit('a.md');
    H.Visit('b.md');
    H.Visit('c.md');
    AssertEquals('c.md', H.Current);
    AssertEquals('b.md', H.Back);
    AssertEquals('a.md', H.Back);
    AssertFalse(H.CanBack);
    AssertTrue(H.CanForward);
    AssertEquals('b.md', H.Forward);
    AssertEquals('b.md', H.Current);
  finally
    H.Free;
  end;
end;

procedure TTestNavHistory.TestVisitClearsForward;
var
  H: TNavHistory;
begin
  H := TNavHistory.Create;
  try
    H.Visit('a.md');
    H.Visit('b.md');
    H.Back;
    H.Visit('c.md');
    AssertFalse(H.CanForward);
    AssertEquals('a.md', H.Back);
  finally
    H.Free;
  end;
end;

procedure TTestNavHistory.TestSameFileTwiceIgnored;
var
  H: TNavHistory;
begin
  H := TNavHistory.Create;
  try
    H.Visit('a.md');
    H.Visit('a.md');
    AssertFalse(H.CanBack);
  finally
    H.Free;
  end;
end;

procedure TTestNavHistory.TestEmptyHistory;
var
  H: TNavHistory;
begin
  H := TNavHistory.Create;
  try
    AssertFalse(H.CanBack);
    AssertFalse(H.CanForward);
    AssertEquals('', H.Current);
    AssertEquals('', H.Back);
    AssertEquals('', H.Forward);
  finally
    H.Free;
  end;
end;

initialization
  RegisterTest(TTestNavHistory);

end.
