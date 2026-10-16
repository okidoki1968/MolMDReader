unit uTestMdRender;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, uSettings, uMdRender;

type
  TTestMdRender = class(TTestCase)
  private
    FRoot: string;
    procedure WriteFile(const RelPath, Content: string);
    procedure RemoveTree(const Dir: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRenderMessageRoundTripsTrickyText;
    procedure TestRenderMessageCarriesDarkAndBaseUrl;
    procedure TestResolveDarkExplicitModes;
    procedure TestBaseUrlForRootAndNestedFile;
    procedure TestLoadNoteMarkdownStripsFrontmatterAndConvertsWikiLinks;
  end;

implementation

procedure TTestMdRender.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'molmd-render-' + IntToStr(GetTickCount64);
  ForceDirectories(FRoot);
end;

procedure TTestMdRender.RemoveTree(const Dir: string);
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

procedure TTestMdRender.TearDown;
begin
  RemoveTree(FRoot);
end;

procedure TTestMdRender.WriteFile(const RelPath, Content: string);
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

procedure TTestMdRender.TestRenderMessageRoundTripsTrickyText;
var
  Md, Msg: string;
  J: TJSONData;
begin
  Md := 'Aanhaling "dubbel" en \ backslash'#10'<script>alert(1)</script>'#10'caf' + #$C3#$A9;
  Msg := BuildRenderMessage(Md, 'https://notes.molmd/', False, '');
  J := GetJSON(Msg);
  try
    AssertEquals('render', TJSONObject(J).Get('type', ''));
    AssertEquals(Md, TJSONObject(J).Get('markdown', ''));
  finally
    J.Free;
  end;
end;

procedure TTestMdRender.TestRenderMessageCarriesDarkAndBaseUrl;
var
  J: TJSONData;
begin
  J := GetJSON(BuildRenderMessage('x', 'https://notes.molmd/Sub/', True, 'kop-1'));
  try
    AssertTrue(TJSONObject(J).Get('dark', False));
    AssertEquals('https://notes.molmd/Sub/', TJSONObject(J).Get('baseUrl', ''));
    AssertEquals('kop-1', TJSONObject(J).Get('anchor', ''));
  finally
    J.Free;
  end;
end;

procedure TTestMdRender.TestResolveDarkExplicitModes;
begin
  AssertTrue(ResolveDark(tmDark));
  AssertFalse(ResolveDark(tmLight));
end;

procedure TTestMdRender.TestBaseUrlForRootAndNestedFile;
begin
  AssertEquals('https://notes.molmd/', FileBaseUrl('C:\N', 'C:\N\a.md'));
  AssertEquals('https://notes.molmd/Sub%20Dir/Diep/', FileBaseUrl('C:\N', 'C:\N\Sub Dir\Diep\a.md'));
end;

procedure TTestMdRender.TestLoadNoteMarkdownStripsFrontmatterAndConvertsWikiLinks;
var
  S: string;
begin
  WriteFile('Doel.md', 'doel');
  WriteFile('a.md', '---'#10'tags: x'#10'---'#10'Zie [[Doel]].');
  S := LoadNoteMarkdown(FRoot, FRoot + '\a.md');
  AssertEquals('Zie [Doel](Doel.md).', Trim(S));
end;

initialization
  RegisterTest(TTestMdRender);

end.
