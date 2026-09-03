import Foundation
import GTAControlCore
import Observation

@MainActor
@Observable
final class RemoteAppModel {
    private(set) var connectionState: RemoteConnectionState = .idle
    private(set) var pendingCommands: Set<TrainerCommand> = []
    private(set) var isWaitingForMacPairingApproval = false
    private(set) var trainerState = TrainerStateSnapshot.unavailable
    private(set) var pendingGodModeValue: Bool?
    private(set) var pendingWreckPreservationValue: Bool?
    var presentedError: RemoteAppError?

    @ObservationIgnored private let client: any RemoteSessionClient
    @ObservationIgnored private let feedback: any SuccessFeedbackProviding
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var godModeTask: Task<Void, Never>?
    @ObservationIgnored private var wreckPreservationTask: Task<Void, Never>?

    init(
        client: any RemoteSessionClient,
        feedback: any SuccessFeedbackProviding
    ) {
        self.client = client
        self.feedback = feedback
    }

    static func live() -> RemoteAppModel {
        RemoteAppModel(
            client: BonjourRemoteClient(),
            feedback: HapticFeedback()
        )
    }

    var controlsAreEnabled: Bool {
        connectionState.isConnected
    }

    var pairingPrompt: PairingPrompt? {
        if case .awaitingPairing(let prompt) = connectionState { prompt } else { nil }
    }

    var canControlGodMode: Bool {
        controlsAreEnabled && trainerState.isDirectControlReady && pendingGodModeValue == nil
    }

    var canControlWreckPreservation: Bool {
        controlsAreEnabled
            && trainerState.isDirectControlReady
            && trainerState.wreckPreservationEnabled != nil
            && pendingWreckPreservationValue == nil
    }

    func start() {
        guard eventTask == nil else { return }
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in client.events {
                guard !Task.isCancelled else { return }
                consume(event)
            }
        }
        client.start()
    }

    func retry() {
        presentedError = nil
        client.stop()
        client.start()
    }

    func confirmPairing() {
        guard let pairingPrompt else { return }
        isWaitingForMacPairingApproval = true
        client.confirmPairing(pairingPrompt)
    }

    func rejectPairing() {
        guard let pairingPrompt else { return }
        client.rejectPairing(pairingPrompt)
        isWaitingForMacPairingApproval = false
        connectionState = .searching
    }

    func send(_ command: TrainerCommand) async {
        guard controlsAreEnabled, !pendingCommands.contains(command) else { return }
        pendingCommands.insert(command)
        defer { pendingCommands.remove(command) }
        do {
            try await sendCommand(command)
        } catch {
            presentedError = .describe(error)
        }
    }

    func setGodMode(_ enabled: Bool) {
        guard canControlGodMode else { return }
        pendingGodModeValue = enabled
        godModeTask?.cancel()
        godModeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { godModeTask = nil }
            do {
                _ = try await client.setGodMode(enabled)
                try await ContinuousClock().sleep(for: .seconds(2))
                guard pendingGodModeValue == enabled else { return }
                pendingGodModeValue = nil
                presentedError = RemoteAppError(
                    title: "GTA non ha confermato la modifica",
                    what: "L’invincibilità non è stata aggiornata sul telefono.",
                    why: "Il modulo dentro GTA non ha restituito uno stato recente.",
                    how: "Torna in modalità Storia e attendi un attimo, poi riprova.",
                    canRetry: true
                )
            } catch {
                pendingGodModeValue = nil
                presentedError = .describe(error)
            }
        }
    }

    func setWreckPreservation(_ enabled: Bool) {
        guard canControlWreckPreservation else { return }
        pendingWreckPreservationValue = enabled
        wreckPreservationTask?.cancel()
        wreckPreservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { wreckPreservationTask = nil }
            do {
                _ = try await client.setWreckPreservation(enabled)
                try await ContinuousClock().sleep(for: .seconds(2))
                guard pendingWreckPreservationValue == enabled else { return }
                pendingWreckPreservationValue = nil
                presentedError = RemoteAppError(
                    title: "GTA non ha confermato la modifica",
                    what: "La conservazione dei veicoli non è stata aggiornata sul telefono.",
                    why: "Il modulo dentro GTA non ha restituito uno stato recente.",
                    how: "Torna in modalità Storia e attendi un attimo, poi riprova.",
                    canRetry: true
                )
            } catch {
                pendingWreckPreservationValue = nil
                presentedError = .describe(error)
            }
        }
    }

    private func sendCommand(_ command: TrainerCommand) async throws {
        do {
            _ = try await client.send(command)
        } catch {
            throw error
        }
        feedback.commandWasAcknowledged()
    }

    func stop() {
        eventTask?.cancel()
        eventTask = nil
        client.stop()

        godModeTask?.cancel()
        godModeTask = nil
        pendingGodModeValue = nil
        wreckPreservationTask?.cancel()
        wreckPreservationTask = nil
        pendingWreckPreservationValue = nil
    }

    private func consume(_ event: RemoteClientEvent) {
        switch event {
        case .searching:
            connectionState = .searching
        case .connecting(let deviceName):
            connectionState = .connecting(deviceName: deviceName)
        case .pairingRequired(let prompt):
            isWaitingForMacPairingApproval = false
            connectionState = .awaitingPairing(prompt)
        case .connected(let deviceName):
            isWaitingForMacPairingApproval = false
            connectionState = .connected(deviceName: deviceName)
        case .reconnecting(let deviceName, let attempt):
            connectionState = .reconnecting(deviceName: deviceName, attempt: attempt)
        case .disconnected(let reason):
            isWaitingForMacPairingApproval = false
            connectionState = .disconnected(reason: reason)
        case .failed(let error):
            isWaitingForMacPairingApproval = false
            connectionState = .disconnected(reason: nil)
            presentedError = .describe(error)
        case .trainerState(let state):
            trainerState = state
            if let pendingGodModeValue,
               state.godModeEnabled == pendingGodModeValue {
                self.pendingGodModeValue = nil
                feedback.commandWasAcknowledged()
            }
            if let pendingWreckPreservationValue,
               state.wreckPreservationEnabled == pendingWreckPreservationValue {
                self.pendingWreckPreservationValue = nil
                feedback.commandWasAcknowledged()
            }
        }
    }
}
