import Foundation

enum RemoteConnectionState: Equatable, Sendable {
    case idle
    case searching
    case connecting(deviceName: String)
    case awaitingPairing(PairingPrompt)
    case connected(deviceName: String)
    case reconnecting(deviceName: String, attempt: Int)
    case disconnected(reason: String?)

    var isConnected: Bool {
        if case .connected = self { true } else { false }
    }

    var deviceName: String? {
        switch self {
        case .connecting(let name), .connected(let name), .reconnecting(let name, _):
            name
        case .idle, .searching, .awaitingPairing, .disconnected:
            nil
        }
    }
}

struct PairingPrompt: Equatable, Sendable, Identifiable {
    let id: UUID
    let deviceName: String
    let fingerprint: String

    init(id: UUID = UUID(), deviceName: String, fingerprint: String) {
        self.id = id
        self.deviceName = deviceName
        self.fingerprint = fingerprint
    }
}
