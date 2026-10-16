unit uFileTree;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, contnrs;

type
  TMdNode = class
  public
    Name: string;
    FullPath: string;
    IsDir: Boolean;
    Children: TObjectList;
    constructor Create(const AName, AFullPath: string; AIsDir: Boolean);
    destructor Destroy; override;
  end;

function ScanMdTree(const Root: string): TMdNode;
function CountMdFiles(Node: TMdNode): Integer;
function IsMdFileName(const Name: string): Boolean;

implementation

constructor TMdNode.Create(const AName, AFullPath: string; AIsDir: Boolean);
begin
  inherited Create;
  Name := AName;
  FullPath := AFullPath;
  IsDir := AIsDir;
  Children := TObjectList.Create(True);
end;

destructor TMdNode.Destroy;
begin
  Children.Free;
  inherited;
end;

function IsMdFileName(const Name: string): Boolean;
begin
  Result := SameText(ExtractFileExt(Name), '.md');
end;

function NodeCompare(A, B: Pointer): Integer;
var
  NA, NB: TMdNode;
begin
  NA := TMdNode(A);
  NB := TMdNode(B);
  if NA.IsDir <> NB.IsDir then
  begin
    if NA.IsDir then
      Result := -1
    else
      Result := 1;
  end
  else
    Result := CompareText(NA.Name, NB.Name);
end;

procedure ScanInto(Node: TMdNode);
var
  SR: TSearchRec;
  Child: TMdNode;
  Path: string;
begin
  if FindFirst(Node.FullPath + '\*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      Path := Node.FullPath + '\' + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if (SR.Attr and faSymLink) <> 0 then
          Continue;
        Child := TMdNode.Create(SR.Name, Path, True);
        ScanInto(Child);
        if Child.Children.Count > 0 then
          Node.Children.Add(Child)
        else
          Child.Free;
      end
      else if IsMdFileName(SR.Name) then
        Node.Children.Add(TMdNode.Create(SR.Name, Path, False));
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Node.Children.Sort(NodeCompare);
end;

function ScanMdTree(const Root: string): TMdNode;
begin
  Result := TMdNode.Create(ExtractFileName(ExcludeTrailingPathDelimiter(Root)),
    ExcludeTrailingPathDelimiter(Root), True);
  ScanInto(Result);
end;

function CountMdFiles(Node: TMdNode): Integer;
var
  I: Integer;
begin
  if not Node.IsDir then
    Exit(1);
  Result := 0;
  for I := 0 to Node.Children.Count - 1 do
    Inc(Result, CountMdFiles(TMdNode(Node.Children[I])));
end;

end.
