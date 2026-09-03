import GTAControlCore
import SwiftUI

struct BridgeMenuView: View {
    let model: BridgeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BridgeHero(model: model)
                BridgeReadinessCard(model: model)
                DirectControlStatusCard(state: model.trainerState)

                if case let .awaitingPairing(clientID, fingerprint) = model.connectionState {
                    PairingApprovalSection(
                        clientID: clientID,
                        fingerprint: fingerprint,
                        isBusy: model.isResolvingPairing,
                        onResolve: model.resolvePairing
                    )
                }

                DisclosureGroup("Se qualcosa non risponde") {
                    ManualInputTestSection(
                        isBusy: model.manualTestInProgress,
                        onTest: model.runManualTest
                    )
                    .padding(.top, 8)
                }
                .font(.callout)

                DisclosureGroup("Dettagli tecnici") {
                    DiagnosticsSection(
                        entries: model.diagnostics,
                        onClear: model.clearDiagnostics
                    )
                    .padding(.top, 8)
                }
                .font(.callout)

                HStack {
                    Button("Riavvia collegamento") {
                        model.stop()
                        model.start()
                    }
                    Spacer()
                    Button("Esci") {
                        model.stop()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .controlSize(.small)
            }
            .padding(16)
        }
        .frame(width: 390, height: 520)
    }
}

private struct BridgeHero: View {
    let model: BridgeModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text("GodMode Mod Remote Control")
                    .font(.headline)
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var headline: String {
        if case .connected = model.connectionState {
            return "Il tuo iPhone è collegato"
        }
        if model.accessibility.state == .granted {
            return "Pronto per giocare"
        }
        return "Serve il tuo permesso per controllare GTA"
    }
}

private struct BridgeReadinessCard: View {
    let model: BridgeModel

    var body: some View {
        BridgeGlassCard {
            VStack(spacing: 12) {
                FriendlyStatusRow(
                    title: "Collegamento",
                    value: connectionText,
                    symbol: "wifi",
                    tint: connectionTint
                )
                FriendlyStatusRow(
                    title: "Controllo del gioco",
                    value: accessibilityText,
                    symbol: "hand.tap.fill",
                    tint: accessibilityTint
                )

                if model.accessibility.state != .granted {
                    HStack {
                        Button("Controlla di nuovo") {
                            model.refreshAccessibility()
                        }
                        Button("Apri impostazioni") {
                            model.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var connectionText: String {
        switch model.connectionState {
        case .connected:
            return "iPhone collegato"
        case .awaitingPairing:
            return "Conferma il codice"
        case .authenticating:
            return "Controllo in corso"
        case .disconnected:
            if case .ready = model.listenerState { return "In attesa dell’iPhone" }
            return "Mi sto preparando"
        }
    }

    private var connectionTint: Color {
        switch model.connectionState {
        case .connected: return Color.green
        case .awaitingPairing, .authenticating: return Color.orange
        case .disconnected:
            if case .ready = model.listenerState { return .secondary }
            return .orange
        }
    }

    private var accessibilityText: String {
        switch model.accessibility.state {
        case .granted: "Pronto"
        case .unknown: "Verifico il permesso"
        case .denied: "Da autorizzare"
        }
    }

    private var accessibilityTint: Color {
        model.accessibility.state == .granted ? .green : .orange
    }
}

private struct DirectControlStatusCard: View {
    let state: TrainerStateSnapshot

    var body: some View {
        BridgeGlassCard {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(state.godModeEnabled == true ? Color.green : Color.accentColor)
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background((state.godModeEnabled == true ? Color.green : Color.accentColor).opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invincibilità")
                        .font(.callout.weight(.semibold))
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "car.side.and.exclamationmark")
                    .foregroundStyle(state.wreckPreservationEnabled == true ? Color.orange : Color.accentColor)
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background((state.wreckPreservationEnabled == true ? Color.orange : Color.accentColor).opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Veicoli distrutti")
                        .font(.callout.weight(.semibold))
                    Text(wreckStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var status: String {
        guard state.isDirectControlReady else {
            return "Sto aspettando il modulo GTA"
        }
        return state.godModeEnabled == true ? "Attiva in GTA" : "Spenta in GTA"
    }

    private var wreckStatus: String {
        guard state.isDirectControlReady else {
            return "Sto aspettando il modulo GTA"
        }
        guard state.wreckPreservationEnabled != nil else {
            return "Aggiorna GTA per attivarla"
        }
        guard state.wreckPreservationEnabled == true else {
            return "Non vengono conservati"
        }
        let count = state.preservedWreckCount ?? 0
        return count == 1 ? "1 veicolo conservato" : "\(count) veicoli conservati"
    }
}

private struct FriendlyStatusRow: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.callout)
    }
}

private struct PairingApprovalSection: View {
    let clientID: UUID
    let fingerprint: PairingFingerprint
    let isBusy: Bool
    let onResolve: (Bool) -> Void

    var body: some View {
        BridgeGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Connetti questo iPhone", systemImage: "iphone.and.arrow.forward")
                    .font(.headline)
                Text("Verifica che sul telefono ci sia lo stesso codice.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(fingerprint.description)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .textSelection(.enabled)
                HStack {
                    Button("Non ora", role: .cancel) { onResolve(false) }
                    Button("Collega") { onResolve(true) }
                        .buttonStyle(.borderedProminent)
                }
                .disabled(isBusy)
                .controlSize(.small)
            }
        }
        .accessibilityLabel("Richiesta di collegamento dall’iPhone \(clientID.uuidString.prefix(8))")
    }
}

private struct ManualInputTestSection: View {
    let isBusy: Bool
    let onTest: (TrainerCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per una prova, premi un pulsante e torna in GTA entro tre secondi.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Apri il menu") { onTest(.toggleTrainer) }
                Button("Giù") { onTest(.moveDown) }
                Button("Conferma") { onTest(.select) }
                Button("Indietro") { onTest(.back) }
            }
            .controlSize(.small)
            .disabled(isBusy)
        }
    }
}

private struct DiagnosticsSection: View {
    let entries: [DiagnosticEntry]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attività recente")
                    .font(.callout.weight(.semibold))
                Spacer()
                Button("Pulisci", action: onClear)
                    .disabled(entries.isEmpty)
            }

            if entries.isEmpty {
                Text("Non c’è ancora nulla da segnalare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            DiagnosticRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }
}

private struct DiagnosticRow: View {
    let entry: DiagnosticEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption)
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: String {
        switch entry.level {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private var color: Color {
        switch entry.level {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
