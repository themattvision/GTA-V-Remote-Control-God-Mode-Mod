import GTAControlCore
import SwiftUI

struct TrainerControlButton: View {
    let title: LocalizedStringKey
    let accessibilityHint: LocalizedStringKey
    let systemImage: String?
    let command: TrainerCommand
    let minimumHeight: CGFloat
    let styleRole: TrainerPressStyle.Role
    let isEnabled: Bool
    let isPending: Bool
    let action: (TrainerCommand) -> Void

    init(
        _ title: LocalizedStringKey,
        accessibilityHint: LocalizedStringKey,
        systemImage: String? = nil,
        command: TrainerCommand,
        minimumHeight: CGFloat = 64,
        styleRole: TrainerPressStyle.Role = .regular,
        isEnabled: Bool,
        isPending: Bool,
        action: @escaping (TrainerCommand) -> Void
    ) {
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.systemImage = systemImage
        self.command = command
        self.minimumHeight = max(56, minimumHeight)
        self.styleRole = styleRole
        self.isEnabled = isEnabled
        self.isPending = isPending
        self.action = action
    }

    var body: some View {
        Button {
            action(command)
        } label: {
            VStack(spacing: TrainerTheme.Spacing.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }

                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .padding(.horizontal, TrainerTheme.Spacing.regular)
            .overlay(alignment: .topTrailing) {
                if isPending {
                    ProgressView()
                        .tint(.white)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(TrainerPressStyle(role: styleRole, radius: minimumHeight > 76 ? TrainerTheme.Radius.prominentControl : TrainerTheme.Radius.control))
        .disabled(!isEnabled || isPending)
        .opacity(isEnabled ? 1 : 0.68)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? accessibilityHint : "Disponibile quando il Mac è collegato")
    }
}
