unit uSearch;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, LazUTF8, uMdPrepare, uFileTree;

const
  MaxSearchHits = 500;
  MaxSnippetChars = 160;

type
  TSearchHit = record
    FilePath: string;
    Line: Integer;
    Snippet: string;
    NameMatch: Boolean;
  end;

  TSearchHitArray = array of TSearchHit;

  TSearchDoneEvent = procedure(const Hits: TSearchHitArray) of object;

  TSearchThread = class(TThread)
  private
    FDir, FQuery: string;
    FOnDone: TSearchDoneEvent;
    FCancel: Boolean;
    FHits: TSearchHitArray;
    procedure Deliver;
  protected
    procedure Execute; override;
  public
    constructor Create(const ADir, AQuery: string; AOnDone: TSearchDoneEvent);
    procedure Cancel;
  end;

function SearchFolder(const Dir, Query: string; Cancel: PBoolean): TSearchHitArray;

implementation

function IsCancelled(Cancel: PBoolean): Boolean;
begin
  Result := (Cancel <> nil) and Cancel^;
end;

procedure AddHit(var Hits: TSearchHitArray; const Path: string; Line: Integer;
  const Snippet: string; NameMatch: Boolean);
var
  N: Integer;
begin
  N := Length(Hits);
  SetLength(Hits, N + 1);
  Hits[N].FilePath := Path;
  Hits[N].Line := Line;
  Hits[N].Snippet := Snippet;
  Hits[N].NameMatch := NameMatch;
end;

procedure SearchFile(const Path, LowerQuery: string; var Hits: TSearchHitArray; Cancel: PBoolean);
var
  Text: string;
  L: TStringList;
  I: Integer;
  Line: string;
begin
  if UTF8Pos(LowerQuery, UTF8LowerCase(ExtractFileName(Path))) > 0 then
    AddHit(Hits, Path, 0, '', True);
  Text := ReadMdFile(Path);
  if Text = '' then
    Exit;
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
    begin
      if IsCancelled(Cancel) or (Length(Hits) >= MaxSearchHits) then
        Exit;
      Line := L[I];
      if UTF8Pos(LowerQuery, UTF8LowerCase(Line)) > 0 then
        AddHit(Hits, Path, I + 1, UTF8Copy(Trim(Line), 1, MaxSnippetChars), False);
    end;
  finally
    L.Free;
  end;
end;

procedure SearchDir(const Dir, LowerQuery: string; var Hits: TSearchHitArray; Cancel: PBoolean);
var
  SR: TSearchRec;
  Names: TStringList;
  I: Integer;
begin
  Names := TStringList.Create;
  try
    if FindFirst(Dir + '\*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name = '.') or (SR.Name = '..') then
            Continue;
          if (SR.Attr and faDirectory) <> 0 then
          begin
            if not IsLinkedDir(SR) then
              Names.AddObject(SR.Name, TObject(PtrInt(1)));
          end
          else if IsMdFileName(SR.Name) then
            Names.AddObject(SR.Name, TObject(PtrInt(0)));
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    Names.Sort;
    for I := 0 to Names.Count - 1 do
    begin
      if IsCancelled(Cancel) or (Length(Hits) >= MaxSearchHits) then
        Exit;
      if PtrInt(Names.Objects[I]) = 1 then
        SearchDir(Dir + '\' + Names[I], LowerQuery, Hits, Cancel)
      else
        try
          SearchFile(Dir + '\' + Names[I], LowerQuery, Hits, Cancel);
        except
          // onleesbaar bestand overslaan
        end;
    end;
  finally
    Names.Free;
  end;
end;

function SearchFolder(const Dir, Query: string; Cancel: PBoolean): TSearchHitArray;
var
  Q: string;
begin
  Result := nil;
  Q := Trim(Query);
  if Q = '' then
    Exit;
  SearchDir(ExcludeTrailingPathDelimiter(Dir), UTF8LowerCase(Q), Result, Cancel);
end;

{ TSearchThread }

constructor TSearchThread.Create(const ADir, AQuery: string; AOnDone: TSearchDoneEvent);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FDir := ADir;
  FQuery := AQuery;
  FOnDone := AOnDone;
end;

procedure TSearchThread.Cancel;
begin
  FCancel := True;
end;

procedure TSearchThread.Deliver;
begin
  if (not FCancel) and Assigned(FOnDone) then
    FOnDone(FHits);
end;

procedure TSearchThread.Execute;
begin
  try
    FHits := SearchFolder(FDir, FQuery, @FCancel);
  except
    SetLength(FHits, 0);
  end;
  if not FCancel then
    Synchronize(Deliver);
end;

end.
