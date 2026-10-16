unit uMdRender;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpjson, Registry, Windows, uSettings, uMdPrepare;

const
  NotesHost = 'https://notes.molmd/';
  AppHost = 'https://app.molmd/';

function BuildRenderMessage(const Markdown, BaseUrl: string; Dark: Boolean; const Anchor: string): string;
function ResolveDark(Mode: TThemeMode): Boolean;
function FileBaseUrl(const RootDir, FilePath: string): string;
function LoadNoteMarkdown(const RootDir, FilePath: string): string;

implementation

function BuildRenderMessage(const Markdown, BaseUrl: string; Dark: Boolean; const Anchor: string): string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.Add('type', 'render');
    O.Add('markdown', Markdown);
    O.Add('baseUrl', BaseUrl);
    O.Add('dark', Dark);
    O.Add('anchor', Anchor);
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

function ResolveDark(Mode: TThemeMode): Boolean;
var
  R: TRegistry;
begin
  case Mode of
    tmDark: Exit(True);
    tmLight: Exit(False);
  end;
  Result := False;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') then
      if R.ValueExists('AppsUseLightTheme') then
        Result := R.ReadInteger('AppsUseLightTheme') = 0;
  finally
    R.Free;
  end;
end;

function FileBaseUrl(const RootDir, FilePath: string): string;
var
  Rel: string;
begin
  Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(RootDir), ExtractFilePath(FilePath));
  Rel := StringReplace(Rel, '\', '/', [rfReplaceAll]);
  if (Rel <> '') and (Rel[Length(Rel)] <> '/') then
    Rel := Rel + '/';
  Result := NotesHost + UrlEncodePath(Rel);
end;

function LoadNoteMarkdown(const RootDir, FilePath: string): string;
begin
  Result := ReadMdFile(FilePath);
  Result := StripFrontmatter(Result);
  Result := ConvertWikiLinks(Result, ExtractFileDir(FilePath), RootDir);
end;

end.
