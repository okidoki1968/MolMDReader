unit uTestFileTree;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uFileTree;

type
  TTestFileTree = class(TTestCase)
  private
    FRoot: string;
    procedure Touch(const RelPath: string);
    function Names(Node: TMdNode): string;
    procedure RemoveTree(const Dir: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestOnlyMdFilesAndNeededFolders;
    procedure TestSortOrderFoldersFirst;
    procedure TestMissingRootGivesEmptyNode;
    procedure TestDoesNotFollowJunctionLoop;
    procedure TestCountMdFiles;
  end;

implementation

procedure TTestFileTree.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'molmd-tree-' + IntToStr(GetTickCount64);
  ForceDirectories(FRoot);
end;

procedure TTestFileTree.RemoveTree(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '\*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faSymLink) <> 0 then
        RemoveDir(Dir + '\' + SR.Name)
      else if (SR.Attr and faDirectory) <> 0 then
        RemoveTree(Dir + '\' + SR.Name)
      else
        DeleteFile(Dir + '\' + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(Dir);
end;

procedure TTestFileTree.TearDown;
begin
  RemoveTree(FRoot);
end;

procedure TTestFileTree.Touch(const RelPath: string);
var
  F: TStringList;
  P: string;
begin
  P := FRoot + '\' + RelPath;
  ForceDirectories(ExtractFileDir(P));
  F := TStringList.Create;
  try
    F.SaveToFile(P);
  finally
    F.Free;
  end;
end;

function TTestFileTree.Names(Node: TMdNode): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Node.Children.Count - 1 do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + TMdNode(Node.Children[I]).Name;
  end;
end;

procedure TTestFileTree.TestOnlyMdFilesAndNeededFolders;
var
  N: TMdNode;
begin
  Touch('a.md');
  Touch('notes.txt');
  Touch('Docs\b.md');
  Touch('Leeg\x.txt');
  ForceDirectories(FRoot + '\HelemaalLeeg');
  N := ScanMdTree(FRoot);
  try
    AssertEquals('Docs,a.md', Names(N));
  finally
    N.Free;
  end;
end;

procedure TTestFileTree.TestSortOrderFoldersFirst;
var
  N: TMdNode;
begin
  Touch('b.md');
  Touch('A.md');
  Touch('zmap\1.md');
  Touch('Amap\1.md');
  N := ScanMdTree(FRoot);
  try
    AssertEquals('Amap,zmap,A.md,b.md', Names(N));
  finally
    N.Free;
  end;
end;

procedure TTestFileTree.TestMissingRootGivesEmptyNode;
var
  N: TMdNode;
begin
  N := ScanMdTree(FRoot + '\bestaatniet');
  try
    AssertTrue(N.IsDir);
    AssertEquals(0, N.Children.Count);
  finally
    N.Free;
  end;
end;

procedure TTestFileTree.TestDoesNotFollowJunctionLoop;
var
  N: TMdNode;
begin
  Touch('Sub\a.md');
  ExecuteProcess('cmd.exe', '/c mklink /J "' + FRoot + '\Sub\lus" "' + FRoot + '"');
  N := ScanMdTree(FRoot);
  try
    AssertEquals(1, CountMdFiles(N));
  finally
    N.Free;
  end;
end;

procedure TTestFileTree.TestCountMdFiles;
var
  N: TMdNode;
begin
  Touch('a.md');
  Touch('x\b.md');
  Touch('x\y\c.MD');
  N := ScanMdTree(FRoot);
  try
    AssertEquals(3, CountMdFiles(N));
  finally
    N.Free;
  end;
end;

initialization
  RegisterTest(TTestFileTree);

end.
