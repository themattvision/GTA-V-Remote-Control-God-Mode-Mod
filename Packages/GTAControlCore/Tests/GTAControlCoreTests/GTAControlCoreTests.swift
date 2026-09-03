import Foundation
import Testing
@testable import GTAControlCore

@Suite("Protocol messages and framing")
struct ProtocolAndFramingTests {
    private let clientID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let bridgeID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let requestID = UUID(uuidString: "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB")!

    @Test("Every wire message round-trips through the protocol codec")
    func messageRoundTrips() throws {
        let fingerprint = try PairingFingerprint(value: 42)
        let publicKey = try PairingPublicKey(rawRepresentation: Data(repeating: 7, count: 32))
        let envelope = CommandEnvelope(
            clientID: clientID,
            requestID: requestID,
            sequence: 7,
            command: .vehicleRockets
        )
        let messages: [WireMessage] = [
            .hello(HelloMessage(peerID: clientID, role: .controller)),
            .pairingRequest(PairingRequest(clientID: clientID, clientPublicKey: publicKey)),
            .pairingChallenge(
                PairingChallenge(
                    bridgeID: bridgeID,
                    bridgePublicKey: publicKey,
                    fingerprint: fingerprint
                )
            ),
            .pairingApproval(
                PairingApproval(clientID: clientID, bridgeID: bridgeID, approved: true)
            ),
            .command(CommandMessage(envelope: envelope)),
            .godModeCommand(
                GodModeCommandMessage(
                    clientID: clientID,
                    requestID: requestID,
                    sequence: 8,
                    enabled: true
                )
            ),
            .wreckPreservationCommand(
                WreckPreservationCommandMessage(
                    clientID: clientID,
                    requestID: requestID,
                    sequence: 9,
                    enabled: true
                )
            ),
            .acknowledgement(
                AcknowledgementMessage(
                    requestID: requestID,
                    sequence: 7,
                    status: .accepted
                )
            ),
            .error(ProtocolErrorMessage(requestID: requestID, code: .rateLimited)),
            .heartbeat(HeartbeatMessage(sequence: 8)),
            .trainerState(
                TrainerStateMessage(
                    snapshot: TrainerStateSnapshot(
                        isDirectControlReady: true,
                        godModeEnabled: true,
                        wreckPreservationEnabled: true,
                        preservedWreckCount: 3
                    )
                )
            ),
        ]

        for message in messages {
            let encoded = try ProtocolCodec.encode(message)
            #expect(try ProtocolCodec.decode(encoded) == message)
        }
    }

    @Test("Partial frames are buffered until complete")
    func partialFrame() throws {
        let message = WireMessage.hello(HelloMessage(peerID: clientID, role: .controller))
        let frame = try ProtocolCodec.encodeFrame(message)
        var decoder = FrameDecoder()

        #expect(try decoder.append(frame.prefix(2)).isEmpty)
        #expect(try decoder.append(frame.dropFirst(2).prefix(5)).isEmpty)
        let frames = try decoder.append(frame.dropFirst(7))

        #expect(frames.count == 1)
        #expect(try ProtocolCodec.decode(frames[0]) == message)
    }

    @Test("Multiple frames in one chunk are decoded independently")
    func multipleFrames() throws {
        let first = WireMessage.hello(HelloMessage(peerID: clientID, role: .controller))
        let second = WireMessage.heartbeat(HeartbeatMessage(sequence: 1))
        var chunk = try ProtocolCodec.encodeFrame(first)
        chunk.append(try ProtocolCodec.encodeFrame(second))
        var decoder = FrameDecoder()

        let frames = try decoder.append(chunk)

        #expect(frames.count == 2)
        #expect(try ProtocolCodec.decode(frames[0]) == first)
        #expect(try ProtocolCodec.decode(frames[1]) == second)
    }

    @Test("Oversized outgoing and incoming frames are rejected")
    func oversizedFrame() throws {
        let oversized = Data(repeating: 0, count: ProtocolConstants.maximumFrameBytes + 1)
        #expect(throws: FrameCodecError.self) {
            try FrameCodec.encodePayload(oversized)
        }

        let declaredLength = UInt32(ProtocolConstants.maximumFrameBytes + 1)
        let header = Data([
            UInt8((declaredLength >> 24) & 0xff),
            UInt8((declaredLength >> 16) & 0xff),
            UInt8((declaredLength >> 8) & 0xff),
            UInt8(declaredLength & 0xff),
        ])
        var decoder = FrameDecoder()
        #expect(throws: FrameCodecError.self) {
            try decoder.append(header)
        }
    }

    @Test("A mismatched protocol version is rejected")
    func mismatchedVersion() throws {
        let message = WireMessage.heartbeat(
            HeartbeatMessage(protocolVersion: ProtocolConstants.version + 1, sequence: 1)
        )
        let payload = try ProtocolCodec.encode(message)

        #expect {
            try ProtocolCodec.decode(payload)
        } throws: { error in
            error as? FrameCodecError == .unsupportedVersion(
                received: ProtocolConstants.version + 1,
                supported: ProtocolConstants.version
            )
        }
    }
}

@Suite("Pairing and secure channel")
struct PairingAndSecureChannelTests {
    @Test("X25519 peers derive the same session key and fingerprint")
    func agreementAndFingerprint() throws {
        let first = PairingKeyPair()
        let second = PairingKeyPair()

        let firstSession = try first.deriveSessionKey(with: second.publicKey)
        let secondSession = try second.deriveSessionKey(with: first.publicKey)
        let firstFingerprint = try first.fingerprint(with: second.publicKey)
        let secondFingerprint = try second.fingerprint(with: first.publicKey)

        #expect(firstSession == secondSession)
        #expect(firstFingerprint == secondFingerprint)
        #expect(firstFingerprint.description.count == 6)
    }

    @Test("Fingerprint is deterministic for fixed X25519 keys")
    func deterministicFingerprint() throws {
        let first = try PairingKeyPair(rawPrivateKey: Data(0..<32))
        let second = try PairingKeyPair(rawPrivateKey: Data((32..<64).reversed()))

        let fingerprint = try first.fingerprint(with: second.publicKey)
        let reverseFingerprint = try second.fingerprint(with: first.publicKey)
        let repeatedFingerprint = try first.fingerprint(with: second.publicKey)

        #expect(fingerprint == reverseFingerprint)
        #expect(fingerprint.description == repeatedFingerprint.description)
        #expect(first.publicKey.rawRepresentation.hexString == "8f40c5adb68f25624ae5b214ea767a6ec94d829d3d7b5e1ad1ba6f3e2138285f")
        #expect(second.publicKey.rawRepresentation.hexString == "bf64bf0c8e37b3ecf7d4ae82e592a25c37b8a78ce450a721f3079c3372796e5c")
        #expect(fingerprint.value == 105_389)
        #expect(try first.deriveSessionKey(with: second.publicKey).rawRepresentation.hexString == "4165ae8cd29550fc66a3438e0aa958952294d9459235761beb0240c35bba5ae0")
    }

    @Test("ChaChaPoly round-trips and detects tampering without consuming sequence")
    func authenticatedEncryptionAndTamper() throws {
        let key = try SessionKey(rawRepresentation: Data(repeating: 0x5a, count: 32))
        var sender = SecureChannel(sessionKey: key)
        var receiver = SecureChannel(sessionKey: key)
        let original = WireMessage.heartbeat(HeartbeatMessage(sequence: 1))
        let packet = try sender.seal(original)
        var tamperedBytes = packet.combinedCiphertext
        tamperedBytes[tamperedBytes.index(before: tamperedBytes.endIndex)] ^= 0x01
        let tampered = EncryptedPacket(
            sequence: packet.sequence,
            combinedCiphertext: tamperedBytes
        )

        #expect(throws: SecureChannelError.authenticationFailed) {
            try receiver.open(tampered)
        }
        #expect(try receiver.open(packet) == original)
    }

    @Test("A previously accepted packet is rejected as replay")
    func replayProtection() throws {
        let key = try SessionKey(rawRepresentation: Data(repeating: 0x3c, count: 32))
        var sender = SecureChannel(sessionKey: key)
        var receiver = SecureChannel(sessionKey: key)
        let packet = try sender.seal(.heartbeat(HeartbeatMessage(sequence: 1)))

        _ = try receiver.open(packet)
        #expect(throws: SecureChannelError.replayDetected(sequence: 1)) {
            try receiver.open(packet)
        }
    }
}

private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

@Suite("Rate limiting")
struct RateLimiterTests {
    @Test("No more than twenty commands are accepted per second")
    func twentyPerSecond() {
        var limiter = RateLimiter()
        let start = ContinuousClock.now

        for _ in 0..<ProtocolConstants.maximumCommandsPerSecond {
            let allowed = limiter.allow(at: start)
            #expect(allowed)
        }
        let rejected = limiter.allow(at: start)
        let allowedAfterWindow = limiter.allow(at: start.advanced(by: .seconds(1)))
        #expect(!rejected)
        #expect(allowedAfterWindow)
    }
}
