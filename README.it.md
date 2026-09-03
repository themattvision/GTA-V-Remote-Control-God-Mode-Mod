# GodMode Mod Remote Control

Italiano | [English](README.md)

GodMode Mod Remote Control è un telecomando locale composto da due parti per GTA V Legacy in modalità Storia. L'iPhone è il controller. GodMode Mod Remote Control è l'app nella tray di Windows o nella barra dei menu del Mac che collega il telefono al gioco.

È pensato per uso personale e offline sulla propria rete Wi-Fi. Non supporta GTA Online.

## Da dove iniziare

Prima di scaricare, assicurati di avere tutti questi elementi:

1. Un PC Windows 10 o 11 x64, oppure un Mac con macOS 15 o successivo. GodMode Mod Remote Control funziona su questo computer.
2. Un iPhone con iOS 18 o successivo. GTA Remote funziona su questo iPhone.
3. GTA V Legacy installato per la modalità Storia. Su Windows la procedura guidata aiuta a installare ScriptHook V se manca.
4. Computer e iPhone collegati alla stessa rete Wi-Fi. Disattiva eventuali VPN durante il pairing.

L'app iPhone non funziona da sola. Lascia GodMode Mod Remote Control attivo sul PC o sul Mac mentre usi l'iPhone.

## Installa l'app iPhone

1. Apri sull'iPhone il link [Partecipa a GTA Remote su TestFlight](https://testflight.apple.com/join/TfJtcUy3).
2. Se TestFlight non è installato, scaricalo dall'App Store e riapri il link.
3. Tocca Accetta, poi Installa.
4. Apri GTA Remote e, quando iOS chiede l'accesso alla rete locale, tocca Consenti.

### Stato TestFlight al 3 settembre 2026

Il build `0.3.0 (4)` è valido e pronto per i tester interni. Il link TestFlight pubblico è attivo, ma l'installazione esterna è ancora in attesa della Beta App Review di Apple. Se TestFlight indica che l'app non è disponibile, questo è il motivo. I tester interni possono già usare il build corrente.

Non scaricare un IPA da GitHub. TestFlight è il canale normale e supportato per installare l'app iPhone.

## Installa GodMode Mod Remote Control su Windows

1. Apri la [pagina della release v0.3.1](https://github.com/themattvision/GTA-V-Remote-Control-God-Mode-Mod/releases/tag/v0.3.1).
2. In Assets scarica `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.1.exe`.
3. Chiudi completamente GTA V e avvia il setup.
4. Conferma o seleziona la cartella che contiene `GTA5.exe`.
5. Se ScriptHook V manca, usa il collegamento ufficiale mostrato dal setup, scarica lo ZIP e selezionalo. Non estrarlo e non copiare i file a mano.
6. Completa il setup e apri GTA Remote sull'iPhone.

La procedura installa GodMode Mod Remote Control, la mod inclusa `GTARemoteBridge.asi`, i file ufficiali di ScriptHook scelti dall'utente, l'avvio automatico e la regola firewall per la rete privata. Crea un backup prima di sostituire file e durante la disinstallazione rimuove soltanto la nostra mod. ScriptHook V non può essere incluso o scaricato automaticamente perché il suo autore ne vieta la redistribuzione.

L'app si trova nell'area di notifica di Windows. Il suo nome è GodMode Mod Remote Control. GTA Remote è soltanto il controller per iPhone. Setup e app usano l'italiano quando Windows è impostato in italiano, altrimenti l'inglese. Il build Windows corrente non è firmato, quindi SmartScreen può mostrare un avviso. Non disattivare SmartScreen a livello globale.

Consulta la [guida completa per Windows](Windows/README.it.md), disponibile anche [in inglese](Windows/README.md).

## Installa GodMode Mod Remote Control sul Mac

1. Apri la [pagina della release v0.3.1](https://github.com/themattvision/GTA-V-Remote-Control-God-Mode-Mod/releases/tag/v0.3.1).
2. In Assets scarica `Mac-GodMode-Mod-Remote-Control-v0.3.1.dmg`.
3. Apri la DMG nel Finder.
4. Apri prima `1. START HERE.html`, con la procedura completa in italiano e inglese.
5. Trascina GodMode Mod Remote Control nella cartella Applicazioni mostrata nella finestra.
6. Apri GodMode Mod Remote Control da Applicazioni.

GodMode Mod Remote Control è un'app per la barra dei menu. Non apre una normale finestra e non rimane nel Dock. Cerca la sua icona a destra nella barra dei menu di macOS e lasciala attiva mentre usi GTA Remote.

Il download è firmato con Developer ID, autenticato da Apple e graffettato per la verifica offline di Gatekeeper.

### Consenti i due permessi sul Mac

Al primo utilizzo consenti:

1. Rete locale, per trovare l'iPhone sulla stessa rete Wi-Fi.
2. Accessibilità, per inviare gli input supportati alla finestra locale di GTA.

Se macOS non mostra la richiesta per Accessibilità, apri Impostazioni di Sistema, Privacy e sicurezza, Accessibilità e abilita GodMode Mod Remote Control. Chiudi e riapri l'app dopo aver cambiato il permesso.

## Abbina iPhone e computer

1. Avvia GodMode Mod Remote Control sul PC o sul Mac e lascialo attivo nella tray o nella barra dei menu.
2. Verifica che computer e iPhone siano sulla stessa rete Wi-Fi, non su una rete ospiti.
3. Apri GTA Remote sull'iPhone.
4. Seleziona il computer quando compare.
5. Confronta il numero di pairing mostrato sui due dispositivi.
6. Approva sul computer soltanto se i numeri coincidono.

Se il computer non compare, controlla in quest'ordine: entrambe le app aperte, stessa Wi-Fi non ospiti, VPN disattivate e accesso alla rete locale consentito. Su Windows verifica anche che il firewall consenta il bridge sulle reti private. Poi chiudi e riapri entrambe le app.

## Modulo aggiuntivo ScriptHook V

`GTARemoteBridge.asi` è il nostro modulo aggiuntivo ScriptHook V. Non sostituisce né modifica `NativeTrainer.asi` o una mod God Mode esistente. I moduli possono convivere.

Il modulo rende diretti e basati sullo stato reale questi controlli:

- God Mode
- conservazione dei veicoli distrutti, limitata a 12 veicoli guidati dal giocatore

L'interfaccia iPhone corrente non espone ancora questi due controlli. Modulo e protocollo restano inclusi per compatibilità del bridge e per futuri controlli verificati. Il setup Windows include il modulo x64 compilato e lo installa automaticamente.

Per build, installazione manuale e aggiornamento sicuro consulta il [README tecnico in italiano](Mods/GTARemoteBridge/README.it.md) o [in inglese](Mods/GTARemoteBridge/README.md).

## Contenuto del repository

- sorgente iPhone: `iOS/GTARemote`
- sorgente Mac: `macOS/GTABridge`
- sorgente e test Windows: `Windows/GTABridge.Windows` e `Windows/GTAControlCore.Windows.Tests`
- setup guidato Windows: `Installer/GodModeModRemoteControl.iss`
- protocollo locale sicuro condiviso: `Packages/GTAControlCore`
- sorgente del modulo ScriptHook V: `Mods/GTARemoteBridge`
- note di release e protocollo: `CHANGELOG.it.md`, `docs/protocol.it.md` e `docs/e2e-checklist.it.md`

## Sviluppatori

```sh
xcodegen generate
swift test --package-path Packages/GTAControlCore
xcodebuild -project GTARemote.xcodeproj -scheme GTABridge -configuration Release build
# In PowerShell su Windows:
.\Scripts\build-windows-installer.ps1
```

Le lane TestFlight sono in `fastlane/Fastfile`. Imposta `ASC_KEY_FILEPATH` a una chiave App Store Connect conservata fuori dal repository. Non committare chiavi API, profili, archivi o prodotti di build.

## Ambito e limiti noti

- Soltanto GTA V Legacy e modalità Storia.
- Soltanto rete Wi-Fi locale, senza relay internet.
- GTA Online non è supportato.
- Le macro testuali dei cheat sono escluse perché non erano affidabili nella configurazione Wine supportata.
