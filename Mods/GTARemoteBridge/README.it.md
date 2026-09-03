# GTARemoteBridge

Italiano | [English](README.md)

`GTARemoteBridge.asi` è un modulo aggiuntivo ScriptHook V per GTA V Legacy in modalità Storia. Fornisce controlli diretti e basati sullo stato reale per God Mode e conservazione dei veicoli distrutti.

Non sostituisce, altera o modifica `NativeTrainer.asi` o una mod God Mode esistente. È un modulo separato e può convivere con NativeTrainer.

La procedura guidata Windows compila questo sorgente come file `.asi` x64 e lo installa accanto a `GTA5.exe`. La compilazione manuale serve soltanto per lo sviluppo.

## Funzionamento

Il bridge scrive nei file locali una richiesta limitata a `setGodMode` o `setWreckPreservation`. Il modulo la legge sul thread di gioco di GTA, chiama le native necessarie e pubblica lo stato confermato ogni 250 ms.

Il telefono riceve lo stato dal bridge e non lo deduce dalla posizione del menu di NativeTrainer.

Quando la conservazione dei veicoli distrutti è attiva, il modulo mantiene fino a 12 veicoli guidati dal giocatore. Non analizza né blocca tutti i veicoli del traffico. Quando la funzione viene disattivata, riprende la normale pulizia di GTA.

## Requisiti

1. GTA V Legacy, soltanto per la modalità Storia.
2. L'SDK ufficiale ScriptHook V.
3. Un compilatore C++ Windows x64.
4. Un'installazione funzionante di ScriptHook V, con `ScriptHookV.dll` e `dinput8.dll` accanto a `GTA5.exe`.

Il file incluso `ScriptHookV.def` crea la piccola import library richiesta da MinGW. Usa gli ordinali verificati con `ScriptHookV.dll` per GTA Legacy 1.0.1180.2.

## Build e installazione

Gli utenti normali devono usare `Windows-GodMode-Mod-Remote-Control-Setup-v0.3.1.exe` dalla release GitHub. I passaggi seguenti servono agli sviluppatori.

1. Compila il sorgente con l'SDK ufficiale ScriptHook V e un compilatore Windows x64.
2. Verifica che il file prodotto si chiami esattamente `GTARemoteBridge.asi`.
3. Salva la partita e chiudi completamente GTA V.
4. Apri la cartella che contiene `GTA5.exe`.
5. Copia `GTARemoteBridge.asi` accanto a `GTA5.exe`, `ScriptHookV.dll` e `dinput8.dll`.
6. Avvia GTA V Legacy ed entra in modalità Storia.

Non installare il modulo in una sottocartella. I quattro file indicati devono essere nella stessa cartella principale di GTA.

## File locali di comando e stato

GodMode Mod Remote Control scrive `GTARemoteBridge.command`:

```text
version=1
requestID=<uuid>
action=setGodMode
enabled=1
```

Il modulo scrive `GTARemoteBridge.state`:

```text
version=1
godMode=1
wreckPreservation=1
preservedWreckCount=2
```

Lo stato è valido soltanto se aggiornato negli ultimi due secondi. Questo evita che il telefono mostri informazioni obsolete dopo la chiusura di GTA o l'arresto del modulo.

Non modificare manualmente questi file mentre GTA è in esecuzione.

## Aggiornamento sicuro

1. Salva la partita e chiudi completamente GTA V.
2. Copia il nuovo build nella cartella GTA con il nome `GTARemoteBridge.asi.next`.
3. Rinomina il file attivo con un nome di backup recuperabile.
4. Rinomina `GTARemoteBridge.asi.next` in `GTARemoteBridge.asi`.
5. Riavvia GTA V Legacy.

ScriptHook carica i moduli soltanto all'avvio del gioco. Non sostituire mai un file ASI attivo mentre GTA è aperto.

Questo modulo è esclusivamente per uso personale e locale in modalità Storia. GTA Online non è supportato.
