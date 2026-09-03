import SwiftUI

/// Superficie premium riusabile: Liquid Glass nativo dove disponibile, fallback sobrio sugli SDK precedenti.
struct AppleGlassCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(.regular.tint(TrainerTheme.glassTint), in: .rect(cornerRadius: TrainerTheme.Radius.card))
        } else {
            content
                .padding(padding)
                .background {
                    RoundedRectangle(cornerRadius: TrainerTheme.Radius.card, style: .continuous)
                        .fill(TrainerTheme.panel)
                        .overlay {
                            RoundedRectangle(cornerRadius: TrainerTheme.Radius.card, style: .continuous)
                                .stroke(TrainerTheme.border, lineWidth: 1)
                        }
                }
        }
    }
}
