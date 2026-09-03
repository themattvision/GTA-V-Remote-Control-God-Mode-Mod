# GTARemoteBridge

Questo modulo ScriptHook V per la modalità Storia rende Invincibilità e Conserva i veicoli distrutti funzioni dirette e verificabili.

Il bridge macOS scrive una richiesta limitata a `setGodMode` o `setWreckPreservation` nella cartella GTA. Il modulo la legge dal game thread, chiama le native GTA necessarie e pubblica ogni 250 ms lo stato reale. Il telefono riceve quel risultato dal bridge, quindi non deduce mai lo stato dalla posizione del menu Native Trainer.

## File locali

Nella stessa cartella di `GTA5.exe`:

```text
GTARemoteBridge.command
version=1
requestID=<uuid>
action=setGodMode
enabled=1
```

```text
GTARemoteBridge.state
version=1
godMode=1
wreckPreservation=1
preservedWreckCount=2
```

Il file `.state` è valido soltanto se viene aggiornato negli ultimi due secondi. Questo evita di mostrare un vecchio stato quando GTA si chiude o il modulo smette di funzionare.

Quando `setWreckPreservation` e attivo, il modulo conserva fino a 12 veicoli che il giocatore ha guidato. Non scandisce o blocca tutti i veicoli del traffico, cosi la scena resta stabile e quando lo spegni la pulizia torna al motore di GTA.

## Build e installazione

Il sorgente richiede l'SDK di ScriptHook V dal sito ufficiale e un compilatore Windows x64. `ScriptHookV.def` genera la piccola import library necessaria per il toolchain MinGW, usando gli ordinali della `ScriptHookV.dll` già verificata per GTA Legacy 1.0.1180.2. Il risultato deve chiamarsi `GTARemoteBridge.asi` e trovarsi accanto a `GTA5.exe`, `ScriptHookV.dll` e `dinput8.dll`.

Per aggiornare il modulo mentre GTA e in esecuzione, preparare prima il nuovo binario come `GTARemoteBridge.asi.next`. Solo dopo che la partita e stata salvata e GTA e chiuso, spostare il file attivo in un backup recuperabile e rinominare `.asi.next` nel nome attivo. Script Hook carica i plugin solo all'avvio.

Non sostituisce `NativeTrainer.asi`: i due moduli convivono. È pensato esclusivamente per GTA V Legacy in modalità Storia, mai per GTA Online.
