; The MarkLens Windows installer (docs/11_PACKAGING_UPDATE.md).
;
; Compiled by packaging/windows/build.ps1, which passes the version in:
;
;   iscc /DAppVersion=1.0.0 packaging\windows\marklens.iss
;
; The version is never written here. It lives in pubspec.yaml, is mirrored into
; lib/app/version.dart, and the release workflow checks the git tag against
; both; a fourth copy in this file would be a fourth thing to forget.

#ifndef AppVersion
  #error Compile with /DAppVersion=x.y.z - see packaging/windows/build.ps1
#endif

#define AppName        "MarkLens"
#define AppPublisher   "poli0981"
#define AppExeName     "marklens.exe"
#define AppUrl         "https://github.com/poli0981/MarkLens"
#define BuildDir       "..\..\build\windows\x64\runner\Release"

[Setup]
; Permanent. Changing AppId orphans every existing installation - Windows stops
; recognising the old one, so an upgrade becomes a second copy with its own
; uninstall entry. Generated once at M4 and recorded in doc 11.
AppId={{D40DDB92-8D60-4FA4-8D52-4C526834C355}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersion}
; Inno leaves the setup exe's LegalCopyright empty unless AppCopyright is set,
; which would have shipped an installer whose properties page says less about
; its licence than the program it installs (see Runner.rc).
AppCopyright=Copyright (C) 2026 {#AppPublisher}. GPL-3.0-only; see LICENSE.

; Per-user, per doc 11: no admin prompt, nothing written outside this user's
; profile, and nothing another account can be surprised by. `lowest` also means
; the uninstall entry lands under HKCU, which is where associations.iss writes
; too - one privilege story for the whole installer.
;
; And *only* per-user, so there is deliberately no
; PrivilegesRequiredOverridesAllowed. Through 1.0.1 it was `dialog`, which let a
; start-up question - or /ALLUSERS - choose an administrative install that
; nothing below is written for: the files stayed in that administrator's own
; {localappdata} and the associations in their HKCU, while the uninstall entry
; moved to HKLM. WinGet lists this installer as Scope: user (doc 11), and that
; has to be true of every install, not just of the default answer.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; x64compatible rather than x64: the build is x64 and Windows on ARM runs it
; through emulation, which is a supported way to use this program rather than
; something to refuse at the door.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

LicenseFile=..\..\LICENSE
OutputDir=..\..\build\installer
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; associations.iss registers the .md and .mdx ProgId. Without this, Setup never
; announces it (SHCNE_ASSOCCHANGED), and in Inno's own words the file type's
; icon "likely won't be displayed until the user logs off or restarts". With
; it, Setup and the uninstaller both tell Explorer to refresh - which Inno's
; documentation says any installation that creates an association should do.
ChangesAssociations=yes
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes

[Languages]
; Required, and not boilerplate: associations.iss uses {cm:AssocFileExtension},
; which is one of these message files' strings. Without a [Languages] section
; that constant does not exist and the compile fails.
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
; Inno has no standard group heading for file associations - the obvious
; candidate, {cm:AdditionalIcons}, reads "Additional shortcuts:" and would put
; two association checkboxes under a heading about shortcuts.
english.FileAssociations=File associations:

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

#include "associations.iss"

[Files]
; The whole Flutter bundle. `recursesubdirs` picks up data\ - flutter_assets,
; app.so and icudtl.dat - which the exe cannot start without.
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; \
    Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
    Flags: nowait postinstall skipifsilent

[Code]
{ Uninstall offers to remove the config directory, and does not assume.

  This is the only deletion anywhere in MarkLens. CLAUDE.md rule 1 is about the
  user's *documents* - session.json and settings.json are the app's own two
  files (doc 05) - so it is permitted, but it is opt-in and it is off by
  default. Somebody uninstalling to reinstall should not lose their tabs.

  The path is %APPDATA%\<CompanyName>\<ProductName>\marklens, which
  path_provider_windows builds from the exe's version block; doc 05 records why
  those two strings are load-bearing. }

const
  VCRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
  { Where vc_redist.x64.exe records itself, read off a machine that has it
    rather than transcribed: `Installed` is a DWORD 1 beside Version, Major,
    Minor and Bld. It appears in both the 64-bit view and WOW6432Node, and
    both are checked below, because which view an installer sees depends on
    the bitness it happens to be running in. }
  VCRedistKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';

var
  RemoveDataCheckBox: TNewCheckBox;

{ The Visual C++ runtime, which Flutter links against and does not bundle.

  Without it Windows refuses to start the program with a missing-DLL dialog
  naming VCRUNTIME140_1.dll or MSVCP140.dll - a message that says nothing about
  what to install. Every developer machine has the runtime, every machine with
  Office or a game has it, and a fresh Windows Sandbox does not: which is
  exactly where it was found.

  Checked rather than bundled, because this installer is per-user and
  PrivilegesRequired=lowest: the redistributable is a machine-wide install that
  needs elevation, so bundling it would either fail or turn a no-admin install
  into an admin one. Reading HKLM needs no elevation.

  It warns and offers to continue rather than refusing. Somebody may be
  installing ahead of the runtime deliberately, and an installer that blocks on
  a prerequisite it cannot install is a dead end.

  Unattended, there is nobody to answer, so the question has to be one Inno
  can suppress. A plain MsgBox is not: /SUPPRESSMSGBOXES - which WinGet always
  passes - leaves it on screen, and a silent install waits on it for ever.
  SuppressibleMsgBox returns IDYES when suppressed, which is the answer an
  interactive install offers, and the setup log records which way it went. }
function VCRedistInstalled(): Boolean;
var
  Installed: Cardinal;
begin
  Result :=
    (RegQueryDWordValue(HKLM, VCRedistKey, 'Installed', Installed)
      and (Installed = 1))
    or
    (RegQueryDWordValue(HKLM32, VCRedistKey, 'Installed', Installed)
      and (Installed = 1));
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if VCRedistInstalled() then
    Exit;

  Log('The Visual C++ Redistributable (x64) is not installed: no Installed=1 '
    + 'under HKLM\' + VCRedistKey + ' in either registry view.');
  if SuppressibleMsgBox(
      'MarkLens needs the Microsoft Visual C++ Redistributable (x64), which '
      + 'does not appear to be installed.' + #13#10#13#10
      + 'Without it Windows will refuse to start MarkLens with a message about '
      + 'a missing VCRUNTIME140_1.dll or MSVCP140.dll.' + #13#10#13#10
      + 'Download it from:' + #13#10 + VCRedistUrl + #13#10#13#10
      + 'Continue installing anyway?',
      mbConfirmation, MB_YESNO, IDYES) = IDNO then
  begin
    Log('Cancelled at the Visual C++ runtime warning.');
    Result := False;
  end
  else
    Log('Continuing without the Visual C++ runtime. MarkLens will not start '
      + 'until it is installed: ' + VCRedistUrl);
end;

function ConfigDirectory(): String;
begin
  Result := ExpandConstant('{userappdata}\poli0981\MarkLens\marklens');
end;

procedure InitializeUninstallProgressForm();
begin
  RemoveDataCheckBox := TNewCheckBox.Create(UninstallProgressForm);
  RemoveDataCheckBox.Parent := UninstallProgressForm.InnerPage;
  RemoveDataCheckBox.Top := UninstallProgressForm.StatusLabel.Top +
    UninstallProgressForm.StatusLabel.Height + ScaleY(16);
  RemoveDataCheckBox.Left := UninstallProgressForm.StatusLabel.Left;
  RemoveDataCheckBox.Width := UninstallProgressForm.InnerPage.ClientWidth -
    ScaleX(32);
  RemoveDataCheckBox.Caption := 'Also remove settings and session';
  RemoveDataCheckBox.Checked := False;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if Assigned(RemoveDataCheckBox) and RemoveDataCheckBox.Checked then
      DelTree(ConfigDirectory(), True, True, True);
  end;
end;
