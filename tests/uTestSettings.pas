unit uTestSettings;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uSettings;

type
  TTestSettings = class(TTestCase)
  private
    FDir: string;
    function SettingsPath: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRoundTrip;
    procedure TestLoadMissingFileGivesDefaults;
    procedure TestLoadCorruptJsonGivesDefaults;
    procedure TestAddFavoriteIgnoresDuplicates;
    procedure TestValidatePathsClearsMissing;
  end;

implementation

procedure TTestSettings.SetUp;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'molmd-settings-' + IntToStr(GetTickCount64);
  ForceDirectories(FDir);
end;

procedure TTestSettings.TearDown;
begin
  DeleteFile(SettingsPath);
  RemoveDir(FDir + '\sub');
  RemoveDir(FDir);
end;

function TTestSettings.SettingsPath: string;
begin
  Result := FDir + '\settings.json';
end;

procedure TTestSettings.TestRoundTrip;
var
  A, B: TAppSettings;
begin
  A := TAppSettings.Create(SettingsPath);
  B := TAppSettings.Create(SettingsPath);
  try
    A.RootDir := 'C:\Notities';
    A.CurrentDir := 'C:\Notities\Sub';
    A.CurrentFile := 'C:\Notities\Sub\a.md';
    A.Theme := tmDark;
    A.SearchAll := True;
    A.AddFavorite('C:\Notities');
    A.AddFavorite('D:\Klanten\Acme');
    A.Save;
    B.Load;
    AssertEquals('C:\Notities', B.RootDir);
    AssertEquals('C:\Notities\Sub', B.CurrentDir);
    AssertEquals('C:\Notities\Sub\a.md', B.CurrentFile);
    AssertTrue(B.Theme = tmDark);
    AssertTrue(B.SearchAll);
    AssertEquals(2, B.Favorites.Count);
    AssertEquals('D:\Klanten\Acme', B.Favorites[1]);
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TTestSettings.TestLoadMissingFileGivesDefaults;
var
  S: TAppSettings;
begin
  S := TAppSettings.Create(SettingsPath);
  try
    S.Load;
    AssertEquals('', S.RootDir);
    AssertTrue(S.Theme = tmLight);
    AssertFalse(S.SearchAll);
    AssertEquals(0, S.Favorites.Count);
  finally
    S.Free;
  end;
end;

procedure TTestSettings.TestLoadCorruptJsonGivesDefaults;
var
  S: TAppSettings;
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := '{ dit is geen json';
    L.SaveToFile(SettingsPath);
  finally
    L.Free;
  end;
  S := TAppSettings.Create(SettingsPath);
  try
    S.Load;
    AssertEquals('', S.RootDir);
    AssertTrue(S.Theme = tmLight);
  finally
    S.Free;
  end;
end;

procedure TTestSettings.TestAddFavoriteIgnoresDuplicates;
var
  S: TAppSettings;
begin
  S := TAppSettings.Create(SettingsPath);
  try
    S.AddFavorite('C:\A');
    S.AddFavorite('c:\a');
    AssertEquals(1, S.Favorites.Count);
    S.RemoveFavorite('C:\A');
    AssertEquals(0, S.Favorites.Count);
  finally
    S.Free;
  end;
end;

procedure TTestSettings.TestValidatePathsClearsMissing;
var
  S: TAppSettings;
  F: TStringList;
begin
  ForceDirectories(FDir + '\sub');
  F := TStringList.Create;
  try
    F.SaveToFile(FDir + '\sub\a.md');
  finally
    F.Free;
  end;
  S := TAppSettings.Create(SettingsPath);
  try
    S.RootDir := FDir;
    S.CurrentDir := FDir + '\sub';
    S.CurrentFile := FDir + '\sub\a.md';
    S.ValidatePaths;
    AssertEquals(FDir + '\sub\a.md', S.CurrentFile);
    DeleteFile(FDir + '\sub\a.md');
    S.ValidatePaths;
    AssertEquals('', S.CurrentFile);
    AssertEquals(FDir + '\sub', S.CurrentDir);
    RemoveDir(FDir + '\sub');
    S.ValidatePaths;
    AssertEquals('', S.CurrentDir);
    AssertEquals(FDir, S.RootDir);
    S.RootDir := FDir + '\bestaatniet';
    S.CurrentDir := FDir;
    S.ValidatePaths;
    AssertEquals('', S.RootDir);
    AssertEquals('', S.CurrentDir);
  finally
    S.Free;
  end;
end;

initialization
  RegisterTest(TTestSettings);

end.
