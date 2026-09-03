import CryptoKit
import Foundation
import OSLog

public enum SecureChannelError: Error, Equatable, Sendable {
    case unsupportedVersion(received: UInt16, supported: UInt16)
    case exhaustedSequence
    case invalidSequence
    case authenticationFailed
    case replayDetected(sequence: UInt64)
    case sequenceMismatch(packet: UInt64, message: UInt64)
}

public struct EncryptedPacket: Codable, Equatable, Sendable {
    public let protocolVersion: UInt16
    public let sequence: UInt64
    public let combinedCiphertext: Data

    public init(
        protocolVersion: UInt16 = ProtocolConstants.version,
        sequence: UInt64,
        combinedCiphertext: Data
    ) {
        self.protocolVersion = protocolVersion
        self.sequence = sequence
        self.combinedCiphertext = combinedCiphertext
    }
}

public struct ReplayGuard: Sendable {
    public private(set) var highestSequence: UInt64?

    public init() {}

    public mutating func validateAndRecord(sequence: UInt64) throws {
        guard sequence > 0 else { throw SecureChannelError.invalidSequence }
        if let highestSequence, sequence <= highestSequence {
            throw SecureChannelError.replayDetected(sequence: sequence)
        }
        highestSequence = sequence
    }
}

public struct SecureChannel: Sendable {
    private static let logger = Logger(subsystem: "com.matteozampieri.gtacontrol", category: "SecureChannel")

    private let sessionKey: SessionKey
    private var nextSendingSequence: UInt64
    private var replayGuard: ReplayGuard

    public init(sessionKey: SessionKey) {
        self.sessionKey = sessionKey
        nextSendingSequence = 1
        replayGuard = ReplayGuard()
    }

    public mutating func seal(_ message: WireMessage) throws -> EncryptedPacket {
        guard nextSendingSequence > 0 else { throw SecureChannelError.exhaustedSequence }
        let sequence = nextSendingSequence
        let payload = try ProtocolCodec.encode(message)
        let sealed = try ChaChaPoly.seal(
            payload,
            using: sessionKey.cryptoKey,
            authenticating: Self.authenticatedData(
                protocolVersion: ProtocolConstants.version,
                sequence: sequence
            )
        )
        let combined = sealed.combined
        if nextSendingSequence == UInt64.max {
            nextSendingSequence = 0
        } else {
            nextSendingSequence += 1
        }
        return EncryptedPacket(sequence: sequence, combinedCiphertext: combined)
    }

    public mutating func open(_ packet: EncryptedPacket) throws -> WireMessage {
        guard packet.protocolVersion == ProtocolConstants.version else {
            throw SecureChannelError.unsupportedVersion(
                received: packet.protocolVersion,
                supported: ProtocolConstants.version
            )
        }
        guard packet.sequence > 0 else { throw SecureChannelError.invalidSequence }
        if let highest = replayGuard.highestSequence, packet.sequence <= highest {
            throw SecureChannelError.replayDetected(sequence: packet.sequence)
        }

        let payload: Data
        do {
            let box = try ChaChaPoly.SealedBox(combined: packet.combinedCiphertext)
            payload = try ChaChaPoly.open(
                box,
                using: sessionKey.cryptoKey,
                authenticating: Self.authenticatedData(
                    protocolVersion: packet.protocolVersion,
                    sequence: packet.sequence
                )
            )
        } catch {
            Self.logger.error("Authenticated packet rejected at sequence \(packet.sequence, privacy: .public)")
            throw SecureChannelError.authenticationFailed
        }

        try replayGuard.validateAndRecord(sequence: packet.sequence)
        let message = try ProtocolCodec.decode(payload)
        if let messageSequence = Self.embeddedSequence(in: message), messageSequence != packet.sequence {
            throw SecureChannelError.sequenceMismatch(
                packet: packet.sequence,
                message: messageSequence
            )
        }
        return message
    }

    private static func authenticatedData(protocolVersion: UInt16, sequence: UInt64) -> Data {
        var data = Data("GTAControl-Packet-v1".utf8)
        data.append(UInt8((protocolVersion >> 8) & 0xff))
        data.append(UInt8(protocolVersion & 0xff))
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((sequence >> UInt64(shift)) & 0xff))
        }
        return data
    }

    private static func embeddedSequence(in message: WireMessage) -> UInt64? {
        switch message {
        case let .command(command): command.envelope.sequence
        case let .heartbeat(heartbeat): heartbeat.sequence
        default: nil
        }
    }
}
