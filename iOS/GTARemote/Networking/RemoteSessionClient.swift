import Foundation
import GTAControlCore

enum RemoteClientEvent: Equatable, Sendable {
    case searching
    case connecting(deviceName: String)
    case pairingRequired(PairingPrompt)
    case connected(deviceName: String)
    case reconnecting(deviceName: String, attempt: Int)
    case disconnected(reason: String?)
    case failed(RemoteClientError)
    case trainerState(TrainerStateSnapshot)
}

enum RemoteClientError: Error, Equatable, Sendable {
    case notConnected
    case pairingRejected
    case invalidFingerprint
    case connectionLost
    case commandRejected(reason: String)
    case protocolFailure
}

struct CommandAcknowledgement: Equatable, Sendable {
    let requestID: UUID
    let sequence: UInt64
}

@MainActor
protocol RemoteSessionClient: AnyObject {
    var events: AsyncStream<RemoteClientEvent> { get }

    func start()
    func stop()
    func confirmPairing(_ prompt: PairingPrompt)
    func rejectPairing(_ prompt: PairingPrompt)
    func send(_ command: TrainerCommand) async throws -> CommandAcknowledgement
    func setGodMode(_ enabled: Bool) async throws -> CommandAcknowledgement
    func setWreckPreservation(_ enabled: Bool) async throws -> CommandAcknowledgement
}

@MainActor
protocol SuccessFeedbackProviding {
    func commandWasAcknowledged()
}
