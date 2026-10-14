#define AppName "Traut Admin"
#define AppPublisher "Traut"
#define AppExeName "traut_admin.exe"
#define AppVersion GetEnv("TRAUT_VERSION")

[Setup]
AppId={{6DCBE920-F948-4A72-9B17-3A72FC71A5CC}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Traut Admin
DefaultGroupName=Traut Admin
AllowNoIcons=yes
OutputDir=..\output
OutputBaseFilename=TrautAdmin-Setup-v{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Traut Admin"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Traut Admin"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Abrir Traut Admin"; Flags: nowait postinstall skipifsilent
