import SwiftUI

struct TrainerBackdrop: View {
    var body: some View {
        ZStack {
            TrainerTheme.background

            LinearGradient(
                colors: [
                    Color(red: 0.130, green: 0.145, blue: 0.205),
                    Color(red: 0.030, green: 0.035, blue: 0.052),
                    Color(red: 0.072, green: 0.060, blue: 0.086)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AngularGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.075),
                    Color(red: 0.26, green: 0.31, blue: 0.44).opacity(0.22),
                    .clear,
                    Color(red: 0.44, green: 0.38, blue: 0.50).opacity(0.12),
                    .clear
                ],
                center: .center,
                angle: .degrees(-28)
            )
            .blur(radius: 34)
            .opacity(0.72)

            RadialGradient(
                colors: [
                    TrainerTheme.accentSoft.opacity(0.54),
                    TrainerTheme.accentSoft.opacity(0.18),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 420
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.60, green: 0.66, blue: 0.78).opacity(0.34),
                    Color(red: 0.60, green: 0.66, blue: 0.78).opacity(0.09),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 520
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.42, blue: 0.54).opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.54, y: 0.48),
                startRadius: 20,
                endRadius: 330
            )
            .blendMode(.screen)

            TrainerGridOverlay()
                .opacity(0.12)
                .mask {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.62), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }
}

private struct TrainerGridOverlay: View {
    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let spacing: CGFloat = 34
            let lineColor = Color.white.opacity(0.07)

            for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }

            for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}
