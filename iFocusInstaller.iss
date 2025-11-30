; -----------------------------------------------------------
; iFocus Installer Script
; Publisher: IssubiAcademy
; Version: 0.0.0.1
; -----------------------------------------------------------

[Setup]
AppName=iFocus
AppVersion=0.0.0.1
AppPublisher=IssubiAcademy
DefaultDirName={pf}\iFocus
DefaultGroupName=iFocus
OutputDir=output
OutputBaseFilename=iFocusInstaller
Compression=lzma
SolidCompression=yes
DisableDirPage=no
DisableProgramGroupPage=yes
SetupIconFile=windows\runner\resources\app_icon.ico
AppId={{A1F3C840-1A22-4E11-8E07-IFOCUS-2025}}

[Files]
; Copy app icon to installation folder
Source: "windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
; Copy all Flutter Windows build files (EXE + data + DLLs)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Tasks]
Name: "desktopicon"; Description: "Create Desktop Shortcut"; Flags: unchecked
Name: "startmenuicon"; Description: "Create Start Menu Shortcut"; Flags: unchecked

[Icons]
; Start Menu Shortcut
Name: "{group}\iFocus"; Filename: "{app}\ifocus.exe"; IconFilename: "{app}\app_icon.ico"; Tasks: startmenuicon

; Desktop Shortcut
Name: "{commondesktop}\iFocus"; Filename: "{app}\ifocus.exe"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\ifocus.exe"; Description: "Launch iFocus"; Flags: nowait postinstall skipifsilent
