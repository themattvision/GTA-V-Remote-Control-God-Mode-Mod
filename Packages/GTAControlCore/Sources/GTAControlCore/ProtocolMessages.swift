import Foundation

public enum PeerRole: String, Codable, Equatable, Sendable {
    case controller
    case bridge
}

public struct HelloMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let peerID: UUID
    public let role: PeerRole

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        peerID: UUID,
        role: PeerRole
    ) {
        self.protocolVersion = protocolVersion
        self.peerID = peerID
        self.role = role
    }
}

public struct PairingRequest: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let clientID: UUID
    public let clientPublicKey: PairingPublicKey

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        clientID: UUID,
        clientPublicKey: PairingPublicKey
    ) {
        self.protocolVersion = protocolVersion
        self.clientID = clientID
        self.clientPublicKey = clientPublicKey
    }
}

public struct PairingChallenge: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let bridgeID: UUID
    public let bridgePublicKey: PairingPublicKey
    public let fingerprint: PairingFingerprint

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        bridgeID: UUID,
        bridgePublicKey: PairingPublicKey,
        fingerprint: PairingFingerprint
    ) {
        self.protocolVersion = protocolVersion
        self.bridgeID = bridgeID
        self.bridgePublicKey = bridgePublicKey
        self.fingerprint = fingerprint
    }
}

public struct PairingApproval: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let clientID: UUID
    public let bridgeID: UUID
    public let approved: Bool

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        clientID: UUID,
        bridgeID: UUID,
        approved: Bool
    ) {
        self.protocolVersion = protocolVersion
        self.clientID = clientID
        self.bridgeID = bridgeID
        self.approved = approved
    }
}

public struct CommandMessage: Codable, Equatable, Sendable {
    public let envelope: CommandEnvelope

    public init(envelope: CommandEnvelope) {
        self.envelope = envelope
    }

    public var protocolVersion: UInt16 { envelope.protocolVersion }
}

public enum AcknowledgementStatus: String, Codable, Equatable, Sendable {
    case accepted
    case rejected
}

public struct AcknowledgementMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let requestID: UUID
    public let sequence: UInt64
    public let status: AcknowledgementStatus

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        requestID: UUID,
        sequence: UInt64,
        status: AcknowledgementStatus
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.sequence = sequence
        self.status = status
    }
}

public enum ProtocolErrorCode: String, Codable, Equatable, Sendable {
    case unsupportedVersion
    case malformedMessage
    case pairingDenied
    case authenticationFailed
    case replayDetected
    case rateLimited
    case invalidSequence
    case commandRejected
}

public struct ProtocolErrorMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let requestID: UUID?
    public let code: ProtocolErrorCode

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        requestID: UUID? = nil,
        code: ProtocolErrorCode
    ) {
        self.protocolVersion = protocolVersion
        self.requestID = requestID
        self.code = code
    }
}

public struct HeartbeatMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let sequence: UInt64

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        sequence: UInt64
    ) {
        self.protocolVersion = protocolVersion
        self.sequence = sequence
    }
}

public enum WireMessage: Codable, Equatable, Sendable {
    case hello(HelloMessage)
    case pairingRequest(PairingRequest)
    case pairingChallenge(PairingChallenge)
    case pairingApproval(PairingApproval)
    case command(CommandMessage)
    case godModeCommand(GodModeCommandMessage)
    case wreckPreservationCommand(WreckPreservationCommandMessage)
    case acknowledgement(AcknowledgementMessage)
    case error(ProtocolErrorMessage)
    case heartbeat(HeartbeatMessage)
    case trainerState(TrainerStateMessage)

    public var protocolVersion: UInt16 {
        switch self {
        case let .hello(message): message.protocolVersion
        case let .pairingRequest(message): message.protocolVersion
        case let .pairingChallenge(message): message.protocolVersion
        case let .pairingApproval(message): message.protocolVersion
        case let .command(message): message.protocolVersion
        case let .godModeCommand(message): message.protocolVersion
        case let .wreckPreservationCommand(message): message.protocolVersion
        case let .acknowledgement(message): message.protocolVersion
        case let .error(message): message.protocolVersion
        case let .heartbeat(message): message.protocolVersion
        case let .trainerState(message): message.protocolVersion
        }
    }

    private enum Kind: String, Codable {
        case hello
        case pairingRequest
        case pairingChallenge
        case pairingApproval
        case command
        case godModeCommand
        case wreckPreservationCommand
        case acknowledgement
        case error
        case heartbeat
        case trainerState
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .hello:
            self = try .hello(container.decode(HelloMessage.self, forKey: .payload))
        case .pairingRequest:
            self = try .pairingRequest(container.decode(PairingRequest.self, forKey: .payload))
        case .pairingChallenge:
            self = try .pairingChallenge(container.decode(PairingChallenge.self, forKey: .payload))
        case .pairingApproval:
            self = try .pairingApproval(container.decode(PairingApproval.self, forKey: .payload))
        case .command:
            self = try .command(container.decode(CommandMessage.self, forKey: .payload))
        case .godModeCommand:
            self = try .godModeCommand(container.decode(GodModeCommandMessage.self, forKey: .payload))
        case .wreckPreservationCommand:
            self = try .wreckPreservationCommand(container.decode(WreckPreservationCommandMessage.self, forKey: .payload))
        case .acknowledgement:
            self = try .acknowledgement(container.decode(AcknowledgementMessage.self, forKey: .payload))
        case .error:
            self = try .error(container.decode(ProtocolErrorMessage.self, forKey: .payload))
        case .heartbeat:
            self = try .heartbeat(container.decode(HeartbeatMessage.self, forKey: .payload))
        case .trainerState:
            self = try .trainerState(container.decode(TrainerStateMessage.self, forKey: .payload))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .hello(message):
            try container.encode(Kind.hello, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .pairingRequest(message):
            try container.encode(Kind.pairingRequest, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .pairingChallenge(message):
            try container.encode(Kind.pairingChallenge, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .pairingApproval(message):
            try container.encode(Kind.pairingApproval, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .command(message):
            try container.encode(Kind.command, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .godModeCommand(message):
            try container.encode(Kind.godModeCommand, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .wreckPreservationCommand(message):
            try container.encode(Kind.wreckPreservationCommand, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .acknowledgement(message):
            try container.encode(Kind.acknowledgement, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .error(message):
            try container.encode(Kind.error, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .heartbeat(message):
            try container.encode(Kind.heartbeat, forKey: .kind)
            try container.encode(message, forKey: .payload)
        case let .trainerState(message):
            try container.encode(Kind.trainerState, forKey: .kind)
            try container.encode(message, forKey: .payload)
        }
    }
}
