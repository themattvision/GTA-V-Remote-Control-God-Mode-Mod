# Protocollo GTA Remote v3

## Trasporto

- Discovery Bonjour: `_gtactrl._tcp`
- Trasporto: TCP tramite Network.framework
- Framing: prefisso big-endian UInt32 seguito dal payload
- Dimensione massima frame: 16.384 byte
- Protocol version: 3

## Comandi autorizzati

Il peer non puo inviare keycode, testo, shell command o native hash. Puo inviare soltanto un valore dell'enum `TrainerCommand` compilato in entrambi i target oppure i comandi espliciti `setGodMode(enabled:)` e `setWreckPreservation(enabled:)`.

Ogni comando contiene `clientID`, `requestID`, sequence monotona e protocol version. Il bridge rifiuta versioni incompatibili, replay, client non associati e piu di 20 comandi al secondo.

I comandi diretti sono limitati a Invincibilita e Conserva i veicoli distrutti. Il bridge li traduce in un file locale che il modulo ScriptHook legge nel thread di GTA. Il modulo rimanda uno `TrainerStateSnapshot` con il valore che il motore di gioco ha effettivamente confermato. La conservazione riguarda soltanto i veicoli guidati dal giocatore e il modulo ne limita il numero a 12. Se lo stato non arriva o diventa vecchio, l'iPhone disabilita il toggle invece di inventare un valore locale.

## Pairing

Il primo pairing usa uno scambio X25519 e mostra la stessa impronta numerica su iPhone e Mac. L'approvazione avviene sul Mac. Il segreto persistente viene salvato nei Keychain e le sessioni successive derivano nuove chiavi con HKDF. I payload autenticati usano ChaChaPoly.

L'MVP puo includere un transport locale diagnostico in chiaro soltanto dietro una build flag Debug esplicita. Non deve essere attivo in Release.
