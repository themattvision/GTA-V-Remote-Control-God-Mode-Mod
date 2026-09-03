# GodMode Mod Remote Control per Windows

Il bridge Windows collega l'app GTA Remote su iPhone a GTA V Legacy in modalità Storia. Funziona nella tray di Windows, senza una finestra principale.

## Installazione

1. Scarica `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.0.exe` dalla release GitHub.
2. Chiudi completamente GTA V e avvia il setup.
3. Conferma la cartella che contiene `GTA5.exe`. Il setup prova a trovarla da solo.
4. Se ScriptHook V non è già completo, premi il collegamento ufficiale mostrato, scarica lo ZIP e selezionalo nel setup. Non devi estrarlo.
5. Conferma l'uso esclusivo in modalità Storia e completa l'installazione.
6. Cerca GodMode Mod Remote Control nell'area di notifica, anche dentro il menu delle icone nascoste.
7. Apri GTA Remote sull'iPhone, confronta il codice a sei cifre e approva il pairing dal menu del bridge.

Il setup installa l'app Windows, `GTARemoteBridge.asi`, i componenti ufficiali presenti nello ZIP di ScriptHook V, l'avvio automatico e la regola firewall limitata alle reti private. Prima di sostituire file già presenti crea un backup. La disinstallazione rimuove la nostra mod ma lascia i file ScriptHook condivisi, che potrebbero servire ad altre mod.

ScriptHook V non può essere incluso nel setup perché il suo autore vieta la redistribuzione. Per questo rimane un solo passaggio esterno, il download dal sito ufficiale indicato dalla procedura guidata.

Se Windows SmartScreen segnala l'eseguibile, il motivo è che il build di sviluppo non è firmato. Non disattivare SmartScreen a livello globale.

## Uso sicuro

Il bridge invia tasti soltanto quando il processo in primo piano è `GTA5.exe` e l'eseguibile appartiene alla cartella autorizzata. Supporta soltanto i comandi compilati nell'app e non accetta tasti, testo, shell command o native hash arbitrari dalla rete.

La modalità diretta tramite `GTARemoteBridge.asi` usa gli stessi file locali del bridge Mac. Il setup colloca il file `.asi` accanto a `GTA5.exe`. Lo stato è considerato valido soltanto quando `GTARemoteBridge.state` è aggiornato da meno di due secondi.

GTA Online non è supportato.

## Verifica rapida

1. Avvia GTA V Legacy e entra in modalità Storia.
2. Nel menu del bridge scegli `Test F4 tra 3 secondi`.
3. Riporta GTA V in primo piano entro tre secondi.
4. Verifica che F4 apra o chiuda Native Trainer.

Per il test completo usa `docs/e2e-checklist.md` nel repository.

## Build dell'installer da sorgente

Richiede PowerShell, .NET 8 SDK, MinGW x64 con binutils e Inno Setup 6:

```powershell
.\Scripts\build-windows-installer.ps1
```

Lo script esegue i test, pubblica l'app self-contained, compila `GTARemoteBridge.asi` e crea `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.0.exe` nella cartella Download dell'utente.
