unit uSettings;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

type
  TThemeMode = (tmSystem, tmLight, tmDark);

  TAppSettings = class
  private
    FFilePath: string;
    FFavorites: TStringList;
  public
    RootDir: string;
    CurrentDir: string;
    CurrentFile: string;
    Theme: TThemeMode;
    SearchAll: Boolean;
    constructor Create(const AFilePath: string);
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    procedure AddFavorite(const Dir: string);
    procedure RemoveFavorite(const Dir: string);
    procedure ValidatePaths;
    property Favorites: TStringList read FFavorites;
  end;

function DefaultSettingsPath: string;

implementation

function DefaultSettingsPath: string;
var
  Dir: string;
begin
  Dir := GetEnvironmentVariable('APPDATA') + '\MolMDReader';
  ForceDirectories(Dir);
  Result := Dir + '\settings.json';
end;

constructor TAppSettings.Create(const AFilePath: string);
begin
  inherited Create;
  FFilePath := AFilePath;
  FFavorites := TStringList.Create;
  Theme := tmLight;
end;

destructor TAppSettings.Destroy;
begin
  FFavorites.Free;
  inherited;
end;

procedure TAppSettings.Load;
var
  L: TStringList;
  J: TJSONData;
  O: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  RootDir := '';
  CurrentDir := '';
  CurrentFile := '';
  Theme := tmLight;
  SearchAll := False;
  FFavorites.Clear;
  if not FileExists(FFilePath) then
    Exit;
  L := TStringList.Create;
  try
    try
      L.LoadFromFile(FFilePath, TEncoding.UTF8);
      J := GetJSON(L.Text);
    except
      Exit;
    end;
  finally
    L.Free;
  end;
  try
    if not (J is TJSONObject) then
      Exit;
    O := TJSONObject(J);
    RootDir := O.Get('rootDir', '');
    CurrentDir := O.Get('currentDir', '');
    CurrentFile := O.Get('currentFile', '');
    I := O.Get('theme', Ord(tmLight));
    if (I >= Ord(Low(TThemeMode))) and (I <= Ord(High(TThemeMode))) then
      Theme := TThemeMode(I);
    SearchAll := O.Get('searchAll', False);
    if O.Find('favorites') is TJSONArray then
    begin
      A := TJSONArray(O.Find('favorites'));
      for I := 0 to A.Count - 1 do
        FFavorites.Add(A.Strings[I]);
    end;
  finally
    J.Free;
  end;
end;

procedure TAppSettings.Save;
var
  O: TJSONObject;
  A: TJSONArray;
  L: TStringList;
  I: Integer;
  Tmp: string;
begin
  O := TJSONObject.Create;
  try
    O.Add('rootDir', RootDir);
    O.Add('currentDir', CurrentDir);
    O.Add('currentFile', CurrentFile);
    O.Add('theme', Ord(Theme));
    O.Add('searchAll', SearchAll);
    A := TJSONArray.Create;
    for I := 0 to FFavorites.Count - 1 do
      A.Add(FFavorites[I]);
    O.Add('favorites', A);
    L := TStringList.Create;
    try
      L.Text := O.FormatJSON;
      Tmp := FFilePath + '.tmp';
      L.SaveToFile(Tmp, TEncoding.UTF8);
    finally
      L.Free;
    end;
  finally
    O.Free;
  end;
  if FileExists(FFilePath) then
    DeleteFile(FFilePath);
  RenameFile(Tmp, FFilePath);
end;

procedure TAppSettings.AddFavorite(const Dir: string);
var
  I: Integer;
begin
  for I := 0 to FFavorites.Count - 1 do
    if SameText(FFavorites[I], Dir) then
      Exit;
  FFavorites.Add(Dir);
end;

procedure TAppSettings.RemoveFavorite(const Dir: string);
var
  I: Integer;
begin
  for I := FFavorites.Count - 1 downto 0 do
    if SameText(FFavorites[I], Dir) then
      FFavorites.Delete(I);
end;

procedure TAppSettings.ValidatePaths;
begin
  if (RootDir <> '') and not DirectoryExists(RootDir) then
    RootDir := '';
  if RootDir = '' then
  begin
    CurrentDir := '';
    CurrentFile := '';
    Exit;
  end;
  if (CurrentDir <> '') and not DirectoryExists(CurrentDir) then
    CurrentDir := '';
  if (CurrentFile <> '') and ((CurrentDir = '') or not FileExists(CurrentFile)) then
    CurrentFile := '';
end;

end.
