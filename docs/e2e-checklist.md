# Checklist E2E

## Gate Wine, superato il 30 agosto 2026

- GTA avviato con `GTA5.exe -scOfflineOnly`.
- ScriptHookV e NativeTrainer caricati.
- `CGEvent` F4 ha aperto visivamente Native Trainer.
- NUM2 ha spostato la selezione da PLAYER a WEAPON.
- NUM5 ha aperto WEAPON OPTIONS.
- Backspace ha riportato alla lista principale.
- Ogni input ha emesso key-down e key-up.
- Macro testuali escluse: `FUGITIVE` e `LAWYERUP` sintetici non sono stati riconosciuti dal cheat parser Wine. `LAWYERUP` non ha ridotto la stella impostata via trainer e la P finale ha aperto la pausa.

## MVP, stato del 30 agosto 2026

- [x] Build iOS firmata, installata e avviata sull'iPhone 17 di Matteo.
- [x] Build macOS Release firmata, verificata e installata in `~/Applications/GTABridge.app`.
- [x] Listener TCP avviato automaticamente senza aprire il menu della barra dei menu.
- [x] Core: 10 test in 3 suite.
- [x] Bridge: 8 test in 3 suite, comprese tutte le 11 mappature tastiera.
- [x] iPhone: 8 test in 1 suite.
- [x] Telecomando iPhone senza tab e senza scroll, con Apri / chiudi menu grande, quattro frecce, swipe sul D-pad, Indietro piccolo a sinistra e Conferma grande a destra.
- [x] Redesign UI iPhone applicato con backdrop a gradiente, niente neon, niente box generale del telecomando, Liquid Glass solo sui pulsanti e componenti SwiftUI interni stile shadcn.
- [x] Scorciatoie, Trucchi e macro press-only rimosse dalla UI iPhone.
- [x] Replay, frame alterato e client non associato rifiutati dal protocollo e dai test.
- [ ] Consenso Rete locale accettato sul Mac e sull'iPhone fisico.
- [ ] Bridge scoperto via Bonjour senza IP manuale.
- [ ] Pairing approvato e riconnessione successiva.
- [ ] Tap F4 su iPhone apre realmente Native Trainer.
- [ ] Pad, Select e Back controllano realmente l'overlay.
- [ ] Disconnessione mostrata entro due secondi.

## Controlli diretti v0.3.0, da verificare dopo un riavvio sicuro di GTA

- [x] Protocollo v3, bridge e iPhone compilati e firmati.
- [x] Nuovo `GTARemoteBridge.asi` compilato per Windows x64 e preparato come `GTARemoteBridge.asi.next` senza toccare il modulo usato dalla partita corrente.
- [ ] Dopo aver salvato e riavviato GTA, `ScriptHookV.log` registra il nuovo modulo e `GTARemoteBridge.state` contiene `wreckPreservation` e `preservedWreckCount`.
- [ ] Attivare Conserva i veicoli distrutti dall'iPhone, guidare un veicolo, distruggerlo e verificare che resti nella scena.
- [ ] Spegnere la funzione e verificare che il contatore torni a zero e la pulizia torni a GTA.
