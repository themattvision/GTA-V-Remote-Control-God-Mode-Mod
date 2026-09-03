# GodMode Mod Remote Control per Windows

Il bridge Windows collega l'app GTA Remote su iPhone a GTA V Legacy in modalità Storia. Funziona nella tray di Windows, senza una finestra principale.

## Installazione

1. Estrai tutto lo ZIP in una cartella locale.
2. Avvia `GodMode Mod Remote Control.exe`.
3. Se Windows Defender Firewall lo chiede, consenti l'accesso soltanto sulle reti private.
4. Cerca l'icona del bridge nell'area di notifica, anche dentro il menu delle icone nascoste.
5. Dal menu dell'icona scegli `Seleziona cartella GTA V…` e indica la cartella che contiene `GTA5.exe`.
6. Apri GTA Remote sull'iPhone, confronta il codice a sei cifre e approva il pairing dal menu del bridge.

Se Windows SmartScreen segnala l'eseguibile, il motivo è che il build di sviluppo non è firmato. Non disattivare SmartScreen a livello globale.

## Uso sicuro

Il bridge invia tasti soltanto quando il processo in primo piano è `GTA5.exe` e l'eseguibile appartiene alla cartella autorizzata. Supporta soltanto i comandi compilati nell'app e non accetta tasti, testo, shell command o native hash arbitrari dalla rete.

La modalità diretta tramite `GTARemoteBridge.asi` usa gli stessi file locali del bridge Mac. Il file `.asi` deve essere accanto a `GTA5.exe`. Lo stato è considerato valido soltanto quando `GTARemoteBridge.state` è aggiornato da meno di due secondi.

GTA Online non è supportato.

## Verifica rapida

1. Avvia GTA V Legacy e entra in modalità Storia.
2. Nel menu del bridge scegli `Test F4 tra 3 secondi`.
3. Riporta GTA V in primo piano entro tre secondi.
4. Verifica che F4 apra o chiuda Native Trainer.

Per il test completo usa `docs/e2e-checklist.md` nel repository.

## Build da sorgente

Richiede PowerShell e .NET 8 SDK:

```powershell
.\Scripts\build-windows.ps1
```

Lo script esegue i test e crea `Windows-GodMode-Mod-Remote-Control-v0.3.0.zip`, uno ZIP x64 self-contained nella cartella Download dell'utente.
