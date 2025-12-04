; iFocus - 1000-Day Transformation Tracker Setup Script
; This script creates an installer that preserves user data across updates

#define MyAppName "iFocus"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Issubi Academy"
#define MyAppURL "https://issubiacademy.com"
#define MyAppExeName "ifocus.exe"
#define MyAppId "{{6b483229-aa8a-4827-a384-4b48e779cb52}}"

[Setup]
; App identification
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation directories
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output configuration
OutputDir=installer_output
OutputBaseFilename={#MyAppName}_Setup_{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression
Compression=lzma2/max
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=2

; UI Configuration
WizardStyle=modern
;WizardImageFile=compiler:WizModernImage-is.bmp
;WizardSmallImageFile=compiler:WizModernSmallImage-is.bmp

; Privileges
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Version Info
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} - 1000-Day Transformation Tracker
VersionInfoCopyright=Copyright (C) 2024 {#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

; Directories that will NOT be deleted on uninstall
[Dirs]
Name: "{%USERPROFILE}\Documents\iFocus"; Flags: uninsneveruninstall

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Launch {#MyAppName} at Windows startup"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main application files from Flutter build
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Note: Add your custom icon if you have one

[Icons]
; Start menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{group}\Open Data Folder"; Filename: "{%USERPROFILE}\Documents\iFocus"; IconIndex: 0

; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

; Startup shortcut
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

; Quick Launch shortcut (for older Windows versions)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Option to launch app after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up app files but NOT user data
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\*.dll"
Type: files; Name: "{app}\*.exe"

[Code]
var
  DataDirPage: TInputDirWizardPage;
  ExistingDataFound: Boolean;
  ExistingDataPath: String;

// Function to check if data directory exists
function DataDirectoryExists(): Boolean;
var
  DataPath: String;
begin
  DataPath := ExpandConstant('{%USERPROFILE}\Documents\iFocus');
  Result := DirExists(DataPath);
end;

// Initialize setup
function InitializeSetup(): Boolean;
begin
  Result := True;
  ExistingDataPath := ExpandConstant('{%USERPROFILE}\Documents\iFocus');
  ExistingDataFound := DirExists(ExistingDataPath);
  
  if ExistingDataFound then
  begin
    if FileExists(ExistingDataPath + '\user_data.json') then
    begin
      MsgBox('✅ Existing iFocus data detected!' + #13#10#13#10 + 
             'Your 1000-day tracking progress will be preserved.' + #13#10 +
             'Data location: ' + ExistingDataPath + #13#10#13#10 +
             'You can safely upgrade without losing any progress!', 
             mbInformation, MB_OK);
    end;
  end;
end;

// Before installation begins
procedure CurStepChanged(CurStep: TSetupStep);
var
  DataPath: String;
begin
  if CurStep = ssInstall then
  begin
    DataPath := ExpandConstant('{%USERPROFILE}\Documents\iFocus');
    
    // Create data directory if it doesn't exist
    if not DirExists(DataPath) then
    begin
      CreateDir(DataPath);
      Log('Created data directory: ' + DataPath);
    end;
  end;
  
  if CurStep = ssPostInstall then
  begin
    MsgBox('✅ {#MyAppName} installed successfully!' + #13#10#13#10 +
           'Your tracking data is stored at:' + #13#10 +
           ExistingDataPath + #13#10#13#10 +
           '💡 Tip: Run as Administrator for Focus Mode to work properly.', 
           mbInformation, MB_OK);
  end;
end;

// Handle uninstallation
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataPath: String;
  DataFileCount: Integer;
  ResultCode: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataPath := ExpandConstant('{%USERPROFILE}\Documents\iFocus');
    
    if DirExists(DataPath) then
    begin
      // Check if data exists
      if FileExists(DataPath + '\user_data.json') then
      begin
        case MsgBox('Do you want to KEEP your 1000-day tracking data?' + #13#10#13#10 +
                    '⚠️ RECOMMENDED: Choose YES' + #13#10#13#10 +
                    'Your data location:' + #13#10 +
                    DataPath + #13#10#13#10 +
                    'If you choose YES:' + #13#10 +
                    '• Your progress is safe' + #13#10 +
                    '• You can reinstall anytime' + #13#10 +
                    '• All your tracking data remains intact' + #13#10#13#10 +
                    'If you choose NO:' + #13#10 +
                    '• ALL your data will be permanently deleted' + #13#10 +
                    '• This cannot be undone', 
                    mbConfirmation, MB_YESNO) of
          IDYES:
          begin
            MsgBox('✅ Your data has been preserved!' + #13#10#13#10 +
                   'Location: ' + DataPath + #13#10#13#10 +
                   'You can reinstall {#MyAppName} anytime and your ' + #13#10 +
                   'progress will be exactly where you left off!', 
                   mbInformation, MB_OK);
          end;
          IDNO:
          begin
            if MsgBox('⚠️ FINAL WARNING!' + #13#10#13#10 +
                      'Are you ABSOLUTELY SURE you want to delete ALL your data?' + #13#10#13#10 +
                      'This will permanently erase:' + #13#10 +
                      '• Your current day progress' + #13#10 +
                      '• All daily logs and history' + #13#10 +
                      '• Weekly plans' + #13#10 +
                      '• All backups in this folder' + #13#10#13#10 +
                      'THIS CANNOT BE UNDONE!', 
                      mbConfirmation, MB_YESNO) = IDYES then
            begin
              // Delete the entire data directory
              if Exec('cmd.exe', '/c rmdir /s /q "' + DataPath + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
              begin
                MsgBox('All data has been permanently deleted.', mbInformation, MB_OK);
              end
              else
              begin
                MsgBox('Could not delete data folder. You may need to delete it manually at:' + #13#10 + DataPath, mbError, MB_OK);
              end;
            end
            else
            begin
              MsgBox('✅ Deletion cancelled. Your data is safe!', mbInformation, MB_OK);
            end;
          end;
        end;
      end
      else
      begin
        // No user data found, safe to remove directory
        Exec('cmd.exe', '/c rmdir /s /q "' + DataPath + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;
  end;
end;

// Custom page to show data location (optional)
procedure InitializeWizard();
begin
  if ExistingDataFound then
  begin
    // Could add custom page here to show data location
  end;
end;