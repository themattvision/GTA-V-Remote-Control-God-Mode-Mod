import CryptoKit
import Foundation

public enum PairingError: Error, Equatable, Sendable {
    case invalidPrivateKey
    case invalidPublicKey
    case invalidSessionKey
    case invalidFingerprint
    case keyAgreementFailed
}

public struct PairingPublicKey: Codable, Equatable, Sendable {
    public let rawRepresentation: Data

    public init(rawRepresentation: Data) throws {
        guard rawRepresentation.count == 32 else { throw PairingError.invalidPublicKey }
        do {
            _ = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawRepresentation)
        } catch {
            throw PairingError.invalidPublicKey
        }
        self.rawRepresentation = rawRepresentation
    }

    fileprivate init(validatedRawRepresentation: Data) {
        rawRepresentation = validatedRawRepresentation
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(rawRepresentation: container.decode(Data.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawRepresentation)
    }
}

public struct PairingFingerprint: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: UInt32

    public init(value: UInt32) throws {
        guard value < 1_000_000 else { throw PairingError.invalidFingerprint }
        self.value = value
    }

    public var description: String {
        String(format: "%06u", value)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(value: container.decode(UInt32.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct SessionKey: Equatable, Sendable {
    public let rawRepresentation: Data

    public init(rawRepresentation: Data) throws {
        guard rawRepresentation.count == 32 else { throw PairingError.invalidSessionKey }
        self.rawRepresentation = rawRepresentation
    }

    fileprivate var symmetricKey: SymmetricKey {
        SymmetricKey(data: rawRepresentation)
    }
}

public struct PairingKeyPair: Sendable {
    private let privateKeyRepresentation: Data
    public let publicKey: PairingPublicKey

    public init() {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        privateKeyRepresentation = privateKey.rawRepresentation
        publicKey = PairingPublicKey(
            validatedRawRepresentation: privateKey.publicKey.rawRepresentation
        )
    }

    init(rawPrivateKey: Data) throws {
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        do {
            privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawPrivateKey)
        } catch {
            throw PairingError.invalidPrivateKey
        }
        privateKeyRepresentation = privateKey.rawRepresentation
        publicKey = try PairingPublicKey(rawRepresentation: privateKey.publicKey.rawRepresentation)
    }

    public func fingerprint(with remotePublicKey: PairingPublicKey) throws -> PairingFingerprint {
        let orderedKeys = Self.ordered(publicKey.rawRepresentation, remotePublicKey.rawRepresentation)
        var material = Data("GTAControl-Pairing-Fingerprint-v1".utf8)
        material.append(orderedKeys.0)
        material.append(orderedKeys.1)
        let digest = SHA256.hash(data: material)
        var number: UInt64 = 0
        for byte in digest.prefix(8) {
            number = (number << 8) | UInt64(byte)
        }
        return try PairingFingerprint(value: UInt32(number % 1_000_000))
    }

    public func deriveSessionKey(with remotePublicKey: PairingPublicKey) throws -> SessionKey {
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(
                rawRepresentation: privateKeyRepresentation
            )
            let remoteKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: remotePublicKey.rawRepresentation
            )
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: remoteKey)
            let orderedKeys = Self.ordered(publicKey.rawRepresentation, remotePublicKey.rawRepresentation)
            var sharedInfo = Data("GTAControl-Session-v1".utf8)
            sharedInfo.append(orderedKeys.0)
            sharedInfo.append(orderedKeys.1)
            let derived = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("GTAControl-HKDF-Salt-v1".utf8),
                sharedInfo: sharedInfo,
                outputByteCount: 32
            )
            let bytes = derived.withUnsafeBytes { Data($0) }
            return try SessionKey(rawRepresentation: bytes)
        } catch let error as PairingError {
            throw error
        } catch {
            throw PairingError.keyAgreementFailed
        }
    }

    private static func ordered(_ first: Data, _ second: Data) -> (Data, Data) {
        first.lexicographicallyPrecedes(second) ? (first, second) : (second, first)
    }
}

extension SessionKey {
    var cryptoKey: SymmetricKey { symmetricKey }
}
