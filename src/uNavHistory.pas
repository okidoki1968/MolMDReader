unit uNavHistory;

{$MODE Delphi}

interface

uses
  Classes, SysUtils;

type
  TNavHistory = class
  private
    FItems: TStringList;
    FIndex: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Visit(const FilePath: string);
    function CanBack: Boolean;
    function CanForward: Boolean;
    function Back: string;
    function Forward: string;
    function Current: string;
  end;

implementation

constructor TNavHistory.Create;
begin
  inherited;
  FItems := TStringList.Create;
  FIndex := -1;
end;

destructor TNavHistory.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TNavHistory.Visit(const FilePath: string);
begin
  if (FIndex >= 0) and SameText(FItems[FIndex], FilePath) then
    Exit;
  while FItems.Count > FIndex + 1 do
    FItems.Delete(FItems.Count - 1);
  FItems.Add(FilePath);
  FIndex := FItems.Count - 1;
end;

function TNavHistory.CanBack: Boolean;
begin
  Result := FIndex > 0;
end;

function TNavHistory.CanForward: Boolean;
begin
  Result := (FIndex >= 0) and (FIndex < FItems.Count - 1);
end;

function TNavHistory.Back: string;
begin
  if CanBack then
    Dec(FIndex);
  Result := Current;
end;

function TNavHistory.Forward: string;
begin
  if CanForward then
    Inc(FIndex);
  Result := Current;
end;

function TNavHistory.Current: string;
begin
  if FIndex >= 0 then
    Result := FItems[FIndex]
  else
    Result := '';
end;

end.
