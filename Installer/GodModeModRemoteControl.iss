#ifndef AppVersion
  #define AppVersion "0.3.0"
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

[Tasks]
Name: "desktopicon"; Description: "Crea un collegamento sul desktop"; GroupDescription: "Collegamenti:"; Flags: unchecked
Name: "autostart"; Description: "Avvia automaticamente il bridge all'accesso a Windows"; GroupDescription: "Avvio automatico:"; Flags: checkedonce

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
Filename: "{app}\{#AppExe}"; Parameters: "--configure-gta ""{code:GetGtaDirectory}"""; Flags: runhidden waituntilterminated; StatusMsg: "Configurazione del percorso di GTA V..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#AppName}"""; Flags: runhidden waituntilterminated; StatusMsg: "Aggiornamento del firewall..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#AppName}"" dir=in action=allow program=""{app}\{#AppExe}"" enable=yes profile=private"; Flags: runhidden waituntilterminated; StatusMsg: "Configurazione della rete locale..."
Filename: "{app}\{#AppExe}"; Description: "Avvia {#AppName}"; Flags: nowait postinstall skipifsilent

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
    'Dove si trova GTA V Legacy?',
    'Seleziona la cartella che contiene GTA5.exe.',
    'L''installer prova a trovarla automaticamente. Se il percorso non è corretto, scegli la cartella principale di GTA V Legacy.');
  GtaPage.Add('Cartella di GTA V Legacy:');
  GtaPage.Values[0] := FirstValidGtaDirectory;

  ScriptHookPage := CreateInputFilePage(GtaPage.ID,
    'Componente ufficiale ScriptHook V',
    'Serve per caricare la mod dentro GTA V in Modalità Storia.',
    'Per licenza non possiamo includerlo nel nostro installer. Premi il collegamento, scarica lo ZIP ufficiale e torna qui: il file viene riconosciuto automaticamente.');
  ScriptHookPage.Add('Archivio ScriptHook V:', 'ZIP (*.zip)|*.zip', '.zip');
  ScriptHookPage.Values[0] := FindDownloadedScriptHook;

  DownloadLink := TNewStaticText.Create(ScriptHookPage.Surface);
  DownloadLink.Parent := ScriptHookPage.Surface;
  DownloadLink.Caption := 'Scarica ScriptHook V dal sito ufficiale';
  DownloadLink.Font.Color := clBlue;
  DownloadLink.Font.Style := [fsUnderline];
  DownloadLink.Cursor := crHand;
  DownloadLink.Top := ScriptHookPage.Edits[0].Top + ScriptHookPage.Edits[0].Height + ScaleY(18);
  DownloadLink.Left := ScriptHookPage.Edits[0].Left;
  DownloadLink.OnClick := @OpenScriptHookDownload;

  SafetyPage := CreateInputOptionPage(ScriptHookPage.ID,
    'Modalità Storia e backup',
    'La mod non supporta GTA Online.',
    'Chiudi completamente GTA V prima di continuare. L''installer crea una copia dei file già presenti prima di sostituirli.',
    True, False);
  SafetyPage.Add('Ho chiuso GTA V e userò la mod soltanto in Modalità Storia.');
  SafetyPage.Values[0] := False;
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
      MsgBox('La cartella scelta non contiene GTA5.exe. Seleziona la cartella principale di GTA V Legacy.', mbError, MB_OK);
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
      MsgBox('Scarica lo ZIP ufficiale di ScriptHook V e selezionalo qui. Non devi estrarlo né copiare file a mano.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  if (CurPageID = SafetyPage.ID) and not SafetyPage.Values[0] then
  begin
    MsgBox('Conferma di aver chiuso GTA V e di usare la mod soltanto in Modalità Storia.', mbError, MB_OK);
    Result := False;
  end;
end;

function PowerShellQuote(const Value: String): String;
begin
  Result := '''' + StringChangeEx(Value, '''', '''''', True) + '''';
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
    Result := 'GTA V è ancora aperto. Salva la partita, chiudi il gioco e riprova.';
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
    Result := 'Non trovo lo ZIP ufficiale di ScriptHook V. Torna indietro e selezionalo.';
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
    Result := 'Lo ZIP selezionato non può essere estratto. Scaricalo di nuovo dal sito ufficiale di ScriptHook V.';
    Exit;
  end;

  if not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\ScriptHookV.dll') or
    not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\dinput8.dll') or
    not FileExists(AddBackslash(ScriptHookExtractDirectory) + 'bin\NativeTrainer.asi') then
  begin
    Result := 'Lo ZIP non contiene i file ufficiali attesi: ScriptHookV.dll, dinput8.dll e NativeTrainer.asi.';
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
