# GTA V Remote Control, God Mode Companion Mod

GTA V Remote Control, God Mode Companion Mod is a local, two-part remote control for GTA V Legacy Story Mode. Your iPhone is the controller. GTA Remote Control is the Mac menu-bar app that connects the phone to the game.

It is for personal, offline use on your own Wi-Fi network. It does not support GTA Online.

## Start here

Before downloading anything, make sure you have all four items below:

1. A Mac running macOS 15 or later. GTA Remote Control runs on this Mac.
2. An iPhone running iOS 18 or later. GTA Remote runs on this iPhone.
3. GTA V Legacy installed for Story Mode, with ScriptHook V if you want to build and use the optional companion module.
4. The Mac and iPhone connected to the same Wi-Fi network. Turn off any VPN on either device while pairing.

The iPhone app cannot work by itself. Leave GTA Remote Control running on the Mac while you use the iPhone.

## Install the iPhone app

1. On the iPhone, open this TestFlight link: [Join GTA Remote on TestFlight](https://testflight.apple.com/join/TfJtcUy3).
2. If TestFlight is not installed, install it from the App Store, then open the link again.
3. Tap Accept, then Install.
4. Open GTA Remote after the installation finishes. When iOS asks for Local Network access, tap Allow.

### Current TestFlight status, 3 September 2026

Build `0.3.0 (4)` is valid and ready for internal testers. The public TestFlight link is enabled, but external installation is still waiting for Apple Beta App Review. If TestFlight says that the app is unavailable, this is the reason. Internal testers can use the current build now.

Do not download an IPA from GitHub. TestFlight is the normal and supported iPhone installation route.

## Install GTA Remote Control on the Mac

1. Open the [v0.3.0 release page](../../releases/tag/v0.3.0).
2. Under Assets, download `GTARemoteControl-0.3.0-macos.dmg`.
3. Open the downloaded DMG file in Finder.
4. Double-click `1. START HERE.html` first. It shows the complete Mac, iPhone, permissions, Wi-Fi, and pairing guide in the right order.
5. Drag GTA Remote Control onto the Applications folder shown in the installation window.
6. Open GTA Remote Control from Applications.

GTA Remote Control is a menu-bar app. It does not open a normal window or stay in the Dock. Look at the right side of the macOS menu bar for its icon. Keep it running while you use GTA Remote.

The download is signed with Developer ID, notarized by Apple, and stapled for offline Gatekeeper verification.

### Allow the two Mac permissions

On first use, GTA Remote Control may ask for permissions. Allow both:

1. Local Network: this lets the Mac find your iPhone on the same Wi-Fi network.
2. Accessibility: this lets GTA Remote Control send the supported controller input to the local GTA window.

If macOS does not show the Accessibility prompt, open System Settings, go to Privacy & Security, then Accessibility, and enable GTA Remote Control. Quit and reopen GTA Remote Control after changing the permission.

## Pair the iPhone and Mac

1. Start GTA Remote Control on the Mac and leave it running in the menu bar.
2. Confirm that the Mac and iPhone are on the same Wi-Fi network. Do not use a guest network.
3. Open GTA Remote on the iPhone.
4. Select the Mac when it appears.
5. Compare the pairing number shown on both devices.
6. Approve the pairing on the Mac only when the two numbers match.

If the Mac does not appear, check these items in order: both apps are open, both devices use the same non-guest Wi-Fi, both VPNs are off, and Local Network access is allowed on both devices. Then quit and reopen GTA Remote Control and GTA Remote.

## Optional ScriptHook V companion module

`GTARemoteBridge.asi` is our additional ScriptHook V companion module. It is not a replacement for `NativeTrainer.asi`, and it does not modify NativeTrainer or an existing God Mode mod. The two modules are designed to coexist.

The module makes these selected controls direct and state-backed:

- God Mode
- Preserve destroyed vehicles, limited to 12 vehicles driven by the player

The current iPhone interface does not expose these two controls yet. The module and protocol are kept for bridge compatibility and future verified controls.

### Important: no ready-to-install `.asi` file is included

This release does not contain `GTARemoteBridge.asi`, because the required official ScriptHook V SDK and Windows x64 build toolchain are not available in this release environment. Do not download a random `.asi` file from an unofficial source.

This section is for developers who can build the module from the included source. Everyone else can skip it.

### Build and install the module

1. Install the official ScriptHook V SDK and a Windows x64 C++ compiler.
2. Build the source in [`Mods/GTARemoteBridge`](Mods/GTARemoteBridge). The output file must be named `GTARemoteBridge.asi`.
3. Close GTA V completely. Do not replace ScriptHook files while the game is running.
4. Open the folder that contains `GTA5.exe`.
5. Put `GTARemoteBridge.asi` in that exact folder, next to `GTA5.exe`, `ScriptHookV.dll`, and `dinput8.dll`.
6. Start GTA V Legacy and enter Story Mode.

When the module is running, GTA Remote Control writes `GTARemoteBridge.command` in the same GTA folder. The module reads it and publishes `GTARemoteBridge.state` there. Do not edit either file while GTA is open.

### Update the module safely

1. Save your game and close GTA V completely.
2. Place the newly built file in the GTA folder as `GTARemoteBridge.asi.next`.
3. Rename the current `GTARemoteBridge.asi` to a backup name, for example `GTARemoteBridge.asi.backup`.
4. Rename `GTARemoteBridge.asi.next` to `GTARemoteBridge.asi`.
5. Start GTA V Legacy again.

ScriptHook loads ASI modules only when GTA starts. Do not try to hot-swap the module during a game session. See the [module README](Mods/GTARemoteBridge/README.md) for technical details.

## What is included in this repository

- iPhone source: `iOS/GTARemote`
- Mac remote-control source: `macOS/GTABridge`
- Shared secure local protocol: `Packages/GTAControlCore`
- ScriptHook V companion module source: `Mods/GTARemoteBridge`
- Release and protocol notes: `CHANGELOG.md`, `docs/protocol.md`, and `docs/e2e-checklist.md`

## Developers

```sh
xcodegen generate
swift test --package-path Packages/GTAControlCore
xcodebuild -project GTARemote.xcodeproj -scheme GTABridge -configuration Release build
```

The iPhone TestFlight lanes are in `fastlane/Fastfile`. Set `ASC_KEY_FILEPATH` to an App Store Connect API key stored outside this repository before using them. Never commit API keys, provisioning profiles, archives, or build products.

## Scope and known limits

- GTA V Legacy and Story Mode only.
- Local Wi-Fi only. There is no internet relay.
- GTA Online is not supported.
- Text cheat macros were deliberately excluded because they were not reliable in the supported Wine setup.
