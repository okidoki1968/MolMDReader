unit uMdPrepare;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, StrUtils, uFileTree;

type
  TLinkKind = (lkExternal, lkMarkdown, lkAnchor, lkBlocked);

const
  MaxMdFileBytes = 5 * 1024 * 1024;

function ReadMdFile(const Path: string): string;
function StripFrontmatter(const Text: string): string;
function ConvertWikiLinks(const Text, BaseDir, RootDir: string): string;
function ClassifyLink(const Href, BaseDir: string; out ResolvedPath: string): TLinkKind;
function FindMdByName(const Dir, FileName: string): string;
function UrlEncodePath(const S: string): string;
function PercentDecode(const S: string): string;

implementation

function SanitizeUtf8(const Raw: string): string;
var
  I, N, Len, J: Integer;
  B: Byte;
begin
  Result := '';
  Len := Length(Raw);
  SetLength(Result, 0);
  I := 1;
  while I <= Len do
  begin
    B := Byte(Raw[I]);
    if B < $80 then
      N := 1
    else if (B >= $C2) and (B <= $DF) then
      N := 2
    else if (B >= $E0) and (B <= $EF) then
      N := 3
    else if (B >= $F0) and (B <= $F4) then
      N := 4
    else
      N := 0;
    if (N > 0) and (I + N - 1 <= Len) then
    begin
      for J := 1 to N - 1 do
        if (Byte(Raw[I + J]) and $C0) <> $80 then
        begin
          N := 0;
          Break;
        end;
    end
    else
      N := 0;
    if N > 0 then
    begin
      Result := Result + Copy(Raw, I, N);
      Inc(I, N);
    end
    else
    begin
      Result := Result + #$EF#$BF#$BD;
      Inc(I);
    end;
  end;
end;

function ReadMdFile(const Path: string): string;
var
  FS: TFileStream;
  Raw: string;
  Count: Int64;
  Truncated: Boolean;
begin
  Result := '';
  try
    FS := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      Count := FS.Size;
      Truncated := Count > MaxMdFileBytes;
      if Truncated then
        Count := MaxMdFileBytes;
      SetLength(Raw, Count);
      if Count > 0 then
        FS.ReadBuffer(Raw[1], Count);
    finally
      FS.Free;
    end;
  except
    Exit;
  end;
  if (Length(Raw) >= 3) and (Raw[1] = #$EF) and (Raw[2] = #$BB) and (Raw[3] = #$BF) then
    Delete(Raw, 1, 3);
  Result := SanitizeUtf8(Raw);
  if Truncated then
    Result := Result + #10#10 + '*(bestand ingekort)*';
end;

function StripFrontmatter(const Text: string): string;
var
  P, LineEnd: Integer;
  Line: string;
begin
  Result := Text;
  if Copy(Text, 1, 3) <> '---' then
    Exit;
  P := 4;
  if Copy(Text, P, 2) = #13#10 then
    Inc(P, 2)
  else if Copy(Text, P, 1) = #10 then
    Inc(P)
  else
    Exit;
  while P <= Length(Text) do
  begin
    LineEnd := P;
    while (LineEnd <= Length(Text)) and (Text[LineEnd] <> #10) do
      Inc(LineEnd);
    Line := TrimRight(Copy(Text, P, LineEnd - P));
    if Line = '---' then
    begin
      Result := Copy(Text, LineEnd + 1, MaxInt);
      Exit;
    end;
    P := LineEnd + 1;
  end;
end;

function PercentDecode(const S: string): string;
var
  I, V: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I + 2 <= Length(S)) then
    begin
      V := StrToIntDef('$' + Copy(S, I + 1, 2), -1);
      if V >= 0 then
      begin
        Result := Result + Chr(V);
        Inc(I, 3);
        Continue;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

function UrlEncodePath(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '/'] then
      Result := Result + C
    else
      Result := Result + '%' + IntToHex(Ord(C), 2);
  end;
end;

function FindMdByName(const Dir, FileName: string): string;
var
  SR: TSearchRec;
  Sub: string;
begin
  Result := '';
  if FileExists(Dir + '\' + FileName) then
    Exit(Dir + '\' + FileName);
  if FindFirst(Dir + '\*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if ((SR.Attr and faDirectory) = 0) or IsLinkedDir(SR) then
        Continue;
      Sub := FindMdByName(Dir + '\' + SR.Name, FileName);
      if Sub <> '' then
        Exit(Sub);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

type
  TWikiResolver = class
  private
    FBaseDir, FRootDir: string;
    FNames: TStringList;
    FPaths: TStringList;
    FBuilt: Boolean;
    procedure Collect(const Dir: string);
    procedure Build;
  public
    constructor Create(const ABaseDir, ARootDir: string);
    destructor Destroy; override;
    function Resolve(const Target: string): string;
  end;

constructor TWikiResolver.Create(const ABaseDir, ARootDir: string);
begin
  inherited Create;
  FBaseDir := ExcludeTrailingPathDelimiter(ABaseDir);
  FRootDir := ExcludeTrailingPathDelimiter(ARootDir);
  FNames := TStringList.Create;
  FNames.Sorted := True;
  FNames.CaseSensitive := False;
  FNames.Duplicates := dupIgnore;
  FPaths := TStringList.Create;
end;

destructor TWikiResolver.Destroy;
begin
  FNames.Free;
  FPaths.Free;
  inherited;
end;

procedure TWikiResolver.Collect(const Dir: string);
var
  SR: TSearchRec;
  Idx: Integer;
begin
  if FindFirst(Dir + '\*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if not IsLinkedDir(SR) then
          Collect(Dir + '\' + SR.Name);
      end
      else if IsMdFileName(SR.Name) then
      begin
        if not FNames.Find(SR.Name, Idx) then
        begin
          FPaths.Add(Dir + '\' + SR.Name);
          FNames.AddObject(SR.Name, TObject(PtrInt(FPaths.Count - 1)));
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TWikiResolver.Build;
begin
  FBuilt := True;
  Collect(FBaseDir);
  if not SameText(FBaseDir, FRootDir) then
    Collect(FRootDir);
end;

function TWikiResolver.Resolve(const Target: string): string;
var
  Idx: Integer;
begin
  Result := '';
  if Target = '' then
    Exit;
  if FileExists(FBaseDir + '\' + Target + '.md') then
    Exit(FBaseDir + '\' + Target + '.md');
  if not FBuilt then
    Build;
  if FNames.Find(Target + '.md', Idx) then
    Result := FPaths[PtrInt(FNames.Objects[Idx])];
end;

function ConvertWikiLine(const Line: string; Resolver: TWikiResolver; const BaseDir: string): string;
var
  I, Close, Bar, Hash, Slash: Integer;
  InCode: Boolean;
  Inner, Target, Caption, Found, Rel: string;
begin
  Result := '';
  InCode := False;
  I := 1;
  while I <= Length(Line) do
  begin
    if Line[I] = '`' then
      InCode := not InCode;
    if (not InCode) and (Line[I] = '[') and (Copy(Line, I, 2) = '[[') then
    begin
      Close := PosEx(']]', Line, I + 2);
      if Close > 0 then
      begin
        Inner := Copy(Line, I + 2, Close - I - 2);
        Bar := Pos('|', Inner);
        if Bar > 0 then
        begin
          Target := Copy(Inner, 1, Bar - 1);
          Caption := Copy(Inner, Bar + 1, MaxInt);
        end
        else
        begin
          Target := Inner;
          Caption := Inner;
        end;
        Hash := Pos('#', Target);
        if Hash > 0 then
          Target := Copy(Target, 1, Hash - 1);
        Slash := LastDelimiter('/\', Target);
        if Slash > 0 then
          Target := Copy(Target, Slash + 1, MaxInt);
        Found := Resolver.Resolve(Target);
        if Found = '' then
          Result := Result + '[' + Caption + '](#niet-gevonden)'
        else
        begin
          Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(BaseDir), Found);
          Rel := StringReplace(Rel, '\', '/', [rfReplaceAll]);
          Result := Result + '[' + Caption + '](' + UrlEncodePath(Rel) + ')';
        end;
        I := Close + 2;
        Continue;
      end;
    end;
    Result := Result + Line[I];
    Inc(I);
  end;
end;

function ConvertWikiLinks(const Text, BaseDir, RootDir: string): string;
var
  Lines: TStringList;
  Resolver: TWikiResolver;
  I: Integer;
  InFence: Boolean;
  T: string;
begin
  if Pos('[[', Text) = 0 then
    Exit(Text);
  Lines := TStringList.Create;
  Resolver := TWikiResolver.Create(BaseDir, RootDir);
  try
    Lines.LineBreak := #10;
    Lines.TextLineBreakStyle := tlbsLF;
    Lines.Text := Text;
    InFence := False;
    for I := 0 to Lines.Count - 1 do
    begin
      T := TrimLeft(Lines[I]);
      if (Copy(T, 1, 3) = '```') or (Copy(T, 1, 3) = '~~~') then
        InFence := not InFence
      else if not InFence then
        Lines[I] := ConvertWikiLine(Lines[I], Resolver, BaseDir);
    end;
    Result := Lines.Text;
    if (Text <> '') and (Text[Length(Text)] <> #10) and (Result <> '') and (Result[Length(Result)] = #10) then
      SetLength(Result, Length(Result) - 1);
  finally
    Resolver.Free;
    Lines.Free;
  end;
end;

function ClassifyLink(const Href, BaseDir: string; out ResolvedPath: string): TLinkKind;
var
  H, PathPart: string;
  I: Integer;
begin
  ResolvedPath := '';
  H := Trim(Href);
  if (LowerCase(Copy(H, 1, 7)) = 'http://') or (LowerCase(Copy(H, 1, 8)) = 'https://') then
    Exit(lkExternal);
  if Copy(H, 1, 1) = '#' then
    Exit(lkAnchor);
  PathPart := H;
  I := Pos('#', PathPart);
  if I > 0 then
    PathPart := Copy(PathPart, 1, I - 1);
  I := Pos('?', PathPart);
  if I > 0 then
    PathPart := Copy(PathPart, 1, I - 1);
  PathPart := PercentDecode(PathPart);
  if Pos(':', PathPart) > 0 then
    Exit(lkBlocked);
  PathPart := StringReplace(PathPart, '/', '\', [rfReplaceAll]);
  if not SameText(ExtractFileExt(PathPart), '.md') then
    Exit(lkBlocked);
  PathPart := ExpandFileName(IncludeTrailingPathDelimiter(BaseDir) + PathPart);
  if not FileExists(PathPart) then
    Exit(lkBlocked);
  ResolvedPath := PathPart;
  Result := lkMarkdown;
end;

end.
