import Foundation

/// Stato letto dal modulo ScriptHook dentro GTA, non dedotto dalla posizione del menu.
public struct TrainerStateSnapshot: Codable, Equatable, Sendable {
    public let isDirectControlReady: Bool
    public let godModeEnabled: Bool?
    public let wreckPreservationEnabled: Bool?
    public let preservedWreckCount: Int?

    public init(
        isDirectControlReady: Bool,
        godModeEnabled: Bool?,
        wreckPreservationEnabled: Bool? = nil,
        preservedWreckCount: Int? = nil
    ) {
        self.isDirectControlReady = isDirectControlReady
        self.godModeEnabled = godModeEnabled
        self.wreckPreservationEnabled = wreckPreservationEnabled
        self.preservedWreckCount = preservedWreckCount
    }

    public static let unavailable = TrainerStateSnapshot(
        isDirectControlReady: false,
        godModeEnabled: nil,
        wreckPreservationEnabled: nil,
        preservedWreckCount: nil
    )
}

/// Richiesta diretta e circoscritta al modulo GTA. Non contiene testo, hash native o keycode.
public struct GodModeCommandMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let clientID: UUID
    public let requestID: UUID
    public let sequence: UInt64
    public let enabled: Bool

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        clientID: UUID,
        requestID: UUID = UUID(),
        sequence: UInt64,
        enabled: Bool
    ) {
        self.protocolVersion = protocolVersion
        self.clientID = clientID
        self.requestID = requestID
        self.sequence = sequence
        self.enabled = enabled
    }
}

/// Richiesta diretta e circoscritta ai veicoli guidati dal giocatore.
/// Il limite di conservazione è deciso dal modulo GTA, non dalla rete.
public struct WreckPreservationCommandMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let clientID: UUID
    public let requestID: UUID
    public let sequence: UInt64
    public let enabled: Bool

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        clientID: UUID,
        requestID: UUID = UUID(),
        sequence: UInt64,
        enabled: Bool
    ) {
        self.protocolVersion = protocolVersion
        self.clientID = clientID
        self.requestID = requestID
        self.sequence = sequence
        self.enabled = enabled
    }
}

public struct TrainerStateMessage: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let snapshot: TrainerStateSnapshot

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        snapshot: TrainerStateSnapshot
    ) {
        self.protocolVersion = protocolVersion
        self.snapshot = snapshot
    }
}
