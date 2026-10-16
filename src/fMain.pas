unit fMain;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, ComCtrls, StdCtrls, Dialogs, Menus,
  LCLType, LCLIntf, Messages, fpjson, jsonparser,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVBrowserBase, uWVTypes, uWVEvents,
  uWVCoreWebView2Args, uWVTypeLibrary,
  uSettings, uFileTree, uNavHistory, uMdPrepare, uMdRender;

type
  TMainForm = class(TForm)
  private
    FSettings: TAppSettings;
    FHistory: TNavHistory;
    FTree: TMdNode;
    FBrowser: TWVBrowser;
    FBrowserParent: TWVWindowParent;
    FInitTimer: TTimer;
    FWatchTimer: TTimer;
    FTopPanel: TPanel;
    FOpenButton: TButton;
    FBackButton: TButton;
    FForwardButton: TButton;
    FLeftPanel: TPanel;
    FFavPanel: TPanel;
    FFavHeader: TPanel;
    FFavAddButton: TButton;
    FFavList: TListBox;
    FFavMenu: TPopupMenu;
    FFavSplitter: TSplitter;
    FTreeView: TTreeView;
    FSplitter: TSplitter;
    FStatus: TStatusBar;
    FBrowserReady: Boolean;
    FPendingFile: string;
    FPendingAnchor: string;
    FSelecting: Boolean;
    FShownFileAge: LongInt;
    FMissingShown: Boolean;
    procedure BuildUi;
    procedure TryCreateBrowser;
    procedure InitTimerTick(Sender: TObject);
    procedure WatchTimerTick(Sender: TObject);
    procedure BrowserAfterCreated(Sender: TObject);
    procedure BrowserWebMessage(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure BrowserNavStarting(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NavigationStartingEventArgs);
    procedure BrowserNewWindow(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NewWindowRequestedEventArgs);
    procedure OpenButtonClick(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure ForwardClick(Sender: TObject);
    procedure FavAddClick(Sender: TObject);
    procedure FavListClick(Sender: TObject);
    procedure FavRemoveClick(Sender: TObject);
    procedure FavListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure FormCloseHandler(Sender: TObject; var CloseAction: TCloseAction);
    procedure LoadTree;
    procedure FillNode(Parent: TTreeNode; Node: TMdNode);
    function FindTreeNode(const Path: string; Parent: TTreeNode): TTreeNode;
    procedure SelectInTree(const Path: string);
    procedure RefreshFavorites;
    procedure UpdateNavButtons;
    procedure UpdateStatus;
    procedure ShowMessagePage(const Markdown: string);
    procedure RenderFile(const Path, Anchor: string);
    procedure MapNotesHost;
    procedure HandleLink(const Raw: string);
    procedure WMMove(var Msg: TWMMove); message WM_MOVE;
    procedure WMMoving(var Msg: TMessage); message WM_MOVING;
  protected
    procedure DoShow; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenRoot(const Dir: string);
    procedure OpenFile(const Path: string; AddToHistory: Boolean; const Anchor: string = '');
  end;

var
  MainForm: TMainForm;

implementation

const
  WelcomeMd = '# MolMDReader'#10#10 + 'Kies een map met markdown-bestanden via **Map openen...** bovenaan.';

{ TMainForm }

constructor TMainForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner);
  Caption := 'MolMDReader';
  Width := 1200;
  Height := 780;
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 10;
  FSettings := TAppSettings.Create(DefaultSettingsPath);
  FSettings.Load;
  FSettings.ValidatePaths;
  FHistory := TNavHistory.Create;
  BuildUi;
  OnClose := FormCloseHandler;
  if FSettings.RootDir <> '' then
    LoadTree;
  RefreshFavorites;
  UpdateNavButtons;
  UpdateStatus;
end;

destructor TMainForm.Destroy;
begin
  FSettings.Free;
  FHistory.Free;
  FTree.Free;
  inherited;
end;

procedure TMainForm.BuildUi;
var
  Item: TMenuItem;
begin
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := False;
  FStatus.Panels.Add.Width := 360;
  FStatus.Panels.Add.Width := 220;
  FStatus.Panels.Add.Width := 160;

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 44;
  FTopPanel.BevelOuter := bvNone;

  FOpenButton := TButton.Create(Self);
  FOpenButton.Parent := FTopPanel;
  FOpenButton.SetBounds(8, 8, 130, 28);
  FOpenButton.Caption := 'Map openen...';
  FOpenButton.OnClick := OpenButtonClick;

  FBackButton := TButton.Create(Self);
  FBackButton.Parent := FTopPanel;
  FBackButton.SetBounds(146, 8, 34, 28);
  FBackButton.Caption := '<';
  FBackButton.OnClick := BackClick;

  FForwardButton := TButton.Create(Self);
  FForwardButton.Parent := FTopPanel;
  FForwardButton.SetBounds(184, 8, 34, 28);
  FForwardButton.Caption := '>';
  FForwardButton.OnClick := ForwardClick;

  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := 290;
  FLeftPanel.BevelOuter := bvNone;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := alLeft;
  FSplitter.Left := 291;
  FSplitter.Width := 5;

  FFavPanel := TPanel.Create(Self);
  FFavPanel.Parent := FLeftPanel;
  FFavPanel.Align := alTop;
  FFavPanel.Height := 150;
  FFavPanel.BevelOuter := bvNone;

  FFavHeader := TPanel.Create(Self);
  FFavHeader.Parent := FFavPanel;
  FFavHeader.Align := alTop;
  FFavHeader.Height := 30;
  FFavHeader.BevelOuter := bvNone;
  FFavHeader.Caption := '  Favorieten';
  FFavHeader.Alignment := taLeftJustify;
  FFavHeader.Font.Style := [fsBold];

  FFavAddButton := TButton.Create(Self);
  FFavAddButton.Parent := FFavHeader;
  FFavAddButton.Align := alRight;
  FFavAddButton.Width := 34;
  FFavAddButton.Caption := '+';
  FFavAddButton.Hint := 'Huidige map toevoegen aan favorieten';
  FFavAddButton.ShowHint := True;
  FFavAddButton.OnClick := FavAddClick;

  FFavMenu := TPopupMenu.Create(Self);
  Item := TMenuItem.Create(FFavMenu);
  Item.Caption := 'Verwijderen';
  Item.OnClick := FavRemoveClick;
  FFavMenu.Items.Add(Item);

  FFavList := TListBox.Create(Self);
  FFavList.Parent := FFavPanel;
  FFavList.Align := alClient;
  FFavList.BorderStyle := bsNone;
  FFavList.PopupMenu := FFavMenu;
  FFavList.OnClick := FavListClick;
  FFavList.OnMouseDown := FavListMouseDown;

  FFavSplitter := TSplitter.Create(Self);
  FFavSplitter.Parent := FLeftPanel;
  FFavSplitter.Align := alTop;
  FFavSplitter.Top := 151;
  FFavSplitter.Height := 5;

  FTreeView := TTreeView.Create(Self);
  FTreeView.Parent := FLeftPanel;
  FTreeView.Align := alClient;
  FTreeView.BorderStyle := bsNone;
  FTreeView.ReadOnly := True;
  FTreeView.HideSelection := False;
  FTreeView.RowSelect := True;
  FTreeView.ShowRoot := True;
  FTreeView.OnChange := TreeChange;

  FBrowser := TWVBrowser.Create(Self);
  FBrowserParent := TWVWindowParent.Create(Self);
  FBrowserParent.Parent := Self;
  FBrowserParent.Align := alClient;
  FBrowserParent.Browser := FBrowser;
  FBrowser.OnAfterCreated := BrowserAfterCreated;
  FBrowser.OnWebMessageReceived := BrowserWebMessage;
  FBrowser.OnNavigationStarting := BrowserNavStarting;
  FBrowser.OnNewWindowRequested := BrowserNewWindow;

  FInitTimer := TTimer.Create(Self);
  FInitTimer.Enabled := False;
  FInitTimer.Interval := 200;
  FInitTimer.OnTimer := InitTimerTick;

  FWatchTimer := TTimer.Create(Self);
  FWatchTimer.Interval := 1000;
  FWatchTimer.OnTimer := WatchTimerTick;
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
    FBrowser.CreateBrowser(FBrowserParent.Handle)
  else
    FInitTimer.Enabled := True;
end;

procedure TMainForm.InitTimerTick(Sender: TObject);
begin
  FInitTimer.Enabled := False;
  TryCreateBrowser;
end;

procedure TMainForm.BrowserAfterCreated(Sender: TObject);
begin
  FBrowserParent.UpdateSize;
  FBrowser.DevToolsEnabled := False;
  FBrowser.DefaultContextMenusEnabled := False;
  FBrowser.ZoomControlEnabled := False;
  FBrowser.StatusBarEnabled := False;
  FBrowser.SetVirtualHostNameToFolderMapping('app.molmd',
    UTF8Decode(ExtractFilePath(Application.ExeName) + 'assets'), COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
  MapNotesHost;
  FBrowser.Navigate(UTF8Decode(AppHost + 'index.html'));
end;

procedure TMainForm.MapNotesHost;
begin
  if (FBrowser = nil) or (not FBrowser.Initialized) then
    Exit;
  FBrowser.ClearVirtualHostNameToFolderMapping('notes.molmd');
  if FSettings.RootDir <> '' then
    FBrowser.SetVirtualHostNameToFolderMapping('notes.molmd',
      UTF8Decode(FSettings.RootDir), COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
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
  finally
    A.Free;
  end;
  try
    if not (J is TJSONObject) then
      Exit;
    T := TJSONObject(J).Get('type', '');
    if T = 'ready' then
    begin
      FBrowserReady := True;
      if FPendingFile <> '' then
        RenderFile(FPendingFile, FPendingAnchor)
      else if FSettings.CurrentFile <> '' then
        RenderFile(FSettings.CurrentFile, '')
      else
        ShowMessagePage(WelcomeMd);
      FPendingFile := '';
    end
    else if T = 'link' then
      HandleLink(TJSONObject(J).Get('raw', ''));
  finally
    J.Free;
  end;
end;

procedure TMainForm.BrowserNavStarting(Sender: TObject; const aWebView: ICoreWebView2; const aArgs: ICoreWebView2NavigationStartingEventArgs);
var
  A: TCoreWebView2NavigationStartingEventArgs;
begin
  A := TCoreWebView2NavigationStartingEventArgs.Create(aArgs);
  try
    if UTF8Encode(A.URI) <> AppHost + 'index.html' then
      A.Cancel := True;
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

procedure TMainForm.ShowMessagePage(const Markdown: string);
begin
  if not FBrowserReady then
    Exit;
  FBrowser.PostWebMessageAsString(UTF8Decode(
    BuildRenderMessage(Markdown, NotesHost, ResolveDark(FSettings.Theme), '')));
end;

procedure TMainForm.RenderFile(const Path, Anchor: string);
var
  Md: string;
begin
  if not FBrowserReady then
  begin
    FPendingFile := Path;
    FPendingAnchor := Anchor;
    Exit;
  end;
  if not FileExists(Path) then
  begin
    ShowMessagePage('# Bestand niet meer beschikbaar'#10#10 + '`' + ExtractFileName(Path) + '`');
    Exit;
  end;
  FShownFileAge := FileAge(Path);
  FMissingShown := False;
  Md := LoadNoteMarkdown(FSettings.RootDir, Path);
  FBrowser.PostWebMessageAsString(UTF8Decode(
    BuildRenderMessage(Md, FileBaseUrl(FSettings.RootDir, Path), ResolveDark(FSettings.Theme), Anchor)));
end;

procedure TMainForm.OpenFile(const Path: string; AddToHistory: Boolean; const Anchor: string);
begin
  if not FileExists(Path) then
  begin
    ShowMessagePage('# Bestand niet meer beschikbaar'#10#10 + '`' + ExtractFileName(Path) + '`');
    Exit;
  end;
  FSettings.CurrentFile := Path;
  FSettings.CurrentDir := ExtractFileDir(Path);
  if AddToHistory then
    FHistory.Visit(Path);
  SelectInTree(Path);
  RenderFile(Path, Anchor);
  FSettings.Save;
  UpdateNavButtons;
  UpdateStatus;
end;

procedure TMainForm.OpenRoot(const Dir: string);
begin
  FSettings.RootDir := ExcludeTrailingPathDelimiter(Dir);
  FSettings.CurrentDir := FSettings.RootDir;
  FSettings.CurrentFile := '';
  FSettings.Save;
  MapNotesHost;
  LoadTree;
  ShowMessagePage(WelcomeMd);
  UpdateStatus;
end;

procedure TMainForm.LoadTree;
begin
  FSelecting := True;
  try
    FTreeView.Items.Clear;
    FreeAndNil(FTree);
    if FSettings.RootDir = '' then
      Exit;
    FTree := ScanMdTree(FSettings.RootDir);
    FTreeView.Items.BeginUpdate;
    try
      FillNode(nil, FTree);
    finally
      FTreeView.Items.EndUpdate;
    end;
    Caption := 'MolMDReader - ' + FSettings.RootDir;
  finally
    FSelecting := False;
  end;
  if FSettings.CurrentFile <> '' then
    SelectInTree(FSettings.CurrentFile);
end;

procedure TMainForm.FillNode(Parent: TTreeNode; Node: TMdNode);
var
  I: Integer;
  Child: TMdNode;
  TN: TTreeNode;
begin
  for I := 0 to Node.Children.Count - 1 do
  begin
    Child := TMdNode(Node.Children[I]);
    TN := FTreeView.Items.AddChildObject(Parent, Child.Name, Child);
    if Child.IsDir then
      FillNode(TN, Child);
  end;
  if (Parent = nil) and (FTreeView.Items.Count > 0) then
    FTreeView.Items[0].Expanded := False;
end;

function TMainForm.FindTreeNode(const Path: string; Parent: TTreeNode): TTreeNode;
var
  N: TTreeNode;
begin
  Result := nil;
  if Parent = nil then
    N := FTreeView.Items.GetFirstNode
  else
    N := Parent.GetFirstChild;
  while N <> nil do
  begin
    if SameText(TMdNode(N.Data).FullPath, Path) then
      Exit(N);
    if TMdNode(N.Data).IsDir and (Pos(LowerCase(TMdNode(N.Data).FullPath + '\'), LowerCase(Path)) = 1) then
    begin
      Result := FindTreeNode(Path, N);
      if Result <> nil then
        Exit;
    end;
    N := N.GetNextSibling;
  end;
end;

procedure TMainForm.SelectInTree(const Path: string);
var
  N: TTreeNode;
begin
  N := FindTreeNode(Path, nil);
  if N = nil then
    Exit;
  FSelecting := True;
  try
    N.MakeVisible;
    FTreeView.Selected := N;
  finally
    FSelecting := False;
  end;
end;

procedure TMainForm.TreeChange(Sender: TObject; Node: TTreeNode);
var
  MN: TMdNode;
begin
  if FSelecting or (Node = nil) or (Node.Data = nil) then
    Exit;
  MN := TMdNode(Node.Data);
  if MN.IsDir then
  begin
    FSettings.CurrentDir := MN.FullPath;
    FSettings.Save;
    UpdateStatus;
  end
  else if not SameText(MN.FullPath, FSettings.CurrentFile) then
    OpenFile(MN.FullPath, True);
end;

procedure TMainForm.RefreshFavorites;
begin
  FFavList.Items.Assign(FSettings.Favorites);
end;

procedure TMainForm.OpenButtonClick(Sender: TObject);
var
  D: TSelectDirectoryDialog;
begin
  D := TSelectDirectoryDialog.Create(Self);
  try
    D.Title := 'Kies een map met markdown-bestanden';
    if FSettings.RootDir <> '' then
      D.InitialDir := FSettings.RootDir;
    if D.Execute then
      OpenRoot(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMainForm.FavAddClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := FSettings.CurrentDir;
  if Dir = '' then
    Dir := FSettings.RootDir;
  if Dir = '' then
    Exit;
  FSettings.AddFavorite(Dir);
  FSettings.Save;
  RefreshFavorites;
end;

procedure TMainForm.FavListClick(Sender: TObject);
var
  Dir: string;
begin
  if FFavList.ItemIndex < 0 then
    Exit;
  Dir := FFavList.Items[FFavList.ItemIndex];
  if not DirectoryExists(Dir) then
  begin
    ShowMessage('Deze map bestaat niet meer: ' + Dir);
    Exit;
  end;
  OpenRoot(Dir);
end;

procedure TMainForm.FavListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button = mbRight then
  begin
    I := FFavList.ItemAtPos(Point(X, Y), True);
    if I >= 0 then
      FFavList.ItemIndex := I;
  end;
end;

procedure TMainForm.FavRemoveClick(Sender: TObject);
begin
  if FFavList.ItemIndex < 0 then
    Exit;
  FSettings.RemoveFavorite(FFavList.Items[FFavList.ItemIndex]);
  FSettings.Save;
  RefreshFavorites;
end;

procedure TMainForm.BackClick(Sender: TObject);
begin
  if FHistory.CanBack then
    OpenFile(FHistory.Back, False);
end;

procedure TMainForm.ForwardClick(Sender: TObject);
begin
  if FHistory.CanForward then
    OpenFile(FHistory.Forward, False);
end;

procedure TMainForm.UpdateNavButtons;
begin
  FBackButton.Enabled := FHistory.CanBack;
  FForwardButton.Enabled := FHistory.CanForward;
end;

procedure TMainForm.UpdateStatus;
var
  Count: Integer;
begin
  if FSettings.CurrentFile <> '' then
  begin
    FStatus.Panels[0].Text := ExtractFileName(FSettings.CurrentFile);
    if FileExists(FSettings.CurrentFile) then
      FStatus.Panels[1].Text := 'gewijzigd ' + FormatDateTime('dd-mm-yyyy hh:nn', FileDateToDateTime(FileAge(FSettings.CurrentFile)))
    else
      FStatus.Panels[1].Text := '';
  end
  else
  begin
    FStatus.Panels[0].Text := '';
    FStatus.Panels[1].Text := '';
  end;
  if FTree <> nil then
    Count := CountMdFiles(FTree)
  else
    Count := 0;
  FStatus.Panels[2].Text := IntToStr(Count) + ' bestanden';
end;

procedure TMainForm.HandleLink(const Raw: string);
var
  Resolved, Anchor: string;
  P: Integer;
begin
  case ClassifyLink(Raw, ExtractFileDir(FSettings.CurrentFile), Resolved) of
    lkExternal:
      OpenURL(Raw);
    lkMarkdown:
      begin
        Anchor := '';
        P := Pos('#', Raw);
        if P > 0 then
          Anchor := Copy(Raw, P + 1, MaxInt);
        OpenFile(Resolved, True, Anchor);
      end;
  end;
end;

procedure TMainForm.WatchTimerTick(Sender: TObject);
begin
  if (not FBrowserReady) or (FSettings.CurrentFile = '') then
    Exit;
  if not FileExists(FSettings.CurrentFile) then
  begin
    if not FMissingShown then
    begin
      FMissingShown := True;
      ShowMessagePage('# Bestand niet meer beschikbaar'#10#10 + '`' + ExtractFileName(FSettings.CurrentFile) + '`');
      LoadTree;
      UpdateStatus;
    end;
    Exit;
  end;
  if FileAge(FSettings.CurrentFile) <> FShownFileAge then
  begin
    RenderFile(FSettings.CurrentFile, '');
    UpdateStatus;
  end;
end;

procedure TMainForm.FormCloseHandler(Sender: TObject; var CloseAction: TCloseAction);
begin
  FSettings.Save;
end;

procedure TMainForm.WMMove(var Msg: TWMMove);
begin
  inherited;
  if FBrowser <> nil then
    FBrowser.NotifyParentWindowPositionChanged;
end;

procedure TMainForm.WMMoving(var Msg: TMessage);
begin
  inherited;
  if FBrowser <> nil then
    FBrowser.NotifyParentWindowPositionChanged;
end;

initialization
  GlobalWebView2Loader := TWVLoader.Create(nil);
  GlobalWebView2Loader.UserDataFolder := UTF8Decode(GetEnvironmentVariable('APPDATA') + '\MolMDReader\webview');
  GlobalWebView2Loader.StartWebView2;

end.
