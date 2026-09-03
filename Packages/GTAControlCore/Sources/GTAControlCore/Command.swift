import Foundation

public enum ProtocolConstants {
    public static let version: UInt16 = 3
    public static let bonjourType = "_gtactrl._tcp"
    public static let maximumFrameBytes = 16_384
    public static let maximumCommandsPerSecond = 20
}

public enum TrainerCommand: String, Codable, CaseIterable, Sendable {
    case toggleTrainer
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case select
    case back
    case numpadBack
    case vehicleBoostUp
    case vehicleBoostDown
    case vehicleRockets
}

public struct CommandEnvelope: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let clientID: UUID
    public let requestID: UUID
    public let sequence: UInt64
    public let command: TrainerCommand

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        clientID: UUID,
        requestID: UUID = UUID(),
        sequence: UInt64,
        command: TrainerCommand
    ) {
        self.protocolVersion = protocolVersion
        self.clientID = clientID
        self.requestID = requestID
        self.sequence = sequence
        self.command = command
    }
}
