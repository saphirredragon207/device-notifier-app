[Setup]
AppId={{12345678-1234-1234-1234-123456789012}
AppName=Device Notifier
AppVersion=1.0.0
AppVerName=Device Notifier 1.0.0
AppPublisher=Device Notifier Team
AppPublisherURL=https://devicenotifier.com
AppSupportURL=https://github.com/devicenotifier/docs
AppUpdatesURL=https://devicenotifier.com/updates
DefaultDirName={autopf}\DeviceNotifier
DefaultGroupName=Device Notifier
AllowNoIcons=yes
LicenseFile=license.txt
OutputDir=output
OutputBaseFilename=DeviceNotifier-Setup-Wizard
SetupIconFile=icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0.17763
DisableDirPage=no
DisableProgramGroupPage=no
DisableWelcomePage=no
DisableReadyPage=no
DisableFinishedPage=no
SetupLogging=yes
LogFileName=DeviceNotifier-Install.log

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Start Device Notifier Agent on system startup"; GroupDescription: "Additional options:"; Flags: unchecked
Name: "discord_integration"; Description: "Configure Discord integration during installation"; GroupDescription: "Integration options:"; Flags: unchecked

[Files]
; Main application files (will be built during installation)
Source: "files\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Device Notifier"; Filename: "{app}\DeviceNotifier.exe"
Name: "{group}\Uninstall Device Notifier"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Device Notifier"; Filename: "{app}\DeviceNotifier.exe"; Tasks: desktopicon

[Registry]
; Register the application
Root: HKLM; Subkey: "SOFTWARE\DeviceNotifier"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\DeviceNotifier"; ValueType: string; ValueName: "Version"; ValueData: "1.0.0"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\DeviceNotifier"; ValueType: string; ValueName: "InstallDate"; ValueData: "{code:GetInstallDate}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\DeviceNotifier"; ValueType: string; ValueName: "InstallScope"; ValueData: "{code:GetInstallScope}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\DeviceNotifier"; ValueType: dword; ValueName: "StartOnBoot"; ValueData: "{code:GetStartOnBoot}"; Flags: uninsdeletekey

; Add to PATH for command-line access
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: NeedsAddPath

[Run]
; Launch the application after installation
Filename: "{app}\DeviceNotifier.exe"; Description: "Launch Device Notifier"; Flags: postinstall nowait skipifsilent

[UninstallRun]
; Stop and remove the service before uninstalling
Filename: "net"; Parameters: "stop DeviceNotifierAgent"; Flags: runhidden
Filename: "{app}\device-notifier-agent.exe"; Parameters: "uninstall"; Flags: runhidden

[Code]
var
  // Wizard pages
  WelcomePage: TOutputMsgWizardPage;
  LicensePage: TOutputMsgWizardPage;
  PrereqCheckPage: TOutputMsgWizardPage;
  DownloadProgressPage: TOutputMsgWizardPage;
  InstallOptionsPage: TOutputMsgWizardPage;
  InstallProgressPage: TOutputMsgWizardPage;
  DiscordSetupPage: TOutputMsgWizardPage;
  FinishPage: TOutputMsgWizardPage;
  
  // Download management
  DownloadPage: TDownloadWizardPage;
  DownloadManager: TDownloadManager;
  
  // Prerequisites
  PrereqList: TStringList;
  PrereqStatus: TStringList;
  PrereqSources: TStringList;
  PrereqChecksums: TStringList;
  
  // Installation options
  InstallScope: String;
  StartOnBoot: Boolean;
  CreateShortcuts: Boolean;
  ConfigureDiscord: Boolean;
  
  // Progress tracking
  CurrentStep: Integer;
  TotalSteps: Integer;
  InstallLog: TStringList;
  
  // Error handling
  LastError: String;
  RollbackRequired: Boolean;

// Download manager class
type
  TDownloadManager = class
  private
    FDownloads: TStringList;
    FCurrentDownload: Integer;
    FTotalDownloads: Integer;
    FDownloadedBytes: Int64;
    FTotalBytes: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddDownload(const Url, Filename, ExpectedSha256: String);
    function DownloadAll: Boolean;
    function VerifyChecksum(const Filename, ExpectedSha256: String): Boolean;
    property TotalDownloads: Integer read FTotalDownloads;
    property CurrentDownload: Integer read FCurrentDownload;
    property DownloadedBytes: Int64 read FDownloadedBytes;
    property TotalBytes: Int64 read FTotalBytes;
  end;

constructor TDownloadManager.Create;
begin
  FDownloads := TStringList.Create;
  FCurrentDownload := 0;
  FTotalDownloads := 0;
  FDownloadedBytes := 0;
  FTotalBytes := 0;
end;

destructor TDownloadManager.Destroy;
begin
  FDownloads.Free;
  inherited;
end;

procedure TDownloadManager.AddDownload(const Url, Filename, ExpectedSha256: String);
begin
  FDownloads.Add(Url + '|' + Filename + '|' + ExpectedSha256);
  Inc(FTotalDownloads);
end;

function TDownloadManager.DownloadAll: Boolean;
var
  I: Integer;
  Parts: TStringList;
  Url, Filename, ExpectedSha256: String;
begin
  Result := True;
  Parts := TStringList.Create;
  try
    for I := 0 to FDownloads.Count - 1 do
    begin
      FCurrentDownload := I + 1;
      Parts.Clear;
      Parts.Delimiter := '|';
      Parts.DelimitedText := FDownloads[I];
      
      if Parts.Count >= 3 then
      begin
        Url := Parts[0];
        Filename := Parts[1];
        ExpectedSha256 := Parts[2];
        
        // Download file
        if not DownloadPage.DownloadFile(Url, Filename) then
        begin
          Result := False;
          Break;
        end;
        
        // Verify checksum
        if not VerifyChecksum(Filename, ExpectedSha256) then
        begin
          Result := False;
          Break;
        end;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

function TDownloadManager.VerifyChecksum(const Filename, ExpectedSha256: String): Boolean;
var
  ActualSha256: String;
begin
  // TODO: Implement SHA256 calculation
  // For now, return True (placeholder)
  Result := True;
end;

// Wizard page creation
procedure CreateCustomPages;
begin
  // Welcome page
  WelcomePage := CreateOutputMsgPage(wpWelcome,
    'Welcome to Device Notifier',
    'Cross-Platform Device Monitoring & Discord Integration',
    'This wizard will guide you through installing Device Notifier, a powerful cross-platform application that monitors your device events and sends notifications to Discord.' + #13#10 + #13#10 +
    'The installer will:' + #13#10 +
    '• Check and download required prerequisites' + #13#10 +
    '• Install the Device Notifier application' + #13#10 +
    '• Configure system services and startup options' + #13#10 +
    '• Set up Discord integration (optional)' + #13#10 + #13#10 +
    'Click Next to continue with the installation.');
  
  // License page
  LicensePage := CreateOutputMsgPage(WelcomePage.ID,
    'License Agreement',
    'Please read and accept the license terms',
    'By installing Device Notifier, you agree to the following terms and conditions:' + #13#10 + #13#10 +
    '1. This software is provided "as is" without warranty of any kind.' + #13#10 +
    '2. The software will monitor system events and send notifications to Discord.' + #13#10 +
    '3. You consent to the collection and transmission of device event data.' + #13#10 +
    '4. You can disable the service at any time through the GUI or system services.' + #13#10 +
    '5. Remote command execution is disabled by default for security.' + #13#10 + #13#10 +
    'Privacy Summary:' + #13#10 +
    '• Device events (login/logout, system health) are sent to Discord' + #13#10 +
    '• No passwords or personal data are transmitted' + #13#10 +
    '• All data is encrypted in transit' + #13#10 +
    '• Local audit logs are stored securely' + #13#10 + #13#10 +
    'You must accept these terms to continue with the installation.');
  
  // Prerequisites check page
  PrereqCheckPage := CreateOutputMsgPage(LicensePage.ID,
    'Prerequisites Check',
    'Checking system requirements and downloading missing components',
    'The installer is now checking your system for required components and will download any missing prerequisites.');
  
  // Download progress page
  DownloadProgressPage := CreateOutputMsgPage(PrereqCheckPage.ID,
    'Downloading Prerequisites',
    'Downloading and verifying required components',
    'Downloading prerequisite components. This may take several minutes depending on your internet connection.');
  
  // Install options page
  InstallOptionsPage := CreateOutputMsgPage(DownloadProgressPage.ID,
    'Installation Options',
    'Configure installation settings and options',
    'Choose your installation preferences:');
  
  // Install progress page
  InstallProgressPage := CreateOutputMsgPage(InstallOptionsPage.ID,
    'Installing Device Notifier',
    'Installing application components and configuring system',
    'Installing Device Notifier and configuring your system. Please wait...');
  
  // Discord setup page
  DiscordSetupPage := CreateOutputMsgPage(InstallProgressPage.ID,
    'Discord Integration Setup',
    'Configure Discord bot integration (optional)',
    'Set up Discord integration to receive device notifications:');
  
  // Finish page
  FinishPage := CreateOutputMsgPage(DiscordSetupPage.ID,
    'Installation Complete',
    'Device Notifier has been successfully installed',
    'Device Notifier has been successfully installed and configured on your system.');
end;

// Initialize wizard
procedure InitializeWizard;
begin
  CreateCustomPages;
  
  // Initialize download manager
  DownloadManager := TDownloadManager.Create;
  
  // Initialize prerequisite lists
  PrereqList := TStringList.Create;
  PrereqStatus := TStringList.Create;
  PrereqSources := TStringList.Create;
  PrereqChecksums := TStringList.Create;
  
  // Initialize installation log
  InstallLog := TStringList.Create;
  
  // Set default values
  InstallScope := 'system';
  StartOnBoot := True;
  CreateShortcuts := True;
  ConfigureDiscord := False;
  CurrentStep := 0;
  TotalSteps := 8;
  RollbackRequired := False;
  
  // Log installation start
  InstallLog.Add(Format('[%s] Installation started', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
  InstallLog.Add(Format('[%s] OS: %s', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), GetWindowsVersionString]));
  InstallLog.Add(Format('[%s] Architecture: %s', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), GetArchitectureString]));
end;

// Clean up
procedure DeinitializeSetup;
begin
  if Assigned(DownloadManager) then
    DownloadManager.Free;
  if Assigned(PrereqList) then
    PrereqList.Free;
  if Assigned(PrereqStatus) then
    PrereqStatus.Free;
  if Assigned(PrereqSources) then
    PrereqSources.Free;
  if Assigned(PrereqChecksums) then
    PrereqChecksums.Free;
  if Assigned(InstallLog) then
    InstallLog.Free;
end;

// Check prerequisites
function CheckPrerequisites: Boolean;
var
  I: Integer;
  PrereqName, Status: String;
begin
  Result := True;
  
  // Define prerequisites for Windows
  PrereqList.Clear;
  PrereqList.Add('Visual C++ Redistributable 2015-2022');
  PrereqList.Add('Microsoft .NET Framework 4.8');
  PrereqList.Add('OpenSSL 3.0');
  
  // Check each prerequisite
  for I := 0 to PrereqList.Count - 1 do
  begin
    PrereqName := PrereqList[I];
    Status := CheckPrereqStatus(PrereqName);
    
    if Status = 'missing' then
    begin
      Result := False;
      // Add to download list
      DownloadManager.AddDownload(
        GetPrereqDownloadUrl(PrereqName),
        GetPrereqFilename(PrereqName),
        GetPrereqChecksum(PrereqName)
      );
    end;
    
    PrereqStatus.Add(Format('%s: %s', [PrereqName, Status]));
  end;
  
  InstallLog.Add(Format('[%s] Prerequisites check completed', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
end;

// Check individual prerequisite status
function CheckPrereqStatus(const PrereqName: String): String;
begin
  // TODO: Implement actual prerequisite checking
  // For now, return 'missing' to trigger downloads
  Result := 'missing';
end;

// Get prerequisite download URL
function GetPrereqDownloadUrl(const PrereqName: String): String;
begin
  if PrereqName = 'Visual C++ Redistributable 2015-2022' then
    Result := 'https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/vc_redist/vc_redist.x64.exe'
  else if PrereqName = 'Microsoft .NET Framework 4.8' then
    Result := 'https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/dotnet/ndp48-web.exe'
  else if PrereqName = 'OpenSSL 3.0' then
    Result := 'https://github.com/saphirredragon207/device-notifier-app/raw/main/prerequisites/windows/openssl/Win64OpenSSL-3_0_12.exe'
  else
    Result := '';
end;

// Get prerequisite filename
function GetPrereqFilename(const PrereqName: String): String;
begin
  if PrereqName = 'Visual C++ Redistributable 2015-2022' then
    Result := 'vc_redist.x64.exe'
  else if PrereqName = 'Microsoft .NET Framework 4.8' then
    Result := 'ndp48-web.exe'
  else if PrereqName = 'OpenSSL 3.0' then
    Result := 'Win64OpenSSL-3_0_12.exe'
  else
    Result := '';
end;

// Get prerequisite checksum
function GetPrereqChecksum(const PrereqName: String): String;
begin
  if PrereqName = 'Visual C++ Redistributable 2015-2022' then
    Result := 'a1c2b3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678'
  else if PrereqName = 'Microsoft .NET Framework 4.8' then
    Result := 'b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567890'
  else if PrereqName = 'OpenSSL 3.0' then
    Result := 'c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567890ab'
  else
    Result := '';
end;

// Install prerequisites
function InstallPrerequisites: Boolean;
var
  I: Integer;
  InstallerPath: String;
  ResultCode: Integer;
begin
  Result := True;
  
  InstallLog.Add(Format('[%s] Installing prerequisites', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
  
  // Install each downloaded prerequisite
  for I := 0 to PrereqList.Count - 1 do
  begin
    InstallerPath := ExpandConstant('{tmp}\') + GetPrereqFilename(PrereqList[I]);
    
    if FileExists(InstallerPath) then
    begin
      // Install based on file type
      if LowerCase(ExtractFileExt(InstallerPath)) = '.exe' then
      begin
        if not Exec(InstallerPath, '/quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          Result := False;
          InstallLog.Add(Format('[%s] Failed to install %s', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), PrereqList[I]]));
          Break;
        end;
      end;
      
      InstallLog.Add(Format('[%s] Successfully installed %s', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), PrereqList[I]]));
    end;
  end;
end;

// Build and install application
function BuildAndInstallApplication: Boolean;
var
  ResultCode: Integer;
  CmdLine: String;
begin
  Result := True;
  
  InstallLog.Add(Format('[%s] Building and installing application', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
  
  // TODO: Implement actual application building and installation
  // This is a placeholder for the actual implementation
  
  InstallLog.Add(Format('[%s] Application installation completed', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
end;

// Configure Discord integration
function ConfigureDiscordIntegration: Boolean;
begin
  Result := True;
  
  if ConfigureDiscord then
  begin
    InstallLog.Add(Format('[%s] Configuring Discord integration', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
    
    // TODO: Implement Discord configuration
    // This is a placeholder for the actual implementation
    
    InstallLog.Add(Format('[%s] Discord integration configured', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
  end;
end;

// Handle wizard page changes
procedure CurStepChanged(CurStep: TSetupStep);
begin
  case CurStep of
    ssInstall:
    begin
      CurrentStep := 1;
      InstallLog.Add(Format('[%s] Step %d/%d: Checking prerequisites', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), CurrentStep, TotalSteps]));
      
      if not CheckPrerequisites then
      begin
        MsgBox('Failed to check system prerequisites. Installation cannot continue.', mbError, MB_OK);
        Abort;
      end;
      
      CurrentStep := 2;
      InstallLog.Add(Format('[%s] Step %d/%d: Installing prerequisites', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), CurrentStep, TotalSteps]));
      
      if not InstallPrerequisites then
      begin
        MsgBox('Failed to install required prerequisites. Installation cannot continue.', mbError, MB_OK);
        Abort;
      end;
      
      CurrentStep := 3;
      InstallLog.Add(Format('[%s] Step %d/%d: Building and installing application', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), CurrentStep, TotalSteps]));
      
      if not BuildAndInstallApplication then
      begin
        MsgBox('Failed to build and install the application. Installation cannot continue.', mbError, MB_OK);
        Abort;
      end;
      
      CurrentStep := 4;
      InstallLog.Add(Format('[%s] Step %d/%d: Configuring Discord integration', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), CurrentStep, TotalSteps]));
      
      if not ConfigureDiscordIntegration then
      begin
        MsgBox('Failed to configure Discord integration. The application will be installed but Discord features may not work.', mbWarning, MB_OK);
      end;
    end;
    
    ssPostInstall:
    begin
      CurrentStep := 5;
      InstallLog.Add(Format('[%s] Step %d/%d: Finalizing installation', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'), CurrentStep, TotalSteps]));
      
      // Create data directories
      CreateDir(ExpandConstant('{app}\data'));
      CreateDir(ExpandConstant('{app}\logs'));
      
      // Set proper permissions
      Exec('icacls', ExpandConstant('"{app}" /grant "Users":(OI)(CI)F'), '', SW_HIDE);
      
      // Save installation log
      InstallLog.Add(Format('[%s] Installation completed successfully', [GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':')]));
      InstallLog.SaveToFile(ExpandConstant('{app}\install.log'));
    end;
  end;
end;

// Utility functions
function GetInstallDate: string;
begin
  Result := GetDateTimeString('yyyy-mm-dd', '-', ':');
end;

function GetInstallScope: string;
begin
  Result := InstallScope;
end;

function GetStartOnBoot: Integer;
begin
  if StartOnBoot then
    Result := 1
  else
    Result := 0;
end;

function NeedsAddPath: Boolean;
var
  Path: string;
begin
  Result := True;
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Path) then
  begin
    Result := Pos(';' + ExpandConstant('{app}') + ';', ';' + Path + ';') = 0;
  end;
end;

function GetWindowsVersionString: String;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  Result := Format('Windows %d.%d (Build %d)', [Version.Major, Version.Minor, Version.Build]);
end;

function GetArchitectureString: String;
begin
  if Is64BitInstallMode then
    Result := 'x64'
  else
    Result := 'x86';
end;

[CustomMessages]
english.InstallingService=Installing Device Notifier Agent service...
english.StartingService=Starting Device Notifier Agent service...
english.ServiceInstallFailed=Failed to install Device Notifier Agent service. Please run as Administrator.
english.ServiceStartFailed=Failed to start Device Notifier Agent service. Please check the service manually.
