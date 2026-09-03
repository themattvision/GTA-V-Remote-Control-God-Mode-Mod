import GTAControlCore
import SwiftUI

struct DirectionPad: View {
    let isEnabled: Bool
    let pendingCommands: Set<TrainerCommand>
    let buttonSide: CGFloat
    let spacing: CGFloat
    let send: (TrainerCommand) -> Void

    init(
        isEnabled: Bool,
        pendingCommands: Set<TrainerCommand>,
        buttonSide: CGFloat = 82,
        spacing: CGFloat = 12,
        send: @escaping (TrainerCommand) -> Void
    ) {
        self.isEnabled = isEnabled
        self.pendingCommands = pendingCommands
        self.buttonSide = max(56, buttonSide)
        self.spacing = max(8, spacing)
        self.send = send
    }

    var body: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                padSpacer
                directionButton("Su", image: "chevron.up", command: .moveUp)
                padSpacer
            }

            HStack(spacing: spacing) {
                directionButton("Sinistra", image: "chevron.left", command: .moveLeft)
                padSpacer
                directionButton("Destra", image: "chevron.right", command: .moveRight)
            }

            HStack(spacing: spacing) {
                padSpacer
                directionButton("Giù", image: "chevron.down", command: .moveDown)
                padSpacer
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pad direzionale")
        .highPriorityGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: DirectionPadSwipeResolver.minimumDistance)
            .onEnded { value in
                guard isEnabled,
                      let command = DirectionPadSwipeResolver.command(for: value.translation),
                      !pendingCommands.contains(command)
                else { return }

                send(command)
            }
    }

    private var padSpacer: some View {
        Color.clear
            .frame(width: buttonSide, height: buttonSide)
            .accessibilityHidden(true)
    }

    private func directionButton(
        _ title: LocalizedStringKey,
        image: String,
        command: TrainerCommand
    ) -> some View {
        let isPending = pendingCommands.contains(command)

        return Button {
            send(command)
        } label: {
            ZStack {
                Image(systemName: image)
                    .font(.system(size: buttonSide * 0.38, weight: .bold))
                    .symbolRenderingMode(.hierarchical)

                if isPending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.primary)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: buttonSide, height: buttonSide)
            .contentShape(.rect)
        }
        .buttonStyle(TrainerPressStyle(role: .direction, radius: buttonSide * 0.34))
        .buttonRepeatBehavior(.enabled)
        .disabled(!isEnabled || isPending)
        .opacity(isEnabled ? 1 : 0.68)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "Sposta la selezione del Native Trainer" : "Disponibile quando il Mac è collegato")
    }
}
