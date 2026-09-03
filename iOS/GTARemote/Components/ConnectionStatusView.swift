import SwiftUI

struct ConnectionStatusView: View {
    let state: RemoteConnectionState

    var body: some View {
        AppleGlassCard {
            HStack(spacing: 12) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)
                .overlay {
                    if isWorking {
                        Circle()
                            .stroke(indicatorColor.opacity(0.4), lineWidth: 4)
                            .frame(width: 18, height: 18)
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(TrainerTheme.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if isWorking {
                ProgressView()
                    .tint(TrainerTheme.accent)
                    .accessibilityHidden(true)
            }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var title: String {
        switch state {
        case .idle: "Pronto a cercare il Mac"
        case .searching: "Cerco il tuo Mac"
        case .connecting: "Mi collego al Mac"
        case .awaitingPairing: "Conferma il codice"
        case .connected: "Tutto collegato"
        case .reconnecting: "Ripristino il collegamento"
        case .disconnected: "Mac non collegato"
        }
    }

    private var detail: String? {
        switch state {
        case .connecting(let name), .connected(let name): name
        case .awaitingPairing(let prompt): prompt.deviceName
        case .reconnecting(let name, let attempt): "\(name), tentativo \(attempt)"
        case .disconnected(let reason): reason ?? "Controlla Wi-Fi e GTA Bridge"
        case .idle, .searching: nil
        }
    }

    private var indicatorColor: Color {
        switch state {
        case .connected: TrainerTheme.accent
        case .searching, .connecting, .awaitingPairing, .reconnecting: .orange
        case .idle, .disconnected: .red
        }
    }

    private var isWorking: Bool {
        switch state {
        case .searching, .connecting, .reconnecting: true
        case .idle, .awaitingPairing, .connected, .disconnected: false
        }
    }
}
