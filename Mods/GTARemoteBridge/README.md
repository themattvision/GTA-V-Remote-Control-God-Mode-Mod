# GTARemoteBridge

`GTARemoteBridge.asi` is an additional ScriptHook V module for GTA V Legacy Story Mode. It provides direct, state-backed God Mode and destroyed-vehicle preservation controls.

It does not replace, alter, or patch `NativeTrainer.asi` or any existing God Mode mod. It is a separate companion module and can coexist with NativeTrainer.

This is a developer component. No prebuilt `.asi` file is included in the repository or the v0.3.0 release.

## What the module does

The macOS bridge writes one restricted request, either `setGodMode` or `setWreckPreservation`, to the GTA folder. This module reads the request on the GTA game thread, calls the necessary GTA natives, and publishes the confirmed state every 250 ms.

The phone receives the state from the bridge. It does not guess the state from the position of a NativeTrainer menu.

When destroyed-vehicle preservation is on, the module retains up to 12 vehicles driven by the player. It does not scan or freeze all traffic vehicles. When the feature is turned off, normal GTA cleanup resumes.

## Requirements

You need all of the following before building:

1. GTA V Legacy, for Story Mode only.
2. The official ScriptHook V SDK.
3. A Windows x64 C++ compiler.
4. A working ScriptHook V installation, including `ScriptHookV.dll` and `dinput8.dll` next to `GTA5.exe`.

The included `ScriptHookV.def` creates the small import library required by the MinGW toolchain. It uses ordinals verified against `ScriptHookV.dll` for GTA Legacy 1.0.1180.2.

## Build and install

1. Build the source in this folder with the official ScriptHook V SDK and your Windows x64 compiler.
2. Confirm that the build output is named exactly `GTARemoteBridge.asi`.
3. Save your game and close GTA V completely.
4. Open the folder that contains `GTA5.exe`.
5. Copy `GTARemoteBridge.asi` into that folder, next to `GTA5.exe`, `ScriptHookV.dll`, and `dinput8.dll`.
6. Start GTA V Legacy, then enter Story Mode.

The module should not be installed into a subfolder. All four files named above must be in the same GTA installation folder.

## Local command and state files

The module uses two local files in the same folder as `GTA5.exe`.

`GTARemoteBridge.command` is written by GodMode Mod Remote Control:

```text
version=1
requestID=<uuid>
action=setGodMode
enabled=1
```

`GTARemoteBridge.state` is written by the module:

```text
version=1
godMode=1
wreckPreservation=1
preservedWreckCount=2
```

The state file is valid only when it was updated within the last two seconds. This prevents the phone from showing stale information after GTA closes or the module stops working.

Do not manually edit either file while GTA is running.

## Update safely

1. Save your game and close GTA V completely.
2. Copy the new build to the GTA folder as `GTARemoteBridge.asi.next`.
3. Rename the active `GTARemoteBridge.asi` to a recoverable backup name.
4. Rename `GTARemoteBridge.asi.next` to `GTARemoteBridge.asi`.
5. Start GTA V Legacy again.

ScriptHook loads modules only at game launch. Never replace an active ASI file while GTA is open.

This module is for local, personal Story Mode use only. GTA Online is not supported.
