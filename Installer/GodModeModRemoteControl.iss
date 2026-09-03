#ifndef AppVersion
  #define AppVersion "0.3.1"
#endif
#ifndef PublishDir
  #error PublishDir must point to the dotnet publish directory
#endif
#ifndef ModBinary
  #error ModBinary must point to GTARemoteBridge.asi
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define AppName "GodMode Mod Remote Control"
#define AppExe "GodMode Mod Remote Control.exe"
#define ScriptHookUrl "https://www.dev-c.com/gtav/scripthookv/"

[Setup]
AppId={{73D45E77-0843-49FD-BCF1-58B146BB8B88}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Matteo Zampieri
AppPublisherURL=https://github.com/themattvision/GTA-V-Remote-Control-God-Mode-Mod
AppSupportURL=https://github.com/themattvision/GTA-V-Remote-Control-God-Mode-Mod/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Windows-GodMode-Mod-Remote-Control-Setup-v{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#AppExe}
SetupLogging=yes

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
italian.DesktopIcon=Crea un collegamento sul desktop
english.DesktopIcon=Create a desktop shortcut
italian.LinksGroup=Collegamenti:
english.LinksGroup=Shortcuts:
italian.AutoStart=Avvia automaticamente il bridge all'accesso a Windows
english.AutoStart=Start the bridge automatically when you sign in to Windows
italian.StartupGroup=Avvio automatico:
english.StartupGroup=Automatic startup:
italian.ConfigureGtaStatus=Configurazione del percorso di GTA V...
english.ConfigureGtaStatus=Configuring the GTA V folder...
italian.UpdateFirewallStatus=Aggiornamento del firewall...
english.UpdateFirewallStatus=Updating the firewall...
italian.ConfigureNetworkStatus=Configurazione della rete locale...
english.ConfigureNetworkStatus=Configuring the local network...
italian.LaunchApp=Avvia %1
english.LaunchApp=Launch %1
italian.GtaTitle=Dove si trova GTA V Legacy?
english.GtaTitle=Where is GTA V Legacy installed?
italian.GtaSubtitle=Seleziona la cartella che contiene GTA5.exe.
english.GtaSubtitle=Select the folder that contains GTA5.exe.
italian.GtaDescription=L'installer prova a trovarla automaticamente. Se il percorso non è corretto, scegli la cartella principale di GTA V Legacy.
english.GtaDescription=The installer tries to find it automatically. If the path is incorrect, select the main GTA V Legacy folder.
italian.GtaPathLabel=Cartella di GTA V Legacy:
english.GtaPathLabel=GTA V Legacy folder:
italian.ScriptHookTitle=Componente ufficiale ScriptHook V
english.ScriptHookTitle=Official ScriptHook V component
italian.ScriptHookSubtitle=Serve per caricare la mod dentro GTA V in Modalità Storia.
english.ScriptHookSubtitle=It is required to load the mod in GTA V Story Mode.
italian.ScriptHookDescription=Per licenza non possiamo includerlo nel nostro installer. Premi il collegamento, scarica lo ZIP ufficiale e torna qui: il file viene riconosciuto automaticamente.
english.ScriptHookDescription=Its license does not allow us to include it in this installer. Open the link, download the official ZIP, then return here: the file is detected automatically.
italian.ScriptHookArchiveLabel=Archivio ScriptHook V:
english.ScriptHookArchiveLabel=ScriptHook V archive:
italian.ScriptHookDownload=Scarica ScriptHook V dal sito ufficiale
english.ScriptHookDownload=Download ScriptHook V from the official website
italian.SafetyTitle=Modalità Storia e backup
english.SafetyTitle=Story Mode and backups
italian.SafetySubtitle=La mod non supporta GTA Online.
english.SafetySubtitle=The mod does not support GTA Online.
italian.SafetyDescription=Chiudi completamente GTA V prima di continuare. L'installer crea una copia dei file già presenti prima di sostituirli.
english.SafetyDescription=Close GTA V completely before continuing. The installer backs up existing files before replacing them.
italian.SafetyConfirm=Ho chiuso GTA V e userò la mod soltanto in Modalità Storia.
english.SafetyConfirm=I closed GTA V and will use the mod in Story Mode only.
italian.InvalidGtaDirectory=La cartella scelta non contiene GTA5.exe. Seleziona la cartella principale di GTA V Legacy.
english.InvalidGtaDirectory=The selected folder does not contain GTA5.exe. Select the main GTA V Legacy folder.
italian.MissingScriptHookSelection=Scarica lo ZIP ufficiale di ScriptHook V e selezionalo qui. Non devi estrarlo né copiare file a mano.
english.MissingScriptHookSelection=Download the official ScriptHook V ZIP and select it here. You do not need to extract it or copy files manually.
italian.SafetyNotConfirmed=Conferma di aver chiuso GTA V e di usare la mod soltanto in Modalità Storia.
english.SafetyNotConfirmed=Confirm that GTA V is closed and that you will use the mod in Story Mode only.
italian.GtaStillRunning=GTA V è ancora aperto. Salva la partita, chiudi il gioco e riprova.
english.GtaStillRunning=GTA V is still running. Save your game, close it, and try again.
italian.ScriptHookNotFound=Non trovo lo ZIP ufficiale di ScriptHook V. Torna indietro e selezionalo.
english.ScriptHookNotFound=The official ScriptHook V ZIP was not found. Go back and select it.
italian.ScriptHookExtractFailed=Lo ZIP selezionato non può essere estratto. Scaricalo di nuovo dal sito ufficiale di ScriptHook V.
english.ScriptHookExtractFailed=The selected ZIP could not be extracted. Download it again from the official ScriptHook V website.
italian.ScriptHookContentsInvalid=Lo ZIP non contiene i file ufficiali attesi: ScriptHookV.dll, dinput8.dll e NativeTrainer.asi.
english.ScriptHookContentsInvalid=The ZIP does not contain the expected official files: ScriptHookV.dll, dinput8.dll, and NativeTrainer.asi.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; GroupDescription: "{cm:LinksGroup}"; Flags: unchecked
Name: "autostart"; Description: "{cm:AutoStart}"; GroupDescription: "{cm:StartupGroup}"; Flags: checkedonce

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#ModBinary}"; DestDir: "{code:GetGtaDirectory}"; DestName: "GTARemoteBridge.asi"; Flags: ignoreversion uninsneveruninstall
Source: "{code:GetScriptHookFile|ScriptHookV.dll}"; DestDir: "{code:GetGtaDirectory}"; DestName: "ScriptHookV.dll"; Flags: external ignoreversion uninsneveruninstall; Check: ShouldInstallScriptHook
Source: "{code:GetScriptHookFile|dinput8.dll}"; DestDir: "{code:GetGtaDirectory}"; DestName: "dinput8.dll"; Flags: external ignoreversion uninsneveruninstall; Check: ShouldInstallScriptHook
Source: "{code:GetScriptHookFile|NativeTrainer.asi}"; DestDir: "{code:GetGtaDirectory}"; DestName: "NativeTrainer.asi"; Flags: external ignoreversion uninsneveruninstall; Check: ShouldInstallScriptHook

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "GodModeModRemoteControl"; ValueData: """{app}\{#AppExe}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#AppExe}"; Parameters: "--configure-gta ""{code:GetGtaDirectory}"""; Flags: runhidden waituntilterminated; StatusMsg: "{cm:ConfigureGtaStatus}"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#AppName}"""; Flags: runhidden waituntilterminated; StatusMsg: "{cm:UpdateFirewallStatus}"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#AppName}"" dir=in action=allow program=""{app}\{#AppExe}"" enable=yes profile=private"; Flags: runhidden waituntilterminated; StatusMsg: "{cm:ConfigureNetworkStatus}"
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchApp,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#AppName}"""; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\{#AppName}"

[Code]
var
  GtaPage: TInputDirWizardPage;
  ScriptHookPage: TInputFileWizardPage;
  SafetyPage: TInputOptionWizardPage;
  ScriptHookExtractDirectory: String;
  InstallScriptHook: Boolean;
  BackupDirectory: String;
  PreviousModBackup: String;
  DownloadLink: TNewStaticText;

function IsValidGtaDirectory(const Directory: String): Boolean;
begin
  Result := (Directory <> '') and FileExists(AddBackslash(Directory) + 'GTA5.exe');
end;

function FirstValidGtaDirectory: String;
var
  Candidate: String;
begin
  Result := ExpandConstant('{param:GTAPath|}');
  if IsValidGtaDirectory(Result) then Exit;

  if RegQueryStringValue(HKLM64, 'SOFTWARE\Rockstar Games\Grand Theft Auto V', 'InstallFolder', Candidate) and IsValidGtaDirectory(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;
  if RegQueryStringValue(HKLM32, 'SOFTWARE\Rockstar Games\Grand Theft Auto V', 'InstallFolder', Candidate) and IsValidGtaDirectory(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  Candidate := ExpandConstant('{autopf}\Rockstar Games\Grand Theft Auto V');
  if IsValidGtaDirectory(Candidate) then begin Result := Candidate; Exit; end;
  Candidate := ExpandConstant('{autopf32}\Steam\steamapps\common\Grand Theft Auto V');
  if IsValidGtaDirectory(Candidate) then begin Result := Candidate; Exit; end;
  Candidate := ExpandConstant('{autopf}\Epic Games\GTAV');
  if IsValidGtaDirectory(Candidate) then begin Result := Candidate; Exit; end;
  Result := '';
end;

function HasCompleteScriptHook(const Directory: String): Boolean;
begin
  Result := FileExists(AddBackslash(Directory) + 'ScriptHookV.dll') and
    FileExists(AddBackslash(Directory) + 'dinput8.dll') and
    FileExists(AddBackslash(Directory) + 'NativeTrainer.asi');
end;

function GetDownloadsDirectory: String;
begin
  if not RegQueryStringValue(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',
    '{374DE290-123F-4565-9164-39C4925E467B}', Result) then
    Result := AddBackslash(GetEnv('USERPROFILE')) + 'Downloads';
  StringChangeEx(Result, '%USERPROFILE%', GetEnv('USERPROFILE'), True);
  StringChangeEx(Result, '%HOMEDRIVE%', GetEnv('HOMEDRIVE'), True);
  StringChangeEx(Result, '%HOMEPATH%', GetEnv('HOMEPATH'), True);
end;

function FindDownloadedScriptHook: String;
var
  FindRec: TFindRec;
  Pattern: String;
  DownloadsDirectory: String;
begin
  Result := '';
  DownloadsDirectory := GetDownloadsDirectory;
  Pattern := AddBackslash(DownloadsDirectory) + 'ScriptHookV_*.zip';
  if FindFirst(Pattern, FindRec) then
  begin
    try
      repeat
        if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
        begin
          Result := AddBackslash(DownloadsDirectory) + FindRec.Name;
          Exit;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

procedure OpenScriptHookDownload(Sender: TObject);
var
  ErrorCode: Integer;
begin
  ShellExec('open', '{#ScriptHookUrl}', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;

procedure InitializeWizard;
begin
  GtaPage := CreateInputDirPage(wpSelectDir,
    ExpandConstant('{cm:GtaTitle}'),
    ExpandConstant('{cm:GtaSubtitle}'),
    ExpandConstant('{cm:GtaDescription}'),
    False, '');
  GtaPage.Add(ExpandConstant('{cm:GtaPathLabel}'));
  GtaPage.Values[0] := FirstValidGtaDirectory;

  ScriptHookPage := CreateInputFilePage(GtaPage.ID,
    ExpandConstant('{cm:ScriptHookTitle}'),
    ExpandConstant('{cm:ScriptHookSubtitle}'),
    ExpandConstant('{cm:ScriptHookDescription}'));
  ScriptHookPage.Add(ExpandConstant('{cm:ScriptHookArchiveLabel}'), 'ZIP (*.zip)|*.zip', '.zip');
  ScriptHookPage.Values[0] := FindDownloadedScriptHook;

  DownloadLink := TNewStaticText.Create(ScriptHookPage.Surface);
  DownloadLink.Parent := ScriptHookPage.Surface;
  DownloadLink.Caption := ExpandConstant('{cm:ScriptHookDownload}');
  DownloadLink.Font.Color := clBlue;
  DownloadLink.Font.Style := [fsUnderline];
  DownloadLink.Cursor := crHand;
  DownloadLink.Top := ScriptHookPage.Edits[0].Top + ScriptHookPage.Edits[0].Height + ScaleY(18);
  DownloadLink.Left := ScriptHookPage.Edits[0].Left;
  DownloadLink.OnClick := @OpenScriptHookDownload;

  SafetyPage := CreateInputOptionPage(ScriptHookPage.ID,
    ExpandConstant('{cm:SafetyTitle}'),
    ExpandConstant('{cm:SafetySubtitle}'),
    ExpandConstant('{cm:SafetyDescription}'),
    True, False);
  SafetyPage.Add(ExpandConstant('{cm:SafetyConfirm}'));
  { A silent install already represents an explicit acceptance of this warning. }
  SafetyPage.Values[0] := WizardSilent;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = ScriptHookPage.ID) and HasCompleteScriptHook(GtaPage.Values[0]);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = GtaPage.ID then
  begin
    if not IsValidGtaDirectory(GtaPage.Values[0]) then
    begin
      MsgBox(ExpandConstant('{cm:InvalidGtaDirectory}'), mbError, MB_OK);
      Result := False;
      Exit;
    end;
    if ScriptHookPage.Values[0] = '' then ScriptHookPage.Values[0] := FindDownloadedScriptHook;
  end;

  if CurPageID = ScriptHookPage.ID then
  begin
    if ScriptHookPage.Values[0] = '' then ScriptHookPage.Values[0] := FindDownloadedScriptHook;
    if not FileExists(ScriptHookPage.Values[0]) then
    begin
      MsgBox(ExpandConstant('{cm:MissingScriptHookSelection}'), mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  if (CurPageID = SafetyPage.ID) and not SafetyPage.Values[0] then
  begin
    MsgBox(ExpandConstant('{cm:SafetyNotConfirmed}'), mbError, MB_OK);
    Result := False;
  end;
end;

function PowerShellQuote(const Value: String): String;
begin
  Result := Value;
  StringChangeEx(Result, '''', '''''', True);
  Result := '''' + Result + '''';
end;

procedure BackupIfPresent(const FileName: String);
var
  SourcePath: String;
begin
  SourcePath := AddBackslash(GtaPage.Values[0]) + FileName;
  if FileExists(SourcePath) then
  begin
    ForceDirectories(BackupDirectory);
    FileCopy(SourcePath, AddBackslash(BackupDirectory) + FileName, False);
    if FileName = 'GTARemoteBridge.asi' then
      PreviousModBackup := AddBackslash(BackupDirectory) + FileName;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  ArchivePath: String;
  PowerShellArguments: String;
begin
  Result := '';
  if Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -Command "if (Get-Process GTA5 -ErrorAction SilentlyContinue) { exit 10 }"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 10) then
  begin
    Result := ExpandConstant('{cm:GtaStillRunning}');
    Exit;
  end;

  BackupDirectory := AddBackslash(ExpandConstant('{commonappdata}\{#AppName}\Backups')) + GetDateTimeString('yyyymmdd-hhnnss', '-', ':');
  BackupIfPresent('GTARemoteBridge.asi');
  BackupIfPresent('ScriptHookV.dll');
  BackupIfPresent('dinput8.dll');
  BackupIfPresent('NativeTrainer.asi');

  InstallScriptHook := not HasCompleteScriptHook(GtaPage.Values[0]);
  if not InstallScriptHook then Exit;

  ArchivePath := ScriptHookPage.Values[0];
  if ArchivePath = '' then ArchivePath := FindDownloadedScriptHook;
  if not FileExists(ArchivePath) then
  begin
    Result := ExpandConstant('{cm:ScriptHookNotFound}');
    Exit;
  end;

  ScriptHookExtractDirectory := ExpandConstant('{tmp}\GodModeModRemoteControl-ScriptHookV');
  DelTree(ScriptHookExtractDirectory, True, True, True);
  ForceDirectories(ScriptHookExtractDirectory);
  PowerShellArguments := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath ' +
    PowerShellQuote(ArchivePath) + ' -DestinationPath ' + PowerShellQuote(ScriptHookExtractDirectory) + ' -Force"';
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), PowerShellArguments,
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
  begin
    Result := ExpandConstant('{cm:ScriptHookExtractFailed}');
    Exit;
  end;

  if not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\ScriptHookV.dll') or
    not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\dinput8.dll') or
    not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\NativeTrainer.asi') then
  begin
    Result := ExpandConstant('{cm:ScriptHookContentsInvalid}');
  end;
end;

function GetGtaDirectory(Param: String): String;
begin
  Result := GtaPage.Values[0];
end;

function GetScriptHookFile(Param: String): String;
begin
  Result := AddBackslash(ScriptHookExtractDirectory) + 'bin\' + Param;
end;

function ShouldInstallScriptHook: Boolean;
begin
  Result := InstallScriptHook;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Marker: String;
begin
  if CurStep = ssPostInstall then
  begin
    Marker := '[Install]' + #13#10 +
      'GtaDirectory=' + GtaPage.Values[0] + #13#10 +
      'PreviousModBackup=' + PreviousModBackup + #13#10 +
      'Version={#AppVersion}' + #13#10;
    ForceDirectories(ExpandConstant('{commonappdata}\{#AppName}'));
    SaveStringToFile(ExpandConstant('{commonappdata}\{#AppName}\install.ini'), Marker, False);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  GtaDirectory: String;
  ModBackup: String;
  ModPath: String;
begin
  if CurUninstallStep <> usUninstall then Exit;
  GtaDirectory := GetIniString('Install', 'GtaDirectory', '', ExpandConstant('{commonappdata}\{#AppName}\install.ini'));
  if GtaDirectory = '' then Exit;

  ModPath := AddBackslash(GtaDirectory) + 'GTARemoteBridge.asi';
  ModBackup := GetIniString('Install', 'PreviousModBackup', '', ExpandConstant('{commonappdata}\{#AppName}\install.ini'));
  if (ModBackup <> '') and FileExists(ModBackup) then
    FileCopy(ModBackup, ModPath, False)
  else
    DeleteFile(ModPath);

  DeleteFile(AddBackslash(GtaDirectory) + 'GTARemoteBridge.command');
  DeleteFile(AddBackslash(GtaDirectory) + 'GTARemoteBridge.state');
  DeleteFile(AddBackslash(GtaDirectory) + 'GTARemoteBridge.state.tmp');
end;
