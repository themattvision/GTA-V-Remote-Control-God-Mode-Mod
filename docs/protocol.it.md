# Protocollo GTA Remote v3

Italiano | [English](protocol.md)

## Trasporto

- rilevamento Bonjour: `_gtactrl._tcp`
- trasporto: TCP tramite Network.framework
- framing: prefisso di lunghezza `UInt32` big-endian seguito dal payload
- dimensione massima del frame: 16.384 byte
- versione del protocollo: 3

## Comandi consentiti

Un peer non può inviare codici tasto, testo, comandi shell o native hash. Può inviare soltanto un valore `TrainerCommand` compilato nei due target, oppure i comandi espliciti `setGodMode(enabled:)` e `setWreckPreservation(enabled:)`.

Ogni comando include `clientID`, `requestID`, un numero di sequenza monotono e una versione del protocollo. Il bridge rifiuta versioni incompatibili, messaggi ripetuti, client non abbinati e più di 20 comandi al secondo.

I comandi diretti sono limitati a God Mode e conservazione dei veicoli distrutti. Il bridge li traduce in un file locale letto dal modulo ScriptHook sul thread di gioco. Il modulo restituisce un `TrainerStateSnapshot` con il valore confermato dal motore del gioco. La conservazione si applica soltanto ai veicoli guidati dal giocatore, fino a 12. Se lo stato non arriva o diventa obsoleto, l'iPhone disabilita l'interruttore invece di inventare un valore locale.

## Pairing

Il primo pairing usa uno scambio X25519 e mostra la stessa impronta numerica sull'iPhone e sul computer. L'utente la approva sul computer. Il segreto persistente viene conservato in Keychain sul Mac o protetto con DPAPI su Windows. Le sessioni successive derivano nuove chiavi con HKDF. I payload autenticati usano ChaCha20-Poly1305.

L'MVP può includere un trasporto diagnostico locale in chiaro soltanto dietro un flag esplicito di build Debug. Non deve mai essere attivo in Release.
