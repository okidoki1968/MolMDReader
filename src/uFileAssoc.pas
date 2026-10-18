unit uFileAssoc;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Registry, Windows;

const
  DefaultClassesKey = 'Software\Classes';
  MdProgId = 'MolMDReader.md';

function RegisterMdAssociation(const ExePath: string; const BaseKey: string = DefaultClassesKey): Boolean;
function UnregisterMdAssociation(const BaseKey: string = DefaultClassesKey): Boolean;
procedure DeleteRegKeyTree(const Path: string);

implementation

procedure SHChangeNotify(wEventId: LongInt; uFlags: UINT; dwItem1, dwItem2: Pointer); stdcall; external 'shell32.dll';

procedure DeleteRegKeyTree(const Path: string);
var
  R: TRegistry;
  Names: TStringList;
  I: Integer;
begin
  R := TRegistry.Create;
  Names := TStringList.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(Path, False) then
    begin
      R.GetKeyNames(Names);
      R.CloseKey;
      for I := 0 to Names.Count - 1 do
        DeleteRegKeyTree(Path + '\' + Names[I]);
    end;
    R.DeleteKey(Path);
  finally
    Names.Free;
    R.Free;
  end;
end;

procedure NotifyShell(const BaseKey: string);
begin
  if SameText(BaseKey, DefaultClassesKey) then
    SHChangeNotify($08000000, 0, nil, nil); // SHCNE_ASSOCCHANGED
end;

function RegisterMdAssociation(const ExePath: string; const BaseKey: string): Boolean;
var
  R: TRegistry;
begin
  Result := False;
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if not R.OpenKey(BaseKey + '\' + MdProgId, True) then Exit;
    R.WriteString('', 'Markdown-document');
    R.CloseKey;
    if not R.OpenKey(BaseKey + '\' + MdProgId + '\DefaultIcon', True) then Exit;
    R.WriteString('', '"' + ExePath + '",0');
    R.CloseKey;
    if not R.OpenKey(BaseKey + '\' + MdProgId + '\shell\open\command', True) then Exit;
    R.WriteString('', '"' + ExePath + '" "%1"');
    R.CloseKey;
    if not R.OpenKey(BaseKey + '\.md', True) then Exit;
    R.WriteString('', MdProgId);
    R.CloseKey;
    if not R.OpenKey(BaseKey + '\.md\OpenWithProgids', True) then Exit;
    R.WriteString(MdProgId, '');
    R.CloseKey;
    Result := True;
  finally
    R.Free;
  end;
  NotifyShell(BaseKey);
end;

function UnregisterMdAssociation(const BaseKey: string): Boolean;
var
  R: TRegistry;
begin
  DeleteRegKeyTree(BaseKey + '\' + MdProgId);
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(BaseKey + '\.md', False) then
    begin
      if SameText(R.ReadString(''), MdProgId) then
        R.WriteString('', '');
      R.CloseKey;
    end;
    if R.OpenKey(BaseKey + '\.md\OpenWithProgids', False) then
    begin
      if R.ValueExists(MdProgId) then
        R.DeleteValue(MdProgId);
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
  NotifyShell(BaseKey);
  Result := True;
end;

end.
