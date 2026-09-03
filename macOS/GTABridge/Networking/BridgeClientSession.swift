@preconcurrency import Network
import Foundation
import GTAControlCore
import OSLog

@MainActor
protocol BridgeClientSessionDelegate: AnyObject {
    func session(_ session: BridgeClientSession, receivedHello hello: HelloMessage)
    func session(_ session: BridgeClientSession, authenticatedClient clientID: UUID)
    func session(_ session: BridgeClientSession, requestedPairing request: PairingRequest)
    func session(_ session: BridgeClientSession, receivedCommand command: CommandMessage) async
    func session(_ session: BridgeClientSession, receivedGodModeCommand command: GodModeCommandMessage) async
    func session(_ session: BridgeClientSession, receivedWreckPreservationCommand command: WreckPreservationCommandMessage) async
    func session(_ session: BridgeClientSession, failedWith error: Error)
    func sessionDidDisconnect(_ session: BridgeClientSession)
}

enum BridgeSessionError: Error, Equatable, LocalizedError {
    case controllerHelloRequired
    case helloRequired
    case pairingRequired
    case clientIdentityMismatch
    case unexpectedCleartextMessage
    case unexpectedSecureMessage
    case heartbeatRequired
    case malformedEncryptedPacket
    case connectionClosed

    var errorDescription: String? {
        switch self {
        case .controllerHelloRequired:
            "Il peer non si e identificato come controller."
        case .helloRequired:
            "Il client deve inviare hello prima degli altri messaggi."
        case .pairingRequired:
            "Il client non e associato a questo Mac."
        case .clientIdentityMismatch:
            "L'identita del client non coincide con la sessione."
        case .unexpectedCleartextMessage:
            "Messaggio non consentito in chiaro."
        case .unexpectedSecureMessage:
            "Messaggio cifrato non consentito in questa fase."
        case .heartbeatRequired:
            "Il client deve completare la prova cifrata prima di inviare comandi."
        case .malformedEncryptedPacket:
            "Pacchetto cifrato non valido."
        case .connectionClosed:
            "Connessione chiusa dal client."
        }
    }
}

@MainActor
final class BridgeClientSession: Identifiable {
    let id = UUID()
    private(set) var clientID: UUID?
    private var presentedClientID: UUID?

    private static let logger = Logger(
        subsystem: "com.matteozampieri.GTABridge",
        category: "ClientSession"
    )

    private let connection: NWConnection
    private let bridgeID: UUID
    private let sessionStore: KeychainSessionStore
    private weak var delegate: (any BridgeClientSessionDelegate)?
    private var frameDecoder = FrameDecoder()
    private var secureChannel: SecureChannel?
    private var hasAuthenticatedSecurePacket = false
    private var nextOutgoingSecureSequence: UInt64 = 1
    private var isCancelled = false

    init(
        connection: NWConnection,
        bridgeID: UUID,
        sessionStore: KeychainSessionStore,
        delegate: any BridgeClientSessionDelegate
    ) {
        self.connection = connection
        self.bridgeID = bridgeID
        self.sessionStore = sessionStore
        self.delegate = delegate
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state)
            }
        }
        connection.start(queue: .main)
        receiveNextChunk()
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        connection.cancel()
    }

    func activateSecureChannel(sessionKey: SessionKey, clientID: UUID) {
        self.clientID = clientID
        secureChannel = SecureChannel(sessionKey: sessionKey)
    }

    func sendPairingChallenge(_ challenge: PairingChallenge) async throws {
        try await sendClear(.pairingChallenge(challenge))
    }

    func sendPairingApproval(_ approval: PairingApproval) async throws {
        try await sendClear(.pairingApproval(approval))
    }

    func sendAcknowledgement(_ acknowledgement: AcknowledgementMessage) async throws {
        try await sendSecure(.acknowledgement(acknowledgement))
    }

    func sendTrainerState(_ snapshot: TrainerStateSnapshot) async throws {
        guard hasAuthenticatedSecurePacket else { return }
        try await sendSecure(.trainerState(TrainerStateMessage(snapshot: snapshot)))
    }

    func sendError(_ error: ProtocolErrorMessage, securely: Bool) async {
        do {
            if securely {
                try await sendSecure(.error(error))
            } else {
                try await sendClear(.error(error))
            }
        } catch {
            delegate?.session(self, failedWith: error)
        }
    }

    private func receiveNextChunk() {
        guard !isCancelled else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: ProtocolConstants.maximumFrameBytes + 4) {
            [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, !self.isCancelled else { return }

                if let data, !data.isEmpty {
                    do {
                        let frames = try self.frameDecoder.append(data)
                        for frame in frames {
                            try await self.handleFrame(frame)
                        }
                    } catch {
                        self.delegate?.session(self, failedWith: error)
                        self.cancel()
                        return
                    }
                }

                if let error {
                    self.delegate?.session(self, failedWith: error)
                    self.cancel()
                    return
                }

                if isComplete {
                    self.delegate?.session(self, failedWith: BridgeSessionError.connectionClosed)
                    self.cancel()
                    return
                }

                self.receiveNextChunk()
            }
        }
    }

    private func handleFrame(_ payload: Data) async throws {
        if clientID == nil {
            let message = try ProtocolCodec.decode(payload)
            try await handleClearMessage(message)
            return
        }

        // The controller Keychain can be reset independently from the Mac Keychain,
        // for example after reinstalling the iPhone app. Before the first authenticated
        // packet, allow that same announced client to restart pairing explicitly.
        if !hasAuthenticatedSecurePacket,
           let clearMessage = try? ProtocolCodec.decode(payload),
           case let .pairingRequest(request) = clearMessage,
           request.clientID == presentedClientID,
           let staleClientID = clientID {
            try sessionStore.removeSessionKey(for: staleClientID)
            clientID = nil
            secureChannel = nil
            nextOutgoingSecureSequence = 1
            try await handleClearMessage(clearMessage)
            return
        }

        guard var channel = secureChannel else {
            throw BridgeSessionError.pairingRequired
        }

        let packet: EncryptedPacket
        do {
            packet = try JSONDecoder().decode(EncryptedPacket.self, from: payload)
        } catch {
            throw BridgeSessionError.malformedEncryptedPacket
        }

        do {
            let message = try channel.open(packet)
            secureChannel = channel
            try await handleSecureMessage(message)
        } catch {
            secureChannel = channel
            throw error
        }
    }

    private func handleClearMessage(_ message: WireMessage) async throws {
        switch message {
        case let .hello(hello):
            guard hello.role == .controller else {
                throw BridgeSessionError.controllerHelloRequired
            }
            guard presentedClientID == nil || presentedClientID == hello.peerID else {
                throw BridgeSessionError.clientIdentityMismatch
            }

            presentedClientID = hello.peerID
            try await sendClear(.hello(HelloMessage(peerID: bridgeID, role: .bridge)))

            if let storedKey = try sessionStore.sessionKey(for: hello.peerID) {
                activateSecureChannel(sessionKey: storedKey, clientID: hello.peerID)
            }
            delegate?.session(self, receivedHello: hello)

        case let .pairingRequest(request):
            guard clientID == nil, request.clientID == presentedClientID else {
                throw BridgeSessionError.unexpectedCleartextMessage
            }
            delegate?.session(self, requestedPairing: request)

        default:
            throw clientID == nil
                ? BridgeSessionError.helloRequired
                : BridgeSessionError.unexpectedCleartextMessage
        }
    }

    private func handleSecureMessage(_ message: WireMessage) async throws {
        switch message {
        case let .command(command):
            guard hasAuthenticatedSecurePacket else {
                throw BridgeSessionError.heartbeatRequired
            }
            guard command.envelope.clientID == clientID else {
                throw BridgeSessionError.clientIdentityMismatch
            }
            await delegate?.session(self, receivedCommand: command)
        case let .godModeCommand(command):
            guard hasAuthenticatedSecurePacket else {
                throw BridgeSessionError.heartbeatRequired
            }
            guard command.clientID == clientID else {
                throw BridgeSessionError.clientIdentityMismatch
            }
            await delegate?.session(self, receivedGodModeCommand: command)
        case let .wreckPreservationCommand(command):
            guard hasAuthenticatedSecurePacket else {
                throw BridgeSessionError.heartbeatRequired
            }
            guard command.clientID == clientID else {
                throw BridgeSessionError.clientIdentityMismatch
            }
            await delegate?.session(self, receivedWreckPreservationCommand: command)
        case .heartbeat:
            try await sendHeartbeatResponse()
            if !hasAuthenticatedSecurePacket, let clientID {
                hasAuthenticatedSecurePacket = true
                delegate?.session(self, authenticatedClient: clientID)
            }
        default:
            throw BridgeSessionError.unexpectedSecureMessage
        }
    }

    private func sendClear(_ message: WireMessage) async throws {
        try await send(ProtocolCodec.encodeFrame(message))
    }

    private func sendSecure(_ message: WireMessage) async throws {
        guard var channel = secureChannel else {
            throw BridgeSessionError.pairingRequired
        }
        let packet = try channel.seal(message)
        secureChannel = channel
        if nextOutgoingSecureSequence == UInt64.max {
            nextOutgoingSecureSequence = 0
        } else {
            nextOutgoingSecureSequence += 1
        }
        try await send(FrameCodec.encode(packet))
    }

    private func sendHeartbeatResponse() async throws {
        guard nextOutgoingSecureSequence > 0 else {
            throw SecureChannelError.exhaustedSequence
        }
        try await sendSecure(
            .heartbeat(HeartbeatMessage(sequence: nextOutgoingSecureSequence))
        )
    }

    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .failed(let error):
            Self.logger.error("Client connection failed: \(error.localizedDescription, privacy: .public)")
            delegate?.session(self, failedWith: error)
            cancel()
        case .waiting(let error):
            Self.logger.info("Client connection waiting: \(error.localizedDescription, privacy: .public)")
        case .cancelled:
            delegate?.sessionDidDisconnect(self)
        default:
            break
        }
    }
}
