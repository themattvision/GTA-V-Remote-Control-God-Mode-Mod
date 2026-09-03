# Changelog

[Italiano](CHANGELOG.it.md) | English

## v0.3.1, 3 September 2026

- Published the complete Windows 10/11 x64 tray bridge and guided installer from the same source commit as this release tag.
- Added Bonjour discovery, X25519 pairing, HKDF-SHA256 session derivation, ChaCha20-Poly1305 packets, replay protection, DPAPI-protected paired keys, and the existing 20-command-per-second limit on Windows.
- Added guarded `SendInput` keyboard control. Commands are accepted only while `GTA5.exe` from the configured game directory is in the foreground.
- Added the ScriptHook companion state and command-file integration. The Windows setup includes the compiled x64 `GTARemoteBridge.asi`, imports the user-selected official ScriptHook V ZIP when needed, configures autostart and the private-network firewall rule, backs up replaced files, and safely removes only our module during uninstall.
- Localized the guided Windows setup and notification-area app in Italian and English, selected automatically from the Windows display language.
- Added complete public installation, safety, protocol, module, release, and verification documentation in Italian and English.
- Added English TestFlight beta metadata without replacing or resubmitting iPhone build `0.3.0 (4)`.
- Added a reproducible local script for the signed, notarized, and stapled macOS DMG.

## v0.3.0, 3 September 2026

- First public handoff of GTA Remote for GTA V Legacy Story Mode.
- iPhone build `0.3.0 (4)` was made available to internal TestFlight testers. The public TestFlight link was enabled and submitted for Apple Beta App Review.
- Added the notarized and stapled macOS DMG with a visible `1. START HERE.html` guide.
- Documented the local Wi-Fi, Story Mode-only boundary and secure pairing flow.
