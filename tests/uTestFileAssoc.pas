unit uTestFileAssoc;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Registry, Windows, fpcunit, testregistry, uFileAssoc;

type
  TTestFileAssoc = class(TTestCase)
  private
    const TestBase = 'Software\MolMDReaderTest\Classes';
    procedure Cleanup;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRegisterWritesOpenCommandWithArgument;
    procedure TestRegisterSetsMdDefaultAndOpenWith;
    procedure TestUnregisterRemovesEverything;
  end;

implementation

procedure TTestFileAssoc.Cleanup;
var
  R: TRegistry;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    DeleteRegKeyTree('Software\MolMDReaderTest');
  finally
    R.Free;
  end;
end;

procedure TTestFileAssoc.SetUp;
begin
  Cleanup;
end;

procedure TTestFileAssoc.TearDown;
begin
  Cleanup;
end;

procedure TTestFileAssoc.TestRegisterWritesOpenCommandWithArgument;
var
  R: TRegistry;
begin
  AssertTrue(RegisterMdAssociation('C:\Apps\MolMDReader.exe', TestBase));
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    AssertTrue(R.OpenKeyReadOnly(TestBase + '\MolMDReader.md\shell\open\command'));
    AssertEquals('"C:\Apps\MolMDReader.exe" "%1"', R.ReadString(''));
  finally
    R.Free;
  end;
end;

procedure TTestFileAssoc.TestRegisterSetsMdDefaultAndOpenWith;
var
  R: TRegistry;
begin
  RegisterMdAssociation('C:\Apps\MolMDReader.exe', TestBase);
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    AssertTrue(R.OpenKeyReadOnly(TestBase + '\.md'));
    AssertEquals('MolMDReader.md', R.ReadString(''));
    R.CloseKey;
    AssertTrue(R.OpenKeyReadOnly(TestBase + '\.md\OpenWithProgids'));
    AssertTrue(R.ValueExists('MolMDReader.md'));
  finally
    R.Free;
  end;
end;

procedure TTestFileAssoc.TestUnregisterRemovesEverything;
var
  R: TRegistry;
begin
  RegisterMdAssociation('C:\Apps\MolMDReader.exe', TestBase);
  UnregisterMdAssociation(TestBase);
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    AssertFalse(R.KeyExists(TestBase + '\MolMDReader.md'));
    if R.OpenKeyReadOnly(TestBase + '\.md') then
      AssertEquals('', R.ReadString(''));
  finally
    R.Free;
  end;
end;

initialization
  RegisterTest(TTestFileAssoc);

end.
