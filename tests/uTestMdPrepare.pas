unit uTestMdPrepare;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uMdPrepare;

type
  TTestMdPrepare = class(TTestCase)
  private
    FRoot: string;
    procedure WriteBytes(const RelPath: string; const Bytes: array of Byte; Count: Integer = -1);
    procedure Touch(const RelPath: string);
    procedure RemoveTree(const Dir: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestReadBomAndInvalidUtf8;
    procedure TestReadLargeFileTruncates;
    procedure TestStripFrontmatter;
    procedure TestWikiLinkPlainAndAlias;
    procedure TestWikiLinkMissingTarget;
    procedure TestClassifyExternal;
    procedure TestClassifyMdWithSpacesAndAnchor;
    procedure TestClassifyUnicodeFileName;
    procedure TestClassifyUnknownExtensionBlocked;
    procedure TestClassifyMissingMdBlocked;
  end;

implementation

procedure TTestMdPrepare.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'molmd-prep-' + IntToStr(GetTickCount64);
  ForceDirectories(FRoot);
end;

procedure TTestMdPrepare.RemoveTree(const Dir: string);
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

procedure TTestMdPrepare.TearDown;
begin
  RemoveTree(FRoot);
end;

procedure TTestMdPrepare.WriteBytes(const RelPath: string; const Bytes: array of Byte; Count: Integer);
var
  FS: TFileStream;
  P: string;
begin
  P := FRoot + '\' + RelPath;
  ForceDirectories(ExtractFileDir(P));
  FS := TFileStream.Create(P, fmCreate);
  try
    if Count < 0 then
      Count := Length(Bytes);
    if Count > 0 then
      FS.WriteBuffer(Bytes[0], Count);
  finally
    FS.Free;
  end;
end;

procedure TTestMdPrepare.Touch(const RelPath: string);
begin
  WriteBytes(RelPath, [Ord('x')]);
end;

procedure TTestMdPrepare.TestReadBomAndInvalidUtf8;
var
  S: string;
begin
  WriteBytes('bom.md', [$EF, $BB, $BF, Ord('H'), Ord('i')]);
  AssertEquals('Hi', ReadMdFile(FRoot + '\bom.md'));
  WriteBytes('bad.md', [Ord('A'), $FF, $FE, Ord('B')]);
  S := ReadMdFile(FRoot + '\bad.md');
  AssertTrue('begin en eind blijven', (Pos('A', S) = 1) and (Pos('B', S) > 1));
  AssertEquals('', ReadMdFile(FRoot + '\bestaatniet.md'));
end;

procedure TTestMdPrepare.TestReadLargeFileTruncates;
var
  FS: TFileStream;
  Buf: array[0..65535] of Byte;
  I: Integer;
  S: string;
begin
  FillChar(Buf, SizeOf(Buf), Ord('a'));
  FS := TFileStream.Create(FRoot + '\groot.md', fmCreate);
  try
    for I := 1 to 100 do // 6,5 MB
      FS.WriteBuffer(Buf, SizeOf(Buf));
  finally
    FS.Free;
  end;
  S := ReadMdFile(FRoot + '\groot.md');
  AssertTrue('ingekort', Length(S) < 5 * 1024 * 1024 + 200);
  AssertTrue('melding aanwezig', Pos('(bestand ingekort)', S) > 0);
end;

procedure TTestMdPrepare.TestStripFrontmatter;
begin
  AssertEquals('Tekst', StripFrontmatter('---'#10'title: x'#10'---'#10'Tekst'));
  AssertEquals('Tekst', StripFrontmatter('---'#13#10'title: x'#13#10'---'#13#10'Tekst'));
  AssertEquals('Tekst', StripFrontmatter('Tekst'));
  AssertEquals('---'#10'niet afgesloten', StripFrontmatter('---'#10'niet afgesloten'));
end;

procedure TTestMdPrepare.TestWikiLinkPlainAndAlias;
var
  S: string;
begin
  Touch('Sub\Mijn Notitie.md');
  S := ConvertWikiLinks('Zie [[Mijn Notitie]] en [[Mijn Notitie|dit]].', FRoot, FRoot);
  AssertTrue(S, Pos('[Mijn Notitie](Sub/Mijn%20Notitie.md)', S) > 0);
  AssertTrue(S, Pos('[dit](Sub/Mijn%20Notitie.md)', S) > 0);
end;

procedure TTestMdPrepare.TestWikiLinkMissingTarget;
var
  S: string;
begin
  S := ConvertWikiLinks('Zie [[Bestaat Niet]].', FRoot, FRoot);
  AssertEquals('Zie [Bestaat Niet](#niet-gevonden).', S);
end;

procedure TTestMdPrepare.TestClassifyExternal;
var
  P: string;
begin
  AssertTrue(ClassifyLink('https://example.com/a', FRoot, P) = lkExternal);
  AssertTrue(ClassifyLink('http://example.com', FRoot, P) = lkExternal);
end;

procedure TTestMdPrepare.TestClassifyMdWithSpacesAndAnchor;
var
  P: string;
begin
  Touch('Mijn Notitie.md');
  AssertTrue(ClassifyLink('Mijn%20Notitie.md#kop', FRoot, P) = lkMarkdown);
  AssertEquals(FRoot + '\Mijn Notitie.md', P);
  AssertTrue(ClassifyLink('#kop', FRoot, P) = lkAnchor);
end;

procedure TTestMdPrepare.TestClassifyUnicodeFileName;
var
  P: string;
begin
  Touch('Caf' + #$C3#$A9 + ' ' + #$C3#$B1 + '.md');
  AssertTrue(ClassifyLink('Caf%C3%A9%20%C3%B1.md', FRoot, P) = lkMarkdown);
end;

procedure TTestMdPrepare.TestClassifyUnknownExtensionBlocked;
var
  P: string;
begin
  Touch('a.exe');
  AssertTrue(ClassifyLink('a.exe', FRoot, P) = lkBlocked);
  AssertTrue(ClassifyLink('file:///C:/Windows/notepad.exe', FRoot, P) = lkBlocked);
  AssertTrue(ClassifyLink('javascript:alert(1)', FRoot, P) = lkBlocked);
end;

procedure TTestMdPrepare.TestClassifyMissingMdBlocked;
var
  P: string;
begin
  AssertTrue(ClassifyLink('weg.md', FRoot, P) = lkBlocked);
end;

initialization
  RegisterTest(TTestMdPrepare);

end.
