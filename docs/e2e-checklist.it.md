# Checklist end-to-end

Italiano | [English](e2e-checklist.md)

## Gate Wine, superato il 30 agosto 2026

- GTA avviato con `GTA5.exe -scOfflineOnly`.
- ScriptHook V e NativeTrainer caricati.
- F4 tramite `CGEvent` ha aperto Native Trainer in modo visibile.
- NUM2 ha spostato la selezione da PLAYER a WEAPON.
- NUM5 ha aperto WEAPON OPTIONS.
- Backspace è tornato alla lista principale.
- Ogni input ha emesso gli eventi key-down e key-up.
- Le macro testuali sono state escluse perché `FUGITIVE` e `LAWYERUP` sintetici non venivano riconosciuti dal parser dei cheat di Wine.

## Stato MVP, 30 agosto 2026

- [x] Build iOS firmato, installato e avviato sull'iPhone 17 di Matteo.
- [x] Build Release macOS firmato, verificato e installato come GodMode Mod Remote Control.
- [x] Listener TCP avviato automaticamente.
- [x] Core: 10 test in 3 suite.
- [x] Bridge: 8 test in 3 suite, comprese tutte le 11 mappature da tastiera.
- [x] iPhone: 8 test in una suite.
- [x] Telecomando iPhone senza tab o scorrimento, con menu, frecce, swipe, Indietro e Conferma.
- [x] Messaggi ripetuti, frame alterati e client non abbinati rifiutati dal protocollo e dai test.
- [ ] Permesso Rete locale accettato sul Mac e sull'iPhone fisico.
- [ ] Bridge scoperto tramite Bonjour senza IP manuale.
- [ ] Pairing approvato e riconnessione successiva confermata.
- [ ] F4 dall'iPhone apre davvero Native Trainer.
- [ ] Pad, Select e Back controllano davvero l'overlay.
- [ ] Disconnessione mostrata entro due secondi.

## Controlli diretti, da verificare dopo un riavvio sicuro di GTA

- [x] Protocollo v3, bridge e iPhone compilano e sono firmati.
- [x] La CI compila `GTARemoteBridge.asi` come binario Windows PE x64, verifica l'import di ScriptHook V e lo include nel setup.
- [ ] Dopo salvataggio e riavvio, `ScriptHookV.log` registra il modulo e `GTARemoteBridge.state` contiene `wreckPreservation` e `preservedWreckCount`.
- [ ] Attivare la conservazione dall'iPhone, guidare e distruggere un veicolo, poi confermare che rimanga nella scena.
- [ ] Disattivare la funzione e confermare che il contatore torni a zero e riprenda la pulizia di GTA.

## Bridge Windows, aggiunto il 3 settembre 2026

- [x] I test del protocollo .NET passano, compreso lo stesso vettore X25519, fingerprint e HKDF verificato da Swift.
- [x] Il progetto tray Windows viene ripristinato e compilato per `net8.0-windows10.0.19041.0` senza avvisi.
- [x] La pubblicazione self-contained `win-x64` include la dipendenza crittografica nativa.
- [x] Il runner Windows installa il setup in una cartella GTA simulata, verifica app e `.asi`, poi disinstalla senza eliminare i file ScriptHook condivisi.
- [ ] Eseguire il setup su un PC fisico Windows 10 o 11 x64 e avviare GodMode Mod Remote Control.
- [ ] Consentire il firewall solo sulla rete privata attiva e confermare il rilevamento `_gtactrl._tcp` dall'iPhone senza IP manuale.
- [ ] Confrontare e approvare il codice a sei cifre, poi riavviare le app e verificare la riconnessione cifrata.
- [ ] Selezionare la cartella reale di `GTA5.exe` e verificare che il test F4 ritardato venga rifiutato quando un'altra app è in primo piano.
- [ ] Portare GTA V Legacy in modalità Storia in primo piano e verificare visivamente F4, NUM2, NUM8, NUM4, NUM6, NUM5, Backspace, NUM0, NUM9, NUM3 e NUM+.
- [ ] Con `GTARemoteBridge.asi` caricato, confermare stato aggiornato e file di comando nella cartella di `GTA5.exe`.
