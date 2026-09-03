# GTA Remote Protocol v3

## Transport

- Bonjour discovery: `_gtactrl._tcp`
- Transport: TCP through Network.framework
- Framing: big-endian `UInt32` length prefix followed by the payload
- Maximum frame size: 16,384 bytes
- Protocol version: 3

## Allowed commands

A peer cannot send key codes, text, shell commands, or native hashes. It can send only a `TrainerCommand` enum value compiled into both targets, or one of the explicit commands `setGodMode(enabled:)` and `setWreckPreservation(enabled:)`.

Every command includes `clientID`, `requestID`, a monotonic sequence number, and a protocol version. The bridge rejects incompatible versions, replayed messages, unpaired clients, and more than 20 commands per second.

The direct commands are limited to God Mode and destroyed-vehicle preservation. The bridge translates them into a local file read by the ScriptHook module on the GTA game thread. The module returns a `TrainerStateSnapshot` containing the value confirmed by the game engine. Preservation applies only to vehicles driven by the player, and the module caps the number at 12. If state does not arrive or becomes stale, the iPhone disables the toggle instead of inventing a local value.

## Pairing

First pairing uses an X25519 exchange and shows the same numeric fingerprint on the iPhone and Mac. The user approves it on the Mac. The persistent secret is stored in Keychain, and later sessions derive new keys with HKDF. Authenticated payloads use ChaChaPoly.

The MVP may include a clear-text local diagnostic transport only behind an explicit Debug build flag. It must never be active in Release.
