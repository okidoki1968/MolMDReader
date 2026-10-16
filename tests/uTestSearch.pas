unit uTestSearch;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uSearch;

type
  TTestSearch = class(TTestCase)
  private
    FRoot: string;
    FDone: Boolean;
    FHits: TSearchHitArray;
    procedure WriteFile(const RelPath, Content: string);
    procedure RemoveTree(const Dir: string);
    procedure OnSearchDone(const Hits: TSearchHitArray);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNameMatch;
    procedure TestContentMatchHasLineAndSnippet;
    procedure TestCaseInsensitive;
    procedure TestSubfoldersIncluded;
    procedure TestEmptyQueryNoHits;
    procedure TestCancelStopsEarly;
    procedure TestUnreadableFileSkipped;
    procedure TestThreadDeliversHits;
  end;

implementation

procedure TTestSearch.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'molmd-search-' + IntToStr(GetTickCount64);
  ForceDirectories(FRoot);
  FDone := False;
end;

procedure TTestSearch.RemoveTree(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '\*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        RemoveTree(Dir + '\' + SR.Name)
      else
        DeleteFile(Dir + '\' + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(Dir);
end;

procedure TTestSearch.TearDown;
begin
  RemoveTree(FRoot);
end;

procedure TTestSearch.WriteFile(const RelPath, Content: string);
var
  L: TStringList;
  P: string;
begin
  P := FRoot + '\' + RelPath;
  ForceDirectories(ExtractFileDir(P));
  L := TStringList.Create;
  try
    L.Text := Content;
    L.SaveToFile(P);
  finally
    L.Free;
  end;
end;

procedure TTestSearch.OnSearchDone(const Hits: TSearchHitArray);
begin
  FHits := Hits;
  FDone := True;
end;

procedure TTestSearch.TestNameMatch;
var
  H: TSearchHitArray;
begin
  WriteFile('Planning.md', 'niets');
  H := SearchFolder(FRoot, 'plan', nil);
  AssertEquals(1, Length(H));
  AssertTrue(H[0].NameMatch);
  AssertEquals(FRoot + '\Planning.md', H[0].FilePath);
end;

procedure TTestSearch.TestContentMatchHasLineAndSnippet;
var
  H: TSearchHitArray;
begin
  WriteFile('a.md', 'eerste regel' + #10 + 'hier staat Wortel in' + #10 + 'laatste');
  H := SearchFolder(FRoot, 'wortel', nil);
  AssertEquals(1, Length(H));
  AssertFalse(H[0].NameMatch);
  AssertEquals(2, H[0].Line);
  AssertEquals('hier staat Wortel in', H[0].Snippet);
end;

procedure TTestSearch.TestCaseInsensitive;
var
  H: TSearchHitArray;
begin
  WriteFile('a.md', 'CAF' + #$C3#$89);
  H := SearchFolder(FRoot, 'caf' + #$C3#$A9, nil);
  AssertEquals(1, Length(H));
end;

procedure TTestSearch.TestSubfoldersIncluded;
var
  H: TSearchHitArray;
begin
  WriteFile('x\y\diep.md', 'zoekwoord');
  H := SearchFolder(FRoot, 'zoekwoord', nil);
  AssertEquals(1, Length(H));
end;

procedure TTestSearch.TestEmptyQueryNoHits;
begin
  WriteFile('a.md', 'tekst');
  AssertEquals(0, Length(SearchFolder(FRoot, '', nil)));
  AssertEquals(0, Length(SearchFolder(FRoot, '   ', nil)));
end;

procedure TTestSearch.TestCancelStopsEarly;
var
  C: Boolean;
begin
  WriteFile('a.md', 'tekst');
  C := True;
  AssertEquals(0, Length(SearchFolder(FRoot, 'tekst', @C)));
end;

procedure TTestSearch.TestUnreadableFileSkipped;
var
  FS: TFileStream;
  H: TSearchHitArray;
begin
  WriteFile('goed.md', 'zoek');
  FS := TFileStream.Create(FRoot + '\vergrendeld.md', fmCreate or fmShareExclusive);
  try
    H := SearchFolder(FRoot, 'zoek', nil);
    AssertEquals(1, Length(H));
  finally
    FS.Free;
  end;
end;

procedure TTestSearch.TestThreadDeliversHits;
var
  T: TSearchThread;
  Waited: Integer;
begin
  WriteFile('a.md', 'draadtest');
  T := TSearchThread.Create(FRoot, 'draadtest', OnSearchDone);
  Waited := 0;
  while (not FDone) and (Waited < 5000) do
  begin
    CheckSynchronize(20);
    Inc(Waited, 20);
  end;
  AssertTrue('klaar binnen 5 s', FDone);
  AssertEquals(1, Length(FHits));
end;

initialization
  RegisterTest(TTestSearch);

end.
