# GTA Remote

Telecomando locale per GTA V Legacy in modalità Storia. Sostituisce il tastierino numerico quando giochi con il controller, tramite un iPhone e un piccolo bridge nella barra dei menu del Mac.

Funziona solo in locale, sulla stessa rete Wi-Fi, e solo per uso personale offline. Non supporta GTA Online.

## Installa

### iPhone, GTA Remote

[Apri la beta su TestFlight](https://testflight.apple.com/join/TfJtcUy3), quindi installa GTA Remote dall'app TestFlight.

Stato al 3 settembre 2026: il build pubblico è `0.3.0 (4)`, valido e pronto per i tester interni. Il link pubblico è attivo, ma l'installazione per tester esterni resta in attesa dell'approvazione Apple Beta App Review.

L'IPA non è il canale di installazione pubblico: su iPhone la distribuzione avviene tramite TestFlight.

### Mac, GTA Bridge

Scarica `GTABridge-0.3.0-macos.zip` dalla [release v0.3.0](../../releases/tag/v0.3.0), estrailo e sposta `GTABridge.app` in Applicazioni. L'app è firmata con Developer ID, notarizzata e graffettata da Apple.

Al primo avvio:

1. Consenti l'accesso alla Rete locale quando macOS lo chiede.
2. Dal menu di GTA Bridge, apri le impostazioni di Privacy e sicurezza e abilita Accessibilità per GTA Bridge.
3. Lascia GTA Bridge aperta nella barra dei menu.

### Collega iPhone e Mac

1. Collega entrambi alla stessa Wi-Fi e avvia GTA Bridge.
2. Apri GTA Remote, consenti Rete locale e scegli il bridge trovato.
3. Confronta il codice di sei cifre su iPhone e Mac, poi approva dal Mac.
4. Porta GTA V Legacy in primo piano e usa la plancia: Apri / chiudi menu, D-pad anche con swipe, Indietro e Conferma.

Il bridge accetta soltanto comandi previsti dall'app e li inoltra solo con GTA in primo piano.

## Modulo ScriptHook V aggiuntivo

`GTARemoteBridge.asi` è il nostro modulo companion ScriptHook V. Non sostituisce e non modifica `NativeTrainer.asi`: i due moduli convivono.

Rende dirette e verificabili due azioni già implementate nel protocollo, Invincibilità/God Mode e Conserva veicoli distrutti. L'attuale UI iPhone non le espone, ma il bridge e il modulo mantengono il supporto per compatibilità e per una futura superficie esplicita.

Il binario `.asi` non è incluso nella release: in questo checkout non è disponibile un SDK/toolchain Windows ScriptHook V con cui produrlo in modo verificabile. Il sorgente è in [`Mods/GTARemoteBridge`](Mods/GTARemoteBridge) e le istruzioni di compilazione complete sono nel suo [README](Mods/GTARemoteBridge/README.md).

Per installarlo dopo averlo compilato:

1. Chiudi GTA e salva la partita.
2. Metti `GTARemoteBridge.asi` nella cartella che contiene `GTA5.exe`, accanto a `ScriptHookV.dll` e `dinput8.dll`.
3. Avvia GTA V Legacy in modalità Storia e verifica in `asiloader.log` le righe di caricamento del modulo.
4. Il bridge scrive `GTARemoteBridge.command`; il modulo pubblica `GTARemoteBridge.state` nella stessa cartella. Non modificare questi file mentre GTA è aperto.

Per un aggiornamento, prepara `GTARemoteBridge.asi.next` mentre GTA è chiuso, conserva una copia recuperabile del vecchio `.asi`, poi rinomina il nuovo file in `GTARemoteBridge.asi` e riavvia il gioco. ScriptHook carica i moduli soltanto all'avvio.

## Cosa include il repository

- `iOS/GTARemote`: app SwiftUI per iPhone, distribuita pubblicamente con TestFlight.
- `macOS/GTABridge`: bridge SwiftUI macOS nella barra dei menu.
- `Packages/GTAControlCore`: protocollo, pairing e canale cifrato.
- `Mods/GTARemoteBridge`: sorgente del modulo ScriptHook V aggiuntivo.
- [`docs/protocol.md`](docs/protocol.md) e [`docs/e2e-checklist.md`](docs/e2e-checklist.md): dettagli tecnici e verifica.

## Sviluppo

Il progetto Xcode è generato da `project.yml`:

```sh
xcodegen generate
swift test --package-path Packages/GTAControlCore
xcodebuild -project GTARemote.xcodeproj -scheme GTABridge -destination 'platform=macOS' test
xcodebuild -project GTARemote.xcodeproj -scheme GTARemote -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Per la pubblicazione iOS, imposta `ASC_KEY_FILEPATH` all'esterno del repository prima di eseguire Fastlane. Non archiviare chiavi API, profili o IPA nel repository.

## Limiti verificati

Le macro testuali non fanno parte della UX. Questa release resta intenzionalmente limitata a GTA V Legacy, Story Mode e rete locale.
