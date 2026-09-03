import Foundation
import GTAControlCore

enum BridgeListenerState: Equatable, Sendable {
    case stopped
    case starting
    case ready(port: UInt16)
    case failed(String)

    var title: String {
        switch self {
        case .stopped:
            "Fermo"
        case .starting:
            "Avvio"
        case let .ready(port):
            "In ascolto sulla porta \(port)"
        case .failed:
            "Errore listener"
        }
    }
}

enum BridgeConnectionState: Equatable, Sendable {
    case disconnected
    case authenticating(clientID: UUID)
    case connected(clientID: UUID)
    case awaitingPairing(clientID: UUID, fingerprint: PairingFingerprint)

    var clientID: UUID? {
        switch self {
        case .disconnected:
            nil
        case let .authenticating(clientID),
             let .connected(clientID),
             let .awaitingPairing(clientID, _):
            clientID
        }
    }
}

struct DiagnosticEntry: Identifiable, Equatable, Sendable {
    enum Level: String, Sendable {
        case info
        case success
        case warning
        case error
    }

    let id: UUID
    let date: Date
    let level: Level
    let message: String

    init(id: UUID = UUID(), date: Date = .now, level: Level, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.message = message
    }
}
