@preconcurrency import Network
import Foundation
import GTAControlCore
import OSLog

@MainActor
protocol BridgeListenerDelegate: AnyObject {
    func bridgeListener(_ listener: BridgeListener, changedState state: BridgeListenerState)
    func bridgeListener(_ listener: BridgeListener, connectedClient clientID: UUID)
    func bridgeListener(_ listener: BridgeListener, authenticatingClient clientID: UUID)
    func bridgeListener(_ listener: BridgeListener, disconnectedClient clientID: UUID?)
    func bridgeListener(
        _ listener: BridgeListener,
        requestsPairingFor clientID: UUID,
        fingerprint: PairingFingerprint
    )
    func bridgeListener(_ listener: BridgeListener, received command: TrainerCommand) async throws
    func bridgeListener(_ listener: BridgeListener, setsGodMode enabled: Bool) async throws
    func bridgeListener(_ listener: BridgeListener, setsWreckPreservation enabled: Bool) async throws
    func bridgeListener(_ listener: BridgeListener, diagnostic level: DiagnosticEntry.Level, message: String)
}

enum BridgeListenerError: Error, LocalizedError {
    case invalidClientPublicKey
    case noPendingPairing
    case pairingClientMismatch

    var errorDescription: String? {
        switch self {
        case .invalidClientPublicKey:
            "La chiave pubblica del client non e valida."
        case .noPendingPairing:
            "Non c'e una richiesta di pairing da approvare."
        case .pairingClientMismatch:
            "La richiesta di pairing non appartiene al client attivo."
        }
    }
}

@MainActor
final class BridgeListener: BridgeClientSessionDelegate {
    private struct PendingPairing {
        let clientID: UUID
        let keyPair: PairingKeyPair
        let sessionKey: SessionKey
        let fingerprint: PairingFingerprint
        let session: BridgeClientSession
    }

    private static let logger = Logger(
        subsystem: "com.matteozampieri.GTABridge",
        category: "Listener"
    )

    private let bridgeID: UUID
    private let sessionStore: KeychainSessionStore
    private weak var delegate: (any BridgeListenerDelegate)?
    private var listener: NWListener?
    private var sessions: [UUID: BridgeClientSession] = [:]
    private var pendingPairing: PendingPairing?
    private var rateLimiters: [UUID: RateLimiter] = [:]
    private var lastTrainerState = TrainerStateSnapshot.unavailable

    init(
        bridgeID: UUID,
        sessionStore: KeychainSessionStore,
        delegate: any BridgeListenerDelegate
    ) {
        self.bridgeID = bridgeID
        self.sessionStore = sessionStore
        self.delegate = delegate
    }

    func start() {
        guard listener == nil else { return }
        delegate?.bridgeListener(self, changedState: .starting)

        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: "GodMode Mod Remote Control",
                type: ProtocolConstants.bonjourType,
                domain: nil,
                txtRecord: nil
            )
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch {
            delegate?.bridgeListener(self, changedState: .failed(error.localizedDescription))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        pendingPairing = nil
        for session in sessions.values {
            session.cancel()
        }
        sessions.removeAll()
        delegate?.bridgeListener(self, changedState: .stopped)
    }

    func resolvePendingPairing(approved: Bool) async throws {
        guard let pendingPairing else {
            throw BridgeListenerError.noPendingPairing
        }

        let approval = PairingApproval(
            clientID: pendingPairing.clientID,
            bridgeID: bridgeID,
            approved: approved
        )

        if approved {
            try sessionStore.save(pendingPairing.sessionKey, for: pendingPairing.clientID)
            pendingPairing.session.activateSecureChannel(
                sessionKey: pendingPairing.sessionKey,
                clientID: pendingPairing.clientID
            )
            do {
                try await pendingPairing.session.sendPairingApproval(approval)
            } catch {
                try? sessionStore.removeSessionKey(for: pendingPairing.clientID)
                pendingPairing.session.cancel()
                throw error
            }
            delegate?.bridgeListener(self, authenticatingClient: pendingPairing.clientID)
            delegate?.bridgeListener(
                self,
                diagnostic: .success,
                message: "Pairing confermato, attendo la prova cifrata del client."
            )
        } else {
            try await pendingPairing.session.sendPairingApproval(approval)
            delegate?.bridgeListener(self, disconnectedClient: pendingPairing.clientID)
            delegate?.bridgeListener(
                self,
                diagnostic: .warning,
                message: "Pairing rifiutato e confermato al client."
            )
        }

        self.pendingPairing = nil
    }

    func publishTrainerState(_ snapshot: TrainerStateSnapshot) async {
        lastTrainerState = snapshot
        for session in sessions.values {
            do {
                try await session.sendTrainerState(snapshot)
            } catch {
                delegate?.bridgeListener(self, diagnostic: .error, message: error.localizedDescription)
            }
        }
    }

    func session(_ session: BridgeClientSession, receivedHello hello: HelloMessage) {
        Self.logger.notice("Hello received from controller \(hello.peerID.uuidString, privacy: .private(mask: .hash))")
        do {
            if try sessionStore.sessionKey(for: hello.peerID) != nil {
                rateLimiters[hello.peerID] = RateLimiter()
                delegate?.bridgeListener(self, authenticatingClient: hello.peerID)
                delegate?.bridgeListener(
                    self,
                    diagnostic: .info,
                    message: "Chiave nota, attendo la prova cifrata del client."
                )
            } else {
                delegate?.bridgeListener(
                    self,
                    diagnostic: .info,
                    message: "Client rilevato, pairing necessario."
                )
            }
        } catch {
            self.session(session, failedWith: error)
        }
    }

    func session(_ session: BridgeClientSession, authenticatedClient clientID: UUID) {
        delegate?.bridgeListener(self, connectedClient: clientID)
        Task {
            try? await session.sendTrainerState(lastTrainerState)
        }
    }

    func session(_ session: BridgeClientSession, requestedPairing request: PairingRequest) {
        Self.logger.notice("Pairing requested by \(request.clientID.uuidString, privacy: .private(mask: .hash))")
        do {
            guard pendingPairing == nil else {
                throw BridgeListenerError.noPendingPairing
            }
            let clientPublicKey = request.clientPublicKey
            let keyPair = PairingKeyPair()
            let fingerprint = try keyPair.fingerprint(with: clientPublicKey)
            let sessionKey = try keyPair.deriveSessionKey(with: clientPublicKey)
            let challenge = PairingChallenge(
                bridgeID: bridgeID,
                bridgePublicKey: keyPair.publicKey,
                fingerprint: fingerprint
            )
            pendingPairing = PendingPairing(
                clientID: request.clientID,
                keyPair: keyPair,
                sessionKey: sessionKey,
                fingerprint: fingerprint,
                session: session
            )

            Task {
                do {
                    try await session.sendPairingChallenge(challenge)
                    delegate?.bridgeListener(
                        self,
                        requestsPairingFor: request.clientID,
                        fingerprint: fingerprint
                    )
                } catch {
                    self.session(session, failedWith: error)
                }
            }
        } catch {
            self.session(session, failedWith: error)
        }
    }

    func session(_ session: BridgeClientSession, receivedCommand command: CommandMessage) async {
        let envelope = command.envelope
        guard envelope.clientID == session.clientID else {
            await reject(command, on: session, code: .authenticationFailed)
            return
        }

        var rateLimiter = rateLimiters[envelope.clientID, default: RateLimiter()]
        guard rateLimiter.allow() else {
            rateLimiters[envelope.clientID] = rateLimiter
            await reject(command, on: session, code: .rateLimited)
            return
        }
        rateLimiters[envelope.clientID] = rateLimiter

        do {
            try await delegate?.bridgeListener(self, received: envelope.command)
            let acknowledgement = AcknowledgementMessage(
                requestID: envelope.requestID,
                sequence: envelope.sequence,
                status: .accepted
            )
            try await session.sendAcknowledgement(acknowledgement)
            delegate?.bridgeListener(
                self,
                diagnostic: .success,
                message: "Comando \(envelope.command.rawValue) eseguito, ACK inviato."
            )
        } catch {
            await reject(command, on: session, code: .commandRejected)
            delegate?.bridgeListener(
                self,
                diagnostic: .error,
                message: error.localizedDescription
            )
        }
    }

    func session(_ session: BridgeClientSession, receivedGodModeCommand command: GodModeCommandMessage) async {
        guard command.clientID == session.clientID else {
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .authenticationFailed)
            return
        }

        var rateLimiter = rateLimiters[command.clientID, default: RateLimiter()]
        guard rateLimiter.allow() else {
            rateLimiters[command.clientID] = rateLimiter
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .rateLimited)
            return
        }
        rateLimiters[command.clientID] = rateLimiter

        do {
            try await delegate?.bridgeListener(self, setsGodMode: command.enabled)
            try await session.sendAcknowledgement(
                AcknowledgementMessage(
                    requestID: command.requestID,
                    sequence: command.sequence,
                    status: .accepted
                )
            )
            delegate?.bridgeListener(
                self,
                diagnostic: .success,
                message: command.enabled ? "Invincibilita richiesta." : "Invincibilita disattivata."
            )
        } catch {
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .commandRejected)
            delegate?.bridgeListener(self, diagnostic: .error, message: error.localizedDescription)
        }
    }

    func session(
        _ session: BridgeClientSession,
        receivedWreckPreservationCommand command: WreckPreservationCommandMessage
    ) async {
        guard command.clientID == session.clientID else {
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .authenticationFailed)
            return
        }

        var rateLimiter = rateLimiters[command.clientID, default: RateLimiter()]
        guard rateLimiter.allow() else {
            rateLimiters[command.clientID] = rateLimiter
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .rateLimited)
            return
        }
        rateLimiters[command.clientID] = rateLimiter

        do {
            try await delegate?.bridgeListener(self, setsWreckPreservation: command.enabled)
            try await session.sendAcknowledgement(
                AcknowledgementMessage(
                    requestID: command.requestID,
                    sequence: command.sequence,
                    status: .accepted
                )
            )
            delegate?.bridgeListener(
                self,
                diagnostic: .success,
                message: command.enabled ? "Conservazione dei veicoli attivata." : "Conservazione dei veicoli disattivata."
            )
        } catch {
            await reject(requestID: command.requestID, sequence: command.sequence, on: session, code: .commandRejected)
            delegate?.bridgeListener(self, diagnostic: .error, message: error.localizedDescription)
        }
    }

    func session(_ session: BridgeClientSession, failedWith error: Error) {
        Self.logger.error("Client session rejected: \(String(reflecting: error), privacy: .public)")
        delegate?.bridgeListener(self, diagnostic: .error, message: error.localizedDescription)
        session.cancel()
    }

    func sessionDidDisconnect(_ session: BridgeClientSession) {
        sessions.removeValue(forKey: session.id)
        if pendingPairing?.session === session {
            pendingPairing = nil
        }
        delegate?.bridgeListener(self, disconnectedClient: session.clientID)
    }

    private func reject(
        _ command: CommandMessage,
        on session: BridgeClientSession,
        code: ProtocolErrorCode
    ) async {
        let envelope = command.envelope
        await reject(
            requestID: envelope.requestID,
            sequence: envelope.sequence,
            on: session,
            code: code
        )
    }

    private func reject(
        requestID: UUID,
        sequence: UInt64,
        on session: BridgeClientSession,
        code: ProtocolErrorCode
    ) async {
        let acknowledgement = AcknowledgementMessage(
            requestID: requestID,
            sequence: sequence,
            status: .rejected
        )
        do {
            try await session.sendAcknowledgement(acknowledgement)
            delegate?.bridgeListener(
                self,
                diagnostic: .warning,
                message: "Comando rifiutato (\(code.rawValue)), ACK inviato."
            )
        } catch {
            delegate?.bridgeListener(self, diagnostic: .error, message: error.localizedDescription)
        }
    }

    private func accept(_ connection: NWConnection) {
        Self.logger.notice("Incoming controller connection accepted")
        let session = BridgeClientSession(
            connection: connection,
            bridgeID: bridgeID,
            sessionStore: sessionStore,
            delegate: self
        )
        sessions[session.id] = session
        session.start()
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port?.rawValue else {
                delegate?.bridgeListener(self, changedState: .failed("Porta listener assente"))
                return
            }
            delegate?.bridgeListener(self, changedState: .ready(port: port))
        case let .failed(error):
            Self.logger.error("Listener failed: \(error.localizedDescription, privacy: .public)")
            delegate?.bridgeListener(self, changedState: .failed(error.localizedDescription))
        case .cancelled:
            delegate?.bridgeListener(self, changedState: .stopped)
        default:
            break
        }
    }
}
