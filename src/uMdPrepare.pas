unit uMdPrepare;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, httpprotocol;

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
      if ((SR.Attr and faDirectory) = 0) or ((SR.Attr and faSymLink) <> 0) then
        Continue;
      Sub := FindMdByName(Dir + '\' + SR.Name, FileName);
      if Sub <> '' then
        Exit(Sub);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function ConvertWikiLinks(const Text, BaseDir, RootDir: string): string;
var
  P, Q: Integer;
  Inner, Target, Caption, Found, Rel: string;
  Bar, Hash, Slash: Integer;
begin
  Result := '';
  P := 1;
  while P <= Length(Text) do
  begin
    Q := Pos('[[', Copy(Text, P, MaxInt));
    if Q = 0 then
    begin
      Result := Result + Copy(Text, P, MaxInt);
      Break;
    end;
    Q := P + Q - 1;
    Result := Result + Copy(Text, P, Q - P);
    P := Pos(']]', Copy(Text, Q + 2, MaxInt));
    if P = 0 then
    begin
      Result := Result + Copy(Text, Q, MaxInt);
      Break;
    end;
    P := Q + 2 + P - 1;
    Inner := Copy(Text, Q + 2, P - Q - 2);
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
    Found := '';
    if Target <> '' then
    begin
      Found := FindMdByName(ExcludeTrailingPathDelimiter(BaseDir), Target + '.md');
      if (Found = '') and not SameText(BaseDir, RootDir) then
        Found := FindMdByName(ExcludeTrailingPathDelimiter(RootDir), Target + '.md');
    end;
    if Found = '' then
      Result := Result + '[' + Caption + '](#niet-gevonden)'
    else
    begin
      Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(BaseDir), Found);
      Rel := StringReplace(Rel, '\', '/', [rfReplaceAll]);
      Result := Result + '[' + Caption + '](' + UrlEncodePath(Rel) + ')';
    end;
    P := P + 2;
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
  PathPart := HTTPDecode(PathPart);
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
