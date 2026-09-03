# End-to-end checklist

[Italiano](e2e-checklist.it.md) | English

## Wine gate, passed on 30 August 2026

- GTA launched with `GTA5.exe -scOfflineOnly`.
- ScriptHook V and NativeTrainer loaded.
- `CGEvent` F4 visibly opened Native Trainer.
- NUM2 moved the selection from PLAYER to WEAPON.
- NUM5 opened WEAPON OPTIONS.
- Backspace returned to the main list.
- Every input emitted key-down and key-up events.
- Text macros were excluded: synthetic `FUGITIVE` and `LAWYERUP` were not recognized by the Wine cheat parser. `LAWYERUP` did not reduce the trainer-set wanted level, and its final P opened the pause menu.

## MVP status, 30 August 2026

- [x] iOS build signed, installed, and launched on Matteo's iPhone 17.
- [x] macOS Release build signed, verified, and installed as GodMode Mod Remote Control.
- [x] TCP listener starts automatically without opening the menu-bar menu.
- [x] Core: 10 tests in 3 suites.
- [x] Bridge: 8 tests in 3 suites, including all 11 keyboard mappings.
- [x] iPhone: 8 tests in 1 suite.
- [x] iPhone remote with no tabs or scrolling, a large open/close menu control, four arrows, D-pad swipe, small Back on the left, and large Confirm on the right.
- [x] iPhone UI redesign with a gradient backdrop, no neon, no overall remote box, Liquid Glass only on buttons, and internal SwiftUI components in a shadcn-like style.
- [x] Shortcuts, cheats, and press-only macros removed from the iPhone UI.
- [x] Replayed messages, altered frames, and unpaired clients rejected by the protocol and tests.
- [ ] Local Network permission accepted on the Mac and physical iPhone.
- [ ] Bridge discovered through Bonjour without a manual IP address.
- [ ] Pairing approved and later reconnection confirmed.
- [ ] F4 tap on the iPhone actually opens Native Trainer.
- [ ] Pad, Select, and Back actually control the overlay.
- [ ] Disconnection is shown within two seconds.

## Direct controls, verify after a safe GTA restart

- [x] Protocol v3, bridge, and iPhone compile and are signed.
- [x] CI builds `GTARemoteBridge.asi` as a Windows x64 PE binary, verifies its ScriptHook V import, and includes it in the guided setup.
- [ ] After saving and restarting GTA, `ScriptHookV.log` records the new module and `GTARemoteBridge.state` contains `wreckPreservation` and `preservedWreckCount`.
- [ ] Turn on Preserve destroyed vehicles from the iPhone, drive a vehicle, destroy it, and confirm that it remains in the scene.
- [ ] Turn the feature off and confirm that the counter returns to zero and GTA cleanup resumes.

## Windows bridge, added 3 September 2026

- [x] .NET protocol tests pass, including the same fixed X25519, fingerprint, and HKDF vector asserted by Swift.
- [x] Windows tray project restores and compiles for `net8.0-windows10.0.19041.0` with zero warnings.
- [x] The `win-x64` self-contained publish completes and contains the native crypto dependency.
- [x] The Windows runner installs the setup into a simulated GTA directory, verifies the app and `.asi`, then uninstalls and confirms that the shared ScriptHook files remain.
- [ ] Run the setup interactively on a physical Windows 10 or 11 x64 PC and launch GodMode Mod Remote Control.
- [ ] Allow Windows Defender Firewall only on the active private network and confirm that the iPhone discovers `_gtactrl._tcp` without a manual IP address.
- [ ] Compare and approve the same six-digit pairing code on Windows and iPhone, then restart both apps and verify encrypted reconnection.
- [ ] Select the real directory containing `GTA5.exe` and confirm that the delayed F4 test is rejected while another app is in front.
- [ ] Put GTA V Legacy Story Mode in front and visually confirm F4, NUM2, NUM8, NUM4, NUM6, NUM5, Backspace, NUM0, NUM9, NUM3, and NUM+.
- [ ] With `GTARemoteBridge.asi` loaded, confirm fresh state publication and direct-control command files next to `GTA5.exe`.
