unit fMain;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, ComCtrls, StdCtrls, Dialogs, Menus,
  Types, LCLType, LCLIntf, LazUTF8, Messages, Windows, fpjson, jsonparser,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVBrowserBase, uWVTypes, uWVEvents,
  uWVCoreWebView2Args, uWVTypeLibrary,
  uSettings, uFileTree, uNavHistory, uMdPrepare, uMdRender, uSearch;

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
    FThemeFg, FThemePanelBg: TColor;
    FSearchEdit: TEdit;
    FThemeCombo: TComboBox;
    FScopeCombo: TComboBox;
    FResultList: TListBox;
    FSearchTimer: TTimer;
    FSearchThread: TSearchThread;
    FHits: TSearchHitArray;
    procedure SearchEditChange(Sender: TObject);
    procedure SearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SearchTimerTick(Sender: TObject);
    procedure SearchDone(const Hits: TSearchHitArray);
    procedure ScopeChange(Sender: TObject);
    procedure ResultClick(Sender: TObject);
    procedure ShowResults(Visible: Boolean);
    procedure StartSearch;
    procedure CancelSearch;
    procedure FormKeyDownHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ThemeChange(Sender: TObject);
    procedure TreeAdvancedDraw(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
    procedure StatusDrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel; const ARect: TRect);
    procedure ApplyTheme;
    procedure FocusSearch;
    procedure DoRefresh;
    procedure ShowRuntimeMissing;
    procedure BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure BrowserAccelerator(Sender: TObject; const aController: ICoreWebView2Controller; const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
    procedure BuildUi;
    procedure ApplyCommandLineFile;
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

function SetWindowTheme(hwnd: HWND; pszSubAppName, pszSubIdList: PWideChar): HRESULT; stdcall; external 'uxtheme.dll';

const
  TVM_SETBKCOLOR = $111D;
  TVM_SETTEXTCOLOR = $111E;
  WelcomeMd ='# MolMDReader'#10#10 + 'Kies een map met markdown-bestanden via **Map openen...** bovenaan.';

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
  ApplyCommandLineFile;
  FHistory := TNavHistory.Create;
  if FSettings.CurrentFile <> '' then
    FHistory.Visit(FSettings.CurrentFile);
  BuildUi;
  OnClose := FormCloseHandler;
  if FSettings.RootDir <> '' then
    LoadTree;
  RefreshFavorites;
  UpdateNavButtons;
  UpdateStatus;
  ApplyTheme;
end;

destructor TMainForm.Destroy;
begin
  FSettings.Free;
  FHistory.Free;
  FTree.Free;
  inherited;
end;

procedure TMainForm.ApplyCommandLineFile;
var
  F, Dir: string;
begin
  if ParamCount < 1 then
    Exit;
  F := ParamStrUTF8(1);
  if (F = '') or (F[1] = '-') or not FileExists(F) or not IsMdFileName(F) then
    Exit;
  F := ExpandFileName(F);
  Dir := ExtractFileDir(F);
  if (FSettings.RootDir = '') or (Pos(LowerCase(FSettings.RootDir + '\'), LowerCase(F)) <> 1) then
    FSettings.RootDir := Dir;
  FSettings.CurrentDir := Dir;
  FSettings.CurrentFile := F;
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
  FStatus.Panels[0].Style := psOwnerDraw;
  FStatus.Panels[1].Style := psOwnerDraw;
  FStatus.Panels[2].Style := psOwnerDraw;
  FStatus.OnDrawPanel := StatusDrawPanel;

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

  FScopeCombo := TComboBox.Create(Self);
  FScopeCombo.Parent := FTopPanel;
  FScopeCombo.SetBounds(236, 9, 130, 26);
  FScopeCombo.Style := csDropDownList;
  FScopeCombo.Items.Add('Huidige map');
  FScopeCombo.Items.Add('Alles');
  if FSettings.SearchAll then
    FScopeCombo.ItemIndex := 1
  else
    FScopeCombo.ItemIndex := 0;
  FScopeCombo.OnChange := ScopeChange;

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FTopPanel;
  FSearchEdit.SetBounds(374, 9, 420, 26);
  FSearchEdit.TextHint := 'Zoeken (Ctrl+F)...';
  FSearchEdit.OnChange := SearchEditChange;
  FSearchEdit.OnKeyDown := SearchEditKeyDown;

  FThemeCombo := TComboBox.Create(Self);
  FThemeCombo.Parent := FTopPanel;
  FThemeCombo.SetBounds(802, 9, 110, 26);
  FThemeCombo.Style := csDropDownList;
  FThemeCombo.Items.Add('Systeem');
  FThemeCombo.Items.Add('Licht');
  FThemeCombo.Items.Add('Donker');
  FThemeCombo.ItemIndex := Ord(FSettings.Theme);
  FThemeCombo.Hint := 'Thema';
  FThemeCombo.ShowHint := True;
  FThemeCombo.OnChange := ThemeChange;

  KeyPreview := True;
  OnKeyDown := FormKeyDownHandler;

  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Enabled := False;
  FSearchTimer.Interval := 300;
  FSearchTimer.OnTimer := SearchTimerTick;

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
  FTreeView.OnAdvancedCustomDrawItem := TreeAdvancedDraw;

  FResultList := TListBox.Create(Self);
  FResultList.Parent := FLeftPanel;
  FResultList.Align := alClient;
  FResultList.BorderStyle := bsNone;
  FResultList.Visible := False;
  FResultList.OnClick := ResultClick;

  FBrowser := TWVBrowser.Create(Self);
  FBrowserParent := TWVWindowParent.Create(Self);
  FBrowserParent.Parent := Self;
  FBrowserParent.Align := alClient;
  FBrowserParent.Browser := FBrowser;
  FBrowser.OnAfterCreated := BrowserAfterCreated;
  FBrowser.OnWebMessageReceived := BrowserWebMessage;
  FBrowser.OnNavigationStarting := BrowserNavStarting;
  FBrowser.OnNewWindowRequested := BrowserNewWindow;
  FBrowser.OnInitializationError := BrowserInitError;
  FBrowser.OnAcceleratorKeyPressed := BrowserAccelerator;

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
  ApplyTheme;
  TryCreateBrowser;
end;

procedure TMainForm.TryCreateBrowser;
begin
  if GlobalWebView2Loader.InitializationError then
    ShowRuntimeMissing
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
    I := FFavList.ItemAtPos(Types.Point(X, Y), True);
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
  CancelSearch;
  FSettings.Save;
end;

procedure TMainForm.ShowResults(Visible: Boolean);
begin
  FResultList.Visible := Visible;
  FTreeView.Visible := not Visible;
end;

procedure TMainForm.CancelSearch;
begin
  FSearchTimer.Enabled := False;
  if FSearchThread <> nil then
  begin
    FSearchThread.Cancel;
    FSearchThread := nil;
  end;
end;

procedure TMainForm.SearchEditChange(Sender: TObject);
begin
  CancelSearch;
  if Trim(FSearchEdit.Text) = '' then
  begin
    SetLength(FHits, 0);
    ShowResults(False);
    Exit;
  end;
  FSearchTimer.Enabled := True;
end;

procedure TMainForm.SearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    FSearchEdit.Text := '';
    Key := 0;
  end;
end;

procedure TMainForm.FocusSearch;
begin
  FSearchEdit.SetFocus;
  FSearchEdit.SelectAll;
end;

procedure TMainForm.DoRefresh;
begin
  if FSettings.RootDir = '' then
    Exit;
  LoadTree;
  if (FSettings.CurrentFile <> '') and FileExists(FSettings.CurrentFile) then
    RenderFile(FSettings.CurrentFile, '');
  UpdateStatus;
end;

procedure TMainForm.FormKeyDownHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('F')) and (ssCtrl in Shift) then
  begin
    FocusSearch;
    Key := 0;
  end
  else if (Key = VK_LEFT) and (ssAlt in Shift) then
  begin
    BackClick(nil);
    Key := 0;
  end
  else if (Key = VK_RIGHT) and (ssAlt in Shift) then
  begin
    ForwardClick(nil);
    Key := 0;
  end
  else if Key = VK_F5 then
  begin
    DoRefresh;
    Key := 0;
  end;
end;

procedure TMainForm.BrowserAccelerator(Sender: TObject; const aController: ICoreWebView2Controller; const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
var
  A: TCoreWebView2AcceleratorKeyPressedEventArgs;
  VK: LongWord;
  Ctrl, Alt: Boolean;
begin
  A := TCoreWebView2AcceleratorKeyPressedEventArgs.Create(aArgs);
  try
    if (A.KeyEventKind <> COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN) and
       (A.KeyEventKind <> COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN) then
      Exit;
    VK := A.VirtualKey;
    Ctrl := GetKeyState(VK_CONTROL) < 0;
    Alt := GetKeyState(VK_MENU) < 0;
    if Ctrl and (VK = Ord('F')) then
    begin
      A.Handled := True;
      FocusSearch;
    end
    else if Alt and (VK = VK_LEFT) then
    begin
      A.Handled := True;
      BackClick(nil);
    end
    else if Alt and (VK = VK_RIGHT) then
    begin
      A.Handled := True;
      ForwardClick(nil);
    end
    else if VK = VK_F5 then
    begin
      A.Handled := True;
      DoRefresh;
    end;
  finally
    A.Free;
  end;
end;

procedure TMainForm.ShowRuntimeMissing;
const
  RuntimeUrl = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';
begin
  if Application.MessageBox(
    PChar('MolMDReader heeft de Microsoft Edge WebView2-runtime nodig, maar die kon niet worden gestart.' + LineEnding + LineEnding +
      'Wil je de downloadpagina openen?'), 'WebView2-runtime ontbreekt', MB_YESNO or MB_ICONERROR) = IDYES then
    OpenURL(RuntimeUrl);
  Application.Terminate;
end;

procedure TMainForm.BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  ShowRuntimeMissing;
end;

procedure TMainForm.ThemeChange(Sender: TObject);
begin
  FSettings.Theme := TThemeMode(FThemeCombo.ItemIndex);
  FSettings.Save;
  ApplyTheme;
  if FBrowserReady then
  begin
    if (FSettings.CurrentFile <> '') and FileExists(FSettings.CurrentFile) then
      RenderFile(FSettings.CurrentFile, '')
    else
      ShowMessagePage(WelcomeMd);
  end;
end;

procedure TMainForm.ApplyTheme;
var
  Dark: Boolean;
  Bg, PanelBg, Fg: TColor;
begin
  Dark := ResolveDark(FSettings.Theme);
  if Dark then
  begin
    Bg := TColor($211D1B);
    PanelBg := TColor($2C2724);
    Fg := TColor($E8E4E1);
  end
  else
  begin
    Bg := clWindow;
    PanelBg := clBtnFace;
    Fg := clWindowText;
  end;
  Color := PanelBg;
  Font.Color := Fg;
  FTopPanel.Color := PanelBg;
  FLeftPanel.Color := PanelBg;
  FFavPanel.Color := PanelBg;
  FFavHeader.Color := PanelBg;
  FFavHeader.Font.Color := Fg;
  FFavList.Color := Bg;
  FFavList.Font.Color := Fg;
  FTreeView.Color := Bg;
  FTreeView.Font.Color := Fg;
  FResultList.Color := Bg;
  FResultList.Font.Color := Fg;
  // native edit/combo controls keep system colors so their text stays readable
  FSearchEdit.ParentColor := False;
  FSearchEdit.Color := clWindow;
  FSearchEdit.Font.Color := clWindowText;
  FScopeCombo.ParentColor := False;
  FScopeCombo.Color := clWindow;
  FScopeCombo.Font.Color := clWindowText;
  FThemeCombo.ParentColor := False;
  FThemeCombo.Color := clWindow;
  FThemeCombo.Font.Color := clWindowText;
  FThemeFg := Fg;
  FThemePanelBg := PanelBg;
  FStatus.Invalidate;
  if FTreeView.HandleAllocated then
  begin
    if Dark then
      SetWindowTheme(FTreeView.Handle, '', '')
    else
      SetWindowTheme(FTreeView.Handle, 'Explorer', nil);
    SendMessage(FTreeView.Handle, TVM_SETTEXTCOLOR, 0, LPARAM(ColorToRGB(Fg)));
    SendMessage(FTreeView.Handle, TVM_SETBKCOLOR, 0, LPARAM(ColorToRGB(Bg)));
  end;
  FTreeView.Invalidate;
end;


procedure TMainForm.TreeAdvancedDraw(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
  Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
begin
  if Stage = cdPrePaint then
  begin
    if cdsSelected in State then
      Sender.Canvas.Font.Color := clHighlightText
    else
      Sender.Canvas.Font.Color := FThemeFg;
  end;
  DefaultDraw := True;
end;

procedure TMainForm.StatusDrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel; const ARect: TRect);
begin
  StatusBar.Canvas.Brush.Color := FThemePanelBg;
  StatusBar.Canvas.FillRect(ARect);
  StatusBar.Canvas.Font.Color := FThemeFg;
  StatusBar.Canvas.TextOut(ARect.Left + 4, ARect.Top + 2, Panel.Text);
end;

procedure TMainForm.ScopeChange(Sender: TObject);
begin
  FSettings.SearchAll := FScopeCombo.ItemIndex = 1;
  FSettings.Save;
  if Trim(FSearchEdit.Text) <> '' then
    StartSearch;
end;

procedure TMainForm.SearchTimerTick(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  StartSearch;
end;

procedure TMainForm.StartSearch;
var
  Dir: string;
begin
  CancelSearch;
  if FSettings.RootDir = '' then
    Exit;
  if FSettings.SearchAll or (FSettings.CurrentDir = '') then
    Dir := FSettings.RootDir
  else
    Dir := FSettings.CurrentDir;
  FSearchThread := TSearchThread.Create(Dir, Trim(FSearchEdit.Text), SearchDone);
end;

procedure TMainForm.SearchDone(const Hits: TSearchHitArray);
var
  I: Integer;
  Line: string;
begin
  FSearchThread := nil;
  FHits := Hits;
  FResultList.Items.BeginUpdate;
  try
    FResultList.Items.Clear;
    for I := 0 to High(FHits) do
    begin
      Line := ExtractRelativePath(IncludeTrailingPathDelimiter(FSettings.RootDir), FHits[I].FilePath);
      if FHits[I].NameMatch then
        Line := Line + '   (bestandsnaam)'
      else
        Line := Line + ':' + IntToStr(FHits[I].Line) + '   ' + FHits[I].Snippet;
      FResultList.Items.Add(Line);
    end;
    if Length(FHits) = 0 then
      FResultList.Items.Add('Geen resultaten');
  finally
    FResultList.Items.EndUpdate;
  end;
  ShowResults(True);
end;

procedure TMainForm.ResultClick(Sender: TObject);
begin
  if (FResultList.ItemIndex >= 0) and (FResultList.ItemIndex <= High(FHits)) then
    OpenFile(FHits[FResultList.ItemIndex].FilePath, True);
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
  GlobalWebView2Loader.UserDataFolder := UTF8Decode(SysUtils.GetEnvironmentVariable('APPDATA') + '\MolMDReader\webview');
  GlobalWebView2Loader.StartWebView2;

end.
