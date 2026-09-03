import Foundation

struct RemoteAppError: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let what: String
    let why: String
    let how: String
    let canRetry: Bool

    init(
        id: UUID = UUID(),
        title: String,
        what: String,
        why: String,
        how: String,
        canRetry: Bool
    ) {
        self.id = id
        self.title = title
        self.what = what
        self.why = why
        self.how = how
        self.canRetry = canRetry
    }

    static func describe(_ error: any Error) -> RemoteAppError {
        if let clientError = error as? RemoteClientError {
            switch clientError {
            case .notConnected:
                return RemoteAppError(
                    title: "Mac non collegato",
                    what: "Il comando non è stato inviato.",
                    why: "La connessione con GTA Bridge non è attiva.",
                    how: "Controlla che iPhone e Mac siano sulla stessa rete Wi-Fi, poi riprova.",
                    canRetry: true
                )
            case .pairingRejected:
                return RemoteAppError(
                    title: "Associazione non confermata",
                    what: "Questo iPhone non è stato associato al Mac.",
                    why: "La richiesta è stata rifiutata o è scaduta.",
                    how: "Avvia di nuovo la ricerca e conferma lo stesso codice su entrambi i dispositivi.",
                    canRetry: true
                )
            case .invalidFingerprint:
                return RemoteAppError(
                    title: "Codice non valido",
                    what: "Il codice di associazione non può essere verificato.",
                    why: "Il Mac e l’iPhone non hanno mostrato la stessa impronta.",
                    how: "Annulla l’associazione e riprova. Non confermare codici diversi.",
                    canRetry: true
                )
            case .connectionLost:
                return RemoteAppError(
                    title: "Connessione interrotta",
                    what: "Il collegamento con il Mac si è interrotto.",
                    why: "La rete Wi-Fi o GTA Bridge non sono più disponibili.",
                    how: "L’app prova a riconnettersi. Verifica che GTA Bridge sia ancora aperto.",
                    canRetry: true
                )
            case .commandRejected(let reason):
                return RemoteAppError(
                    title: "Comando non eseguito",
                    what: "GTA Bridge ha rifiutato il comando.",
                    why: reason,
                    how: "Porta GTA V in primo piano e verifica i permessi Accessibilità sul Mac.",
                    canRetry: false
                )
            case .protocolFailure:
                return RemoteAppError(
                    title: "Versione non compatibile",
                    what: "iPhone e Mac non riescono a comunicare in modo sicuro.",
                    why: "Le due app usano versioni diverse del protocollo.",
                    how: "Aggiorna GTA Remote e GTA Bridge alla stessa versione.",
                    canRetry: false
                )
            }
        }

        return RemoteAppError(
            title: "Qualcosa non ha funzionato",
            what: "L’operazione non è stata completata.",
            why: "Si è verificato un errore inatteso.",
            how: "Riprova. Se continua, chiudi e riapri GTA Bridge sul Mac.",
            canRetry: true
        )
    }
}
