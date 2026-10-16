unit fMain;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, LCLType, fpjson, jsonparser,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVBrowserBase, uWVTypes, uWVEvents,
  uWVCoreWebView2Args, uWVTypeLibrary;

type
  TMainForm = class(TForm)
  private
    FBrowser: TWVBrowser;
    FParent: TWVWindowParent;
    FTimer: TTimer;
    procedure TryCreateBrowser;
    procedure TimerTick(Sender: TObject);
    procedure BrowserAfterCreated(Sender: TObject);
    procedure BrowserWebMessage(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure BrowserNavStarting(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NavigationStartingEventArgs);
    procedure BrowserNewWindow(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NewWindowRequestedEventArgs);
    procedure SendRender;
  protected
    procedure DoShow; override;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

const
  SpikeMd = '# Spike' + #10#10 + 'Tekst met **vet**, ~~doorgehaald~~ en een [link](https://example.com).' + #10#10 +
    '| Kolom | Waarde |' + #10 + '|---|---|' + #10 + '| a | 1 |' + #10#10 +
    '- [x] gedaan' + #10 + '- [ ] nog niet' + #10#10 +
    '<script>document.title="GEHACKT"</script><img src=x onerror="document.title=''GEHACKT2''">' + #10#10 +
    '```pas' + #10 + 'writeln(1);' + #10 + '```';

constructor TMainForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner);
  Caption := 'MolMDReader spike';
  Width := 1000;
  Height := 700;
  Position := poScreenCenter;
  FBrowser := TWVBrowser.Create(Self);
  FParent := TWVWindowParent.Create(Self);
  FParent.Parent := Self;
  FParent.Align := alClient;
  FParent.Browser := FBrowser;
  FBrowser.OnAfterCreated := BrowserAfterCreated;
  FBrowser.OnWebMessageReceived := BrowserWebMessage;
  FBrowser.OnNavigationStarting := BrowserNavStarting;
  FBrowser.OnNewWindowRequested := BrowserNewWindow;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 200;
  FTimer.OnTimer := TimerTick;
end;

procedure TMainForm.DoShow;
begin
  inherited;
  TryCreateBrowser;
end;

procedure TMainForm.TryCreateBrowser;
begin
  if GlobalWebView2Loader.InitializationError then
    Application.MessageBox(PChar(UTF8Encode(GlobalWebView2Loader.ErrorMessage)), 'WebView2', MB_OK)
  else if GlobalWebView2Loader.Initialized then
    FBrowser.CreateBrowser(FParent.Handle)
  else
    FTimer.Enabled := True;
end;

procedure TMainForm.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  TryCreateBrowser;
end;

procedure TMainForm.BrowserAfterCreated(Sender: TObject);
begin
  FParent.UpdateSize;
  FBrowser.SetVirtualHostNameToFolderMapping('app.molmd',
    UTF8Decode(ExtractFilePath(Application.ExeName) + 'assets'), COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
  FBrowser.SetVirtualHostNameToFolderMapping('notes.molmd',
    UTF8Decode(ExtractFilePath(Application.ExeName)), COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
  FBrowser.Navigate('https://app.molmd/index.html');
end;

procedure TMainForm.SendRender;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.Add('type', 'render');
    O.Add('markdown', SpikeMd);
    O.Add('baseUrl', 'https://notes.molmd/');
    O.Add('dark', False);
    FBrowser.PostWebMessageAsString(UTF8Decode(O.AsJSON));
  finally
    O.Free;
  end;
end;

procedure TMainForm.BrowserWebMessage(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  A: TCoreWebView2WebMessageReceivedEventArgs;
  J: TJSONData;
  T: string;
begin
  A := TCoreWebView2WebMessageReceivedEventArgs.Create(aArgs);
  try
    J := GetJSON(UTF8Encode(A.WebMessageAsString));
    try
      T := TJSONObject(J).Get('type', '');
      if T = 'ready' then SendRender
      else if T = 'rendered' then Caption := 'spike rendered'
      else if T = 'link' then Caption := 'link: ' + TJSONObject(J).Get('href', '');
    finally
      J.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TMainForm.BrowserNavStarting(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NavigationStartingEventArgs);
var
  A: TCoreWebView2NavigationStartingEventArgs;
  U: string;
begin
  A := TCoreWebView2NavigationStartingEventArgs.Create(aArgs);
  try
    U := UTF8Encode(A.URI);
    if U <> 'https://app.molmd/index.html' then A.Cancel := True;
  finally
    A.Free;
  end;
end;

procedure TMainForm.BrowserNewWindow(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NewWindowRequestedEventArgs);
var
  A: TCoreWebView2NewWindowRequestedEventArgs;
begin
  A := TCoreWebView2NewWindowRequestedEventArgs.Create(aArgs);
  try
    A.Handled := True;
  finally
    A.Free;
  end;
end;

initialization
  GlobalWebView2Loader := TWVLoader.Create(nil);
  GlobalWebView2Loader.UserDataFolder := UTF8Decode(GetEnvironmentVariable('APPDATA') + '\MolMDReader\webview');
  GlobalWebView2Loader.StartWebView2;

end.
