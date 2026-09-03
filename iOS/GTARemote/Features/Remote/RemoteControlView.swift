import GTAControlCore
import SwiftUI

struct RemoteControlView: View {
    let model: RemoteAppModel

    var body: some View {
        GeometryReader { proxy in
            let metrics = ControllerMetrics(size: proxy.size)

            VStack(spacing: metrics.controlSpacing) {
                CompactConnectionStatusView(state: model.connectionState)

                control(
                    "Apri / chiudi menu",
                    hint: "Attiva o disattiva il menu del Native Trainer",
                    image: "rectangle.on.rectangle",
                    command: .toggleTrainer,
                    height: metrics.menuHeight,
                    role: .primary
                )

                DirectionPad(
                    isEnabled: model.controlsAreEnabled,
                    pendingCommands: model.pendingCommands,
                    buttonSide: metrics.directionButtonSide,
                    spacing: metrics.directionSpacing,
                    send: send
                )

                HStack(spacing: metrics.actionSpacing) {
                    control(
                        "Indietro",
                        hint: "Torna alla schermata precedente",
                        image: "arrow.uturn.backward",
                        command: .back,
                        height: metrics.actionHeight,
                        role: .subtle
                    )
                    .frame(width: metrics.backButtonWidth)

                    control(
                        "Conferma",
                        hint: "Conferma la voce selezionata",
                        image: "checkmark.circle.fill",
                        command: .select,
                        height: metrics.actionHeight,
                        role: .primary
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, metrics.verticalPadding)
            .padding(.bottom, 10)
        }
        .background(Color.clear)
    }

    private func control(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey,
        image: String,
        command: TrainerCommand,
        height: CGFloat = 64,
        role: TrainerPressStyle.Role = .regular
    ) -> some View {
        TrainerControlButton(
            title,
            accessibilityHint: hint,
            systemImage: image,
            command: command,
            minimumHeight: height,
            styleRole: role,
            isEnabled: model.controlsAreEnabled,
            isPending: model.pendingCommands.contains(command),
            action: send
        )
    }

    private func send(_ command: TrainerCommand) {
        Task { await model.send(command) }
    }
}

private struct ControllerMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let controlSpacing: CGFloat
    let directionSpacing: CGFloat
    let actionSpacing: CGFloat
    let directionButtonSide: CGFloat
    let menuHeight: CGFloat
    let actionHeight: CGFloat
    let backButtonWidth: CGFloat

    init(size: CGSize) {
        let compactHeight = size.height < 610
        let compactWidth = size.width < 390

        horizontalPadding = compactWidth ? 12 : 16
        verticalPadding = compactHeight ? 6 : 10
        controlSpacing = compactHeight ? 12 : 20
        directionSpacing = compactWidth ? 10 : 12
        actionSpacing = compactWidth ? 10 : 12

        let contentWidth = max(0, size.width - horizontalPadding * 2)
        let sideFromWidth = (contentWidth - directionSpacing * 2) / 3

        let fixedControlsHeight: CGFloat = 54 + 72 + 64 + controlSpacing * 3 + directionSpacing * 2
        let sideFromHeight = (size.height - verticalPadding - 10 - fixedControlsHeight) / 3
        directionButtonSide = min(88, max(56, min(sideFromWidth, sideFromHeight)))

        menuHeight = min(92, max(68, directionButtonSide * 1.04))
        actionHeight = min(84, max(64, directionButtonSide * 0.96))
        backButtonWidth = min(124, max(104, contentWidth * 0.32))
    }
}

private struct CompactConnectionStatusView: View {
    let state: RemoteConnectionState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(statusLabel)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(TrainerTheme.tertiaryText)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TrainerTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .tint(TrainerTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, TrainerTheme.Spacing.regular)
        .padding(.vertical, TrainerTheme.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch state {
        case .idle:
            "Pronto a cercare il Mac"
        case .searching:
            "Cerco il tuo Mac"
        case .connecting:
            "Mi collego al Mac"
        case .awaitingPairing:
            "Conferma il codice"
        case .connected:
            "Tutto collegato"
        case .reconnecting:
            "Ripristino il collegamento"
        case .disconnected:
            "Mac non collegato"
        }
    }

    private var statusLabel: String {
        switch state {
        case .connected:
            "ONLINE"
        case .idle, .searching, .connecting, .awaitingPairing, .reconnecting:
            "CONNESSIONE"
        case .disconnected:
            "OFFLINE"
        }
    }

    private var indicatorColor: Color {
        switch state {
        case .connected:
            TrainerTheme.success
        case .searching, .connecting, .awaitingPairing, .reconnecting:
            TrainerTheme.warning
        case .idle, .disconnected:
            TrainerTheme.danger
        }
    }

    private var isWorking: Bool {
        switch state {
        case .searching, .connecting, .reconnecting:
            true
        case .idle, .awaitingPairing, .connected, .disconnected:
            false
        }
    }
}
