# GodMode Mod Remote Control for Windows

[Italiano](README.it.md) | English

The Windows bridge connects GTA Remote on the iPhone to GTA V Legacy Story Mode. It runs in the Windows notification area without a main window.
The setup and notification-area menu automatically use Italian when Windows is set to Italian, and English otherwise.

## Installation

1. Download `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.1.exe` from the GitHub release.
2. Close GTA V completely, then start the setup.
3. Confirm the folder containing `GTA5.exe`. The setup tries to find it automatically.
4. If ScriptHook V is incomplete, use the official link shown by the setup, download the ZIP, and select it. You do not need to extract it.
5. Confirm that you will use the mod only in Story Mode and complete the installation.
6. Find GodMode Mod Remote Control in the notification area, including the hidden-icons menu.
7. Open GTA Remote on the iPhone, compare the six-digit code, and approve pairing from the bridge menu.

The setup installs the Windows app, `GTARemoteBridge.asi`, the official components found in the ScriptHook V ZIP, automatic startup, and a firewall rule limited to private networks. It backs up existing files before replacing them. Uninstall removes our mod but leaves shared ScriptHook files that other mods may need.

ScriptHook V cannot be included in the setup because its author prohibits redistribution. The only separate step is downloading it from the official site linked by the guided setup.

The current Windows build is not code-signed, so SmartScreen may warn about the executable. Do not disable SmartScreen globally.

## Safe use

The bridge sends keys only when `GTA5.exe` from the authorized game folder is the foreground process. It supports only commands compiled into the app and does not accept arbitrary key codes, text, shell commands, or native hashes from the network.

Direct mode through `GTARemoteBridge.asi` uses the same local files as the Mac bridge. The setup places the `.asi` file next to `GTA5.exe`. State is valid only while `GTARemoteBridge.state` was updated within the last two seconds.

GTA Online is not supported.

## Quick verification

1. Start GTA V Legacy and enter Story Mode.
2. Choose `Test F4 in 3 seconds` from the bridge menu.
3. Bring GTA V to the foreground within three seconds.
4. Confirm that F4 opens or closes Native Trainer.

Use [`docs/e2e-checklist.md`](../docs/e2e-checklist.md) for the complete test.

## Build the installer from source

Requires PowerShell, the .NET 8 SDK, MinGW x64 with binutils, and Inno Setup 6:

```powershell
.\Scripts\build-windows-installer.ps1
```

The script runs the tests, publishes the self-contained app, builds `GTARemoteBridge.asi`, and creates `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.1.exe` in the user's Downloads folder.
