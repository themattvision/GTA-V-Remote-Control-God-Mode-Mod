@preconcurrency import Network
import Foundation
import GTAControlCore
import OSLog

@MainActor
final class BonjourRemoteClient: RemoteSessionClient {
    private struct PairingContext {
        let prompt: PairingPrompt
        let bridgeID: UUID
        let keyPair: PairingKeyPair
        let sessionKey: SessionKey?
        var localFingerprintConfirmed = false
        var bridgeApprovalReceived = false
    }

    private struct PendingCommand {
        let sequence: UInt64
        let continuation: CheckedContinuation<CommandAcknowledgement, any Error>
        let timeoutTask: Task<Void, Never>
    }

    private static let logger = Logger(
        subsystem: "com.matteozampieri.GTARemote",
        category: "BonjourRemoteClient"
    )

    let events: AsyncStream<RemoteClientEvent>

    private let eventContinuation: AsyncStream<RemoteClientEvent>.Continuation
    private let sessionStore = KeychainSessionStore(service: "com.matteozampieri.GTARemote.sessions")
    private let defaults: UserDefaults
    private let clientID: UUID

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var decoder = FrameDecoder()
    private var bridgeID: UUID?
    private var bridgeName = "Mac"
    private var pairingContext: PairingContext?
    private var secureChannel: SecureChannel?
    private var nextCommandSequence: UInt64 = 1
    private var awaitingSecureConfirmation = false
    private var restoredSessionInUse = false
    private var secureConfirmationTask: Task<Void, Never>?
    private var pendingCommands: [UUID: PendingCommand] = [:]
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var shouldRun = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stream = AsyncStream.makeStream(of: RemoteClientEvent.self)
        events = stream.stream
        eventContinuation = stream.continuation

        let identityKey = "gtaRemote.clientID"
        if let storedID = defaults.string(forKey: identityKey).flatMap(UUID.init(uuidString:)) {
            clientID = storedID
        } else {
            let newID = UUID()
            clientID = newID
            defaults.set(newID.uuidString, forKey: identityKey)
        }
    }

    func start() {
        guard !shouldRun else { return }
        shouldRun = true
        reconnectAttempt = 0
        beginBrowsing()
    }

    func stop() {
        shouldRun = false
        reconnectTask?.cancel()
        reconnectTask = nil
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        secureConfirmationTask?.cancel()
        secureConfirmationTask = nil
        secureChannel = nil
        awaitingSecureConfirmation = false
        restoredSessionInUse = false
        pairingContext = nil
        failPendingCommands(with: .connectionLost)
        eventContinuation.yield(.disconnected(reason: nil))
    }

    func confirmPairing(_ prompt: PairingPrompt) {
        guard var context = pairingContext, context.prompt.id == prompt.id else { return }
        context.localFingerprintConfirmed = true
        pairingContext = context
        completePairingIfReady()
    }

    func rejectPairing(_ prompt: PairingPrompt) {
        guard pairingContext?.prompt.id == prompt.id else { return }
        pairingContext = nil
        connection?.cancel()
        scheduleReconnect(reason: "Associazione annullata")
    }

    func send(_ command: TrainerCommand) async throws -> CommandAcknowledgement {
        try await sendRequest { requestID, sequence in
            .command(
                CommandMessage(
                    envelope: CommandEnvelope(
                        clientID: self.clientID,
                        requestID: requestID,
                        sequence: sequence,
                        command: command
                    )
                )
            )
        }
    }

    func setGodMode(_ enabled: Bool) async throws -> CommandAcknowledgement {
        try await sendRequest { requestID, sequence in
            .godModeCommand(
                GodModeCommandMessage(
                    clientID: self.clientID,
                    requestID: requestID,
                    sequence: sequence,
                    enabled: enabled
                )
            )
        }
    }

    func setWreckPreservation(_ enabled: Bool) async throws -> CommandAcknowledgement {
        try await sendRequest { requestID, sequence in
            .wreckPreservationCommand(
                WreckPreservationCommandMessage(
                    clientID: self.clientID,
                    requestID: requestID,
                    sequence: sequence,
                    enabled: enabled
                )
            )
        }
    }

    private func sendRequest(
        _ message: (UUID, UInt64) -> WireMessage
    ) async throws -> CommandAcknowledgement {
        guard connection != nil,
              !awaitingSecureConfirmation,
              var channel = secureChannel else {
            throw RemoteClientError.notConnected
        }
        guard nextCommandSequence > 0 else {
            throw RemoteClientError.protocolFailure
        }

        let requestID = UUID()
        let sequence = nextCommandSequence

        let packet: EncryptedPacket
        do {
            packet = try channel.seal(message(requestID, sequence))
            guard packet.sequence == sequence else { throw RemoteClientError.protocolFailure }
        } catch {
            throw RemoteClientError.protocolFailure
        }

        secureChannel = channel
        nextCommandSequence = sequence == UInt64.max ? 0 : sequence + 1

        let frame: Data
        do {
            frame = try FrameCodec.encode(packet)
        } catch {
            throw RemoteClientError.protocolFailure
        }

        return try await withCheckedThrowingContinuation { continuation in
            let timeout = Task { [weak self] in
                try? await ContinuousClock().sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                self?.resolveCommand(
                    requestID: requestID,
                    result: .failure(.connectionLost)
                )
            }
            pendingCommands[requestID] = PendingCommand(
                sequence: sequence,
                continuation: continuation,
                timeoutTask: timeout
            )
            transmit(frame) { [weak self] error in
                guard error != nil else { return }
                self?.resolveCommand(
                    requestID: requestID,
                    result: .failure(.connectionLost)
                )
            }
        }
    }

    private func beginBrowsing() {
        guard shouldRun else { return }
        browser?.cancel()
        connection?.cancel()
        connection = nil
        secureConfirmationTask?.cancel()
        secureConfirmationTask = nil
        secureChannel = nil
        awaitingSecureConfirmation = false
        restoredSessionInUse = false
        pairingContext = nil
        decoder = FrameDecoder()
        eventContinuation.yield(.searching)

        let browser = NWBrowser(
            for: .bonjour(type: ProtocolConstants.bonjourType, domain: nil),
            using: .tcp
        )
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                if case .failed(let error) = state {
                    Self.logger.error("Bonjour browser failed: \(error.localizedDescription, privacy: .public)")
                    self.scheduleReconnect(reason: "GTA Bridge non trovato")
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated {
                guard let self, self.connection == nil, let result = results.first else { return }
                self.connect(to: result.endpoint)
            }
        }
        browser.start(queue: .main)
    }

    private func connect(to endpoint: NWEndpoint) {
        browser?.cancel()
        browser = nil
        bridgeName = Self.displayName(for: endpoint)
        eventContinuation.yield(.connecting(deviceName: bridgeName))

        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            MainActor.assumeIsolated {
                guard let self, connection === self.connection else { return }
                switch state {
                case .ready:
                    self.reconnectTask?.cancel()
                    self.reconnectTask = nil
                    self.decoder = FrameDecoder()
                    self.receiveNextChunk()
                    self.sendClear(.hello(HelloMessage(peerID: self.clientID, role: .controller)))
                case .failed(let error):
                    Self.logger.error("Connection failed: \(error.localizedDescription, privacy: .public)")
                    self.scheduleReconnect(reason: "Connessione al Mac interrotta")
                case .cancelled:
                    if self.shouldRun, self.reconnectTask == nil {
                        self.scheduleReconnect(reason: "Connessione al Mac interrotta")
                    }
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func receiveNextChunk() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.consume(data)
                }
                if error != nil || complete {
                    self.scheduleReconnect(reason: "Connessione al Mac interrotta")
                } else {
                    self.receiveNextChunk()
                }
            }
        }
    }

    private func consume(_ data: Data) {
        do {
            for frame in try decoder.append(data) {
                if var channel = secureChannel {
                    let packet = try JSONDecoder().decode(EncryptedPacket.self, from: frame)
                    let message = try channel.open(packet)
                    secureChannel = channel
                    consumeSecure(message)
                } else {
                    consumeClear(try ProtocolCodec.decode(frame))
                }
            }
        } catch {
            Self.logger.error("Protocol data rejected: \(String(describing: error), privacy: .public)")
            eventContinuation.yield(.failed(.protocolFailure))
            connection?.cancel()
        }
    }

    private func consumeClear(_ message: WireMessage) {
        switch message {
        case .hello(let hello) where hello.role == .bridge:
            bridgeID = hello.peerID
            do {
                if let storedKey = try sessionStore.sessionKey(for: hello.peerID) {
                    activateSecureSession(storedKey, restored: true)
                } else {
                    beginPairing(with: hello.peerID)
                }
            } catch {
                eventContinuation.yield(.failed(.protocolFailure))
            }

        case .pairingChallenge(let challenge):
            accept(challenge)

        case .pairingApproval(let approval):
            accept(approval)

        case .error(let error):
            handleProtocolError(error)

        default:
            eventContinuation.yield(.failed(.protocolFailure))
            connection?.cancel()
        }
    }

    private func beginPairing(with bridgeID: UUID) {
        let keyPair = PairingKeyPair()
        pairingContext = PairingContext(
            prompt: PairingPrompt(deviceName: bridgeName, fingerprint: ""),
            bridgeID: bridgeID,
            keyPair: keyPair,
            sessionKey: nil
        )
        sendClear(
            .pairingRequest(
                PairingRequest(
                    clientID: clientID,
                    clientPublicKey: keyPair.publicKey
                )
            )
        )
    }

    private func accept(_ challenge: PairingChallenge) {
        guard challenge.bridgeID == bridgeID,
              let existingContext = pairingContext else {
            failPairing(.protocolFailure)
            return
        }

        do {
            let remoteKey = challenge.bridgePublicKey
            let computedFingerprint = try existingContext.keyPair.fingerprint(with: remoteKey)
            guard computedFingerprint == challenge.fingerprint else {
                failPairing(.invalidFingerprint)
                return
            }
            let sessionKey = try existingContext.keyPair.deriveSessionKey(with: remoteKey)
            let prompt = PairingPrompt(
                deviceName: bridgeName,
                fingerprint: computedFingerprint.description
            )
            pairingContext = PairingContext(
                prompt: prompt,
                bridgeID: challenge.bridgeID,
                keyPair: existingContext.keyPair,
                sessionKey: sessionKey
            )
            eventContinuation.yield(.pairingRequired(prompt))
        } catch {
            failPairing(.invalidFingerprint)
        }
    }

    private func accept(_ approval: PairingApproval) {
        guard approval.clientID == clientID,
              var context = pairingContext,
              approval.bridgeID == context.bridgeID else {
            failPairing(.protocolFailure)
            return
        }
        guard approval.approved else {
            failPairing(.pairingRejected)
            return
        }
        context.bridgeApprovalReceived = true
        pairingContext = context
        completePairingIfReady()
    }

    private func completePairingIfReady() {
        guard let context = pairingContext,
              context.localFingerprintConfirmed,
              context.bridgeApprovalReceived,
              let sessionKey = context.sessionKey else { return }
        do {
            try sessionStore.save(sessionKey, for: context.bridgeID)
            pairingContext = nil
            activateSecureSession(sessionKey, restored: false)
        } catch {
            failPairing(.protocolFailure)
        }
    }

    private func activateSecureSession(_ key: SessionKey, restored: Bool) {
        var channel = SecureChannel(sessionKey: key)
        do {
            let packet = try channel.seal(.heartbeat(HeartbeatMessage(sequence: 1)))
            guard packet.sequence == 1 else { throw RemoteClientError.protocolFailure }
            let frame = try FrameCodec.encode(packet)

            secureChannel = channel
            nextCommandSequence = 2
            awaitingSecureConfirmation = true
            restoredSessionInUse = restored
            eventContinuation.yield(.connecting(deviceName: bridgeName))

            secureConfirmationTask?.cancel()
            secureConfirmationTask = Task { [weak self] in
                try? await ContinuousClock().sleep(for: .seconds(4))
                guard !Task.isCancelled, let self, self.awaitingSecureConfirmation else { return }
                self.scheduleReconnect(reason: "Il Mac non ha confermato la sessione sicura")
            }
            transmit(frame) { [weak self] error in
                guard error != nil else { return }
                self?.scheduleReconnect(reason: "Verifica della sessione sicura non riuscita")
            }
        } catch {
            eventContinuation.yield(.failed(.protocolFailure))
            connection?.cancel()
        }
    }

    private func consumeSecure(_ message: WireMessage) {
        switch message {
        case .acknowledgement(let acknowledgement):
            guard let pending = pendingCommands[acknowledgement.requestID],
                  pending.sequence == acknowledgement.sequence else {
                eventContinuation.yield(.failed(.protocolFailure))
                return
            }
            if acknowledgement.status == .accepted {
                resolveCommand(
                    requestID: acknowledgement.requestID,
                    result: .success(
                        CommandAcknowledgement(
                            requestID: acknowledgement.requestID,
                            sequence: acknowledgement.sequence
                        )
                    )
                )
            } else {
                resolveCommand(
                    requestID: acknowledgement.requestID,
                    result: .failure(.commandRejected(reason: "Il Mac non ha eseguito il comando."))
                )
            }

        case .error(let error):
            if let requestID = error.requestID {
                resolveCommand(
                    requestID: requestID,
                    result: .failure(Self.clientError(for: error.code))
                )
            } else {
                handleProtocolError(error)
            }

        case .heartbeat(let heartbeat):
            guard awaitingSecureConfirmation, heartbeat.sequence == 1 else { break }
            secureConfirmationTask?.cancel()
            secureConfirmationTask = nil
            awaitingSecureConfirmation = false
            restoredSessionInUse = false
            reconnectAttempt = 0
            eventContinuation.yield(.connected(deviceName: bridgeName))

        case .trainerState(let state):
            eventContinuation.yield(.trainerState(state.snapshot))

        default:
            eventContinuation.yield(.failed(.protocolFailure))
        }
    }

    private func sendClear(_ message: WireMessage) {
        do {
            transmit(try ProtocolCodec.encodeFrame(message)) { [weak self] error in
                if error != nil {
                    self?.scheduleReconnect(reason: "Invio al Mac non riuscito")
                }
            }
        } catch {
            eventContinuation.yield(.failed(.protocolFailure))
        }
    }

    private func transmit(_ data: Data, completion: @escaping @MainActor (NWError?) -> Void) {
        guard let connection else {
            completion(NWError.posix(.ENOTCONN))
            return
        }
        connection.send(content: data, completion: .contentProcessed { error in
            MainActor.assumeIsolated {
                completion(error)
            }
        })
    }

    private func resolveCommand(
        requestID: UUID,
        result: Result<CommandAcknowledgement, RemoteClientError>
    ) {
        guard let pending = pendingCommands.removeValue(forKey: requestID) else { return }
        pending.timeoutTask.cancel()
        switch result {
        case .success(let acknowledgement): pending.continuation.resume(returning: acknowledgement)
        case .failure(let error): pending.continuation.resume(throwing: error)
        }
    }

    private func failPendingCommands(with error: RemoteClientError) {
        let pending = pendingCommands
        pendingCommands.removeAll()
        for command in pending.values {
            command.timeoutTask.cancel()
            command.continuation.resume(throwing: error)
        }
    }

    private func failPairing(_ error: RemoteClientError) {
        pairingContext = nil
        eventContinuation.yield(.failed(error))
        connection?.cancel()
    }

    private func handleProtocolError(_ error: ProtocolErrorMessage) {
        eventContinuation.yield(.failed(Self.clientError(for: error.code)))
        if error.requestID == nil {
            connection?.cancel()
        }
    }

    private func scheduleReconnect(reason: String) {
        guard shouldRun, reconnectTask == nil else { return }
        if awaitingSecureConfirmation, restoredSessionInUse, let bridgeID {
            do {
                try sessionStore.removeSessionKey(for: bridgeID)
            } catch {
                Self.logger.error("Stored session removal failed: \(String(describing: error), privacy: .public)")
            }
        }
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        secureConfirmationTask?.cancel()
        secureConfirmationTask = nil
        secureChannel = nil
        awaitingSecureConfirmation = false
        restoredSessionInUse = false
        pairingContext = nil
        failPendingCommands(with: .connectionLost)

        reconnectAttempt += 1
        let attempt = reconnectAttempt
        eventContinuation.yield(.reconnecting(deviceName: bridgeName, attempt: attempt))
        let delay = min(8, 1 << min(attempt - 1, 3))
        reconnectTask = Task { [weak self] in
            try? await ContinuousClock().sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.shouldRun else { return }
            self.reconnectTask = nil
            self.beginBrowsing()
        }
        Self.logger.notice("Reconnect scheduled: \(reason, privacy: .public)")
    }

    private static func clientError(for code: ProtocolErrorCode) -> RemoteClientError {
        switch code {
        case .pairingDenied: .pairingRejected
        case .commandRejected: .commandRejected(reason: "GTA Bridge ha rifiutato il comando.")
        case .unsupportedVersion, .malformedMessage, .authenticationFailed,
             .replayDetected, .rateLimited, .invalidSequence: .protocolFailure
        }
    }

    private static func displayName(for endpoint: NWEndpoint) -> String {
        if case .service(let name, _, _, _) = endpoint { return name }
        return "Mac con GTA Bridge"
    }
}
