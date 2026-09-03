import SwiftUI

struct TrainerPressStyle: ButtonStyle {
    enum Role {
        case primary
        case regular
        case subtle
        case direction

        var foreground: Color {
            switch self {
            case .primary, .regular, .direction:
                TrainerTheme.primaryText
            case .subtle:
                TrainerTheme.secondaryText
            }
        }

        func fallbackFill(isPressed: Bool) -> Color {
            switch self {
            case .primary:
                isPressed ? Color.white.opacity(0.22) : Color.white.opacity(0.14)
            case .regular, .direction:
                isPressed ? TrainerTheme.panelPressed : TrainerTheme.panel
            case .subtle:
                isPressed ? Color.white.opacity(0.12) : TrainerTheme.panelSubtle
            }
        }

        func glassTint(isPressed: Bool) -> Color {
            switch self {
            case .primary:
                isPressed ? Color.white.opacity(0.22) : Color.white.opacity(0.15)
            case .regular, .direction:
                isPressed ? TrainerTheme.glassTintPressed : TrainerTheme.glassTint
            case .subtle:
                isPressed ? Color.white.opacity(0.13) : Color.white.opacity(0.075)
            }
        }

        var stroke: Color {
            switch self {
            case .primary:
                Color.white.opacity(0.22)
            case .regular, .direction:
                TrainerTheme.border
            case .subtle:
                Color.white.opacity(0.09)
            }
        }
    }

    var role: Role = .regular
    var radius: CGFloat = TrainerTheme.Radius.control
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let base = configuration.label
            .foregroundStyle(role.foreground)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(pressed ? 0.14 : 0.08),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(role.stroke, lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .scaleEffect(pressed && !reduceMotion ? 0.965 : 1)
            .animation(.smooth(duration: 0.14), value: pressed)

        if #available(iOS 26.0, *) {
            base
                .glassEffect(.regular.tint(role.glassTint(isPressed: pressed)).interactive(), in: .rect(cornerRadius: radius))
        } else {
            base
                .background {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(role.fallbackFill(isPressed: pressed))
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(role.stroke, lineWidth: 1)
                        }
                }
        }
    }
}
