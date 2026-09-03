import Foundation
import AppKit
import GTAControlCore
import Observation

typealias LiveForegroundGuard = ForegroundGameGuard<WorkspaceForegroundApplicationProvider>
typealias LiveInputInjector = TrainerInputInjector<
    LiveForegroundGuard,
    CGKeyboardEventPoster,
    SystemAccessibilityPermissionChecker
>

@Observable
@MainActor
final class BridgeModel: BridgeListenerDelegate {
    private(set) var listenerState: BridgeListenerState = .stopped
    private(set) var connectionState: BridgeConnectionState = .disconnected
    private(set) var diagnostics: [DiagnosticEntry] = []
    private(set) var isResolvingPairing = false
    private(set) var manualTestInProgress = false
    private(set) var trainerState = TrainerStateSnapshot.unavailable

    let accessibility: AccessibilityPermission<SystemAccessibilityTrustChecker>

    @ObservationIgnored private let bridgeID: UUID
    @ObservationIgnored private let inputInjector: LiveInputInjector
    @ObservationIgnored private let sessionStore: KeychainSessionStore
    @ObservationIgnored private var listener: BridgeListener?
    @ObservationIgnored private var pairingTask: Task<Void, Never>?
    @ObservationIgnored private var manualTestTask: Task<Void, Never>?
    @ObservationIgnored private var trainerStateTask: Task<Void, Never>?
    @ObservationIgnored private let gameModStateProvider: GameModStateProvider

    init() {
        let defaultsKey = "GTABridge.bridgeID"
        if let storedID = UserDefaults.standard.string(forKey: defaultsKey),
           let parsedID = UUID(uuidString: storedID) {
            bridgeID = parsedID
        } else {
            let generatedID = UUID()
            UserDefaults.standard.set(generatedID.uuidString, forKey: defaultsKey)
            bridgeID = generatedID
        }

        accessibility = AccessibilityPermission(checker: SystemAccessibilityTrustChecker())
        sessionStore = KeychainSessionStore(service: "com.matteozampieri.GTABridge.session")

        let foregroundGuard = LiveForegroundGuard(provider: WorkspaceForegroundApplicationProvider())
        inputInjector = LiveInputInjector(
            foregroundGuard: foregroundGuard,
            poster: CGKeyboardEventPoster(),
            permission: SystemAccessibilityPermissionChecker()
        )
        gameModStateProvider = GameModStateProvider()
    }

    func start() {
        guard listener == nil else { return }
        accessibility.startPolling()
        let listener = BridgeListener(
            bridgeID: bridgeID,
            sessionStore: sessionStore,
            delegate: self
        )
        self.listener = listener
        listener.start()
        startTrainerStatePolling()
    }

    func stop() {
        pairingTask?.cancel()
        pairingTask = nil
        manualTestTask?.cancel()
        manualTestTask = nil
        trainerStateTask?.cancel()
        trainerStateTask = nil
        listener?.stop()
        listener = nil
        accessibility.stopPolling()
        connectionState = .disconnected
    }

    func requestAccessibility() {
        accessibility.request()
    }

    func refreshAccessibility() {
        accessibility.refresh()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func resolvePairing(approved: Bool) {
        guard !isResolvingPairing else { return }
        isResolvingPairing = true
        pairingTask?.cancel()
        pairingTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isResolvingPairing = false }
            do {
                try await self.listener?.resolvePendingPairing(approved: approved)
            } catch {
                self.record(.error, error.localizedDescription)
            }
        }
    }

    func runManualTest(_ command: TrainerCommand) {
        guard !manualTestInProgress else { return }
        manualTestInProgress = true
        manualTestTask?.cancel()
        record(.info, "Test manuale tra 3 secondi, porta GTA in primo piano.")
        manualTestTask = Task { [weak self] in
            guard let self else { return }
            defer { self.manualTestInProgress = false }
            do {
                try await ContinuousClock().sleep(for: .seconds(3))
                try await self.inputInjector.inject(command)
                self.record(.success, "Test manuale \(command.rawValue) completato.")
            } catch {
                self.record(.error, "Test manuale: \(error.localizedDescription)")
            }
        }
    }

    func clearDiagnostics() {
        diagnostics.removeAll()
    }

    func bridgeListener(_ listener: BridgeListener, changedState state: BridgeListenerState) {
        listenerState = state
        switch state {
        case .ready:
            record(.success, "Listener Bonjour disponibile su \(ProtocolConstants.bonjourType).")
        case let .failed(message):
            record(.error, message)
        default:
            break
        }
    }

    func bridgeListener(_ listener: BridgeListener, connectedClient clientID: UUID) {
        connectionState = .connected(clientID: clientID)
        record(.success, "Client autenticato: \(shortID(clientID)).")
    }

    func bridgeListener(_ listener: BridgeListener, authenticatingClient clientID: UUID) {
        connectionState = .authenticating(clientID: clientID)
    }

    func bridgeListener(_ listener: BridgeListener, disconnectedClient clientID: UUID?) {
        if connectionState.clientID == clientID || clientID == nil {
            connectionState = .disconnected
        }
        if let clientID {
            record(.info, "Client disconnesso: \(shortID(clientID)).")
        }
    }

    func bridgeListener(
        _ listener: BridgeListener,
        requestsPairingFor clientID: UUID,
        fingerprint: PairingFingerprint
    ) {
        connectionState = .awaitingPairing(clientID: clientID, fingerprint: fingerprint)
        record(.warning, "Pairing richiesto dal client \(shortID(clientID)).")
    }

    func bridgeListener(_ listener: BridgeListener, received command: TrainerCommand) async throws {
        try await inputInjector.inject(command)
    }

    func bridgeListener(_ listener: BridgeListener, setsGodMode enabled: Bool) async throws {
        try gameModStateProvider.setGodMode(enabled)
    }

    func bridgeListener(_ listener: BridgeListener, setsWreckPreservation enabled: Bool) async throws {
        try gameModStateProvider.setWreckPreservation(enabled)
    }

    func bridgeListener(
        _ listener: BridgeListener,
        diagnostic level: DiagnosticEntry.Level,
        message: String
    ) {
        record(level, message)
    }

    private func record(_ level: DiagnosticEntry.Level, _ message: String) {
        diagnostics.insert(DiagnosticEntry(level: level, message: message), at: 0)
        if diagnostics.count > 30 {
            diagnostics.removeLast(diagnostics.count - 30)
        }
    }

    private func startTrainerStatePolling() {
        trainerStateTask?.cancel()
        trainerStateTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let state = gameModStateProvider.currentState()
                if state != trainerState {
                    trainerState = state
                    await listener?.publishTrainerState(state)
                }
                try? await ContinuousClock().sleep(for: .milliseconds(250))
            }
        }
    }

    private func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }
}
