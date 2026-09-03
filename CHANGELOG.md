# Changelog

## Unreleased, 3 September 2026

- Added a native Windows 10/11 x64 tray bridge compatible with the existing iPhone protocol v3.
- Added Bonjour discovery, X25519 pairing, HKDF-SHA256 session derivation, ChaCha20-Poly1305 packets, replay protection, DPAPI-protected paired keys, and the existing 20-command-per-second limit.
- Added guarded `SendInput` keyboard control. Commands are accepted only while `GTA5.exe` from the configured game directory is in the foreground.
- Added the ScriptHook companion state and command-file integration, Windows tests, a self-contained ZIP build script, and a Windows installation guide.

## v0.3.0, 3 September 2026

- First public handoff of GTA Remote for GTA V Legacy Story Mode.
- iPhone build `0.3.0 (4)` is available to internal TestFlight testers. The public TestFlight link is enabled and awaiting Apple Beta App Review for external installation.
- Added the notarized and stapled macOS `Mac-GodMode-Mod-Remote-Control-v0.3.0.dmg` release asset with a centered hand-drawn drag-to-Applications arrow and a visible `1. START HERE.html` guide for Mac, iPhone, permissions, Wi-Fi, and pairing.
- Named the desktop release assets with the operating system first: `Windows-GodMode-Mod-Remote-Control-v0.3.0.zip` and `Mac-GodMode-Mod-Remote-Control-v0.3.0.dmg`.
- Added the source and installation guide for the separate `GTARemoteBridge.asi` ScriptHook V companion module. No prebuilt `.asi` binary is included.
- Documented the local Wi-Fi, Story Mode-only product boundary and the secure pairing flow.
