# Registro modifiche

Italiano | [English](CHANGELOG.md)

## v0.3.1, 3 settembre 2026

- Pubblicato il bridge tray completo per Windows 10/11 x64 e il relativo setup guidato dallo stesso commit sorgente del tag di release.
- Aggiunti su Windows rilevamento Bonjour, pairing X25519, derivazione della sessione HKDF-SHA256, pacchetti ChaCha20-Poly1305, protezione dai replay, chiavi abbinate protette con DPAPI e limite esistente di 20 comandi al secondo.
- Aggiunto il controllo tastiera protetto tramite `SendInput`. I comandi vengono accettati soltanto mentre è in primo piano `GTA5.exe` della cartella configurata.
- Aggiunta l'integrazione con i file di stato e comando del modulo ScriptHook. Il setup include `GTARemoteBridge.asi` x64 compilato, importa quando necessario lo ZIP ufficiale scelto dall'utente, configura avvio automatico e firewall per rete privata, crea backup e durante la disinstallazione rimuove soltanto il nostro modulo.
- Localizzati in italiano e inglese il setup guidato e l'app nell'area di notifica, con selezione automatica dalla lingua di visualizzazione di Windows.
- Aggiunta la documentazione pubblica completa in italiano e inglese per installazione, sicurezza, protocollo, modulo, release e verifica.
- Aggiunti i metadata TestFlight in inglese senza sostituire o inviare nuovamente il build iPhone `0.3.0 (4)`.
- Aggiunto uno script locale riproducibile per creare la DMG macOS firmata, autenticata e graffettata.

## v0.3.0, 3 settembre 2026

- Prima consegna pubblica di GTA Remote per GTA V Legacy in modalità Storia.
- Build iPhone `0.3.0 (4)` reso disponibile ai tester interni TestFlight. Link pubblico attivato e build inviato alla Beta App Review di Apple.
- Aggiunta la DMG macOS autenticata e graffettata con la guida visibile `1. START HERE.html`.
- Documentati il limite alla rete Wi-Fi locale e alla modalità Storia, insieme al flusso di pairing sicuro.
