import SwiftUI

enum TrainerTheme {
    enum Radius {
        static let small: CGFloat = 14
        static let control: CGFloat = 22
        static let prominentControl: CGFloat = 28
        static let card: CGFloat = 30
        static let sheet: CGFloat = 34
    }

    enum Spacing {
        static let tight: CGFloat = 8
        static let compact: CGFloat = 12
        static let regular: CGFloat = 16
        static let roomy: CGFloat = 24
    }

    static let background = Color(red: 0.015, green: 0.017, blue: 0.024)
    static let backgroundLift = Color(red: 0.045, green: 0.050, blue: 0.070)
    static let panel = Color.white.opacity(0.085)
    static let panelPressed = Color.white.opacity(0.18)
    static let panelSubtle = Color.white.opacity(0.055)
    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.40)
    static let border = Color.white.opacity(0.14)
    static let accent = Color(red: 0.62, green: 0.72, blue: 0.88)
    static let accentSoft = Color(red: 0.36, green: 0.43, blue: 0.58)
    static let success = Color(red: 0.48, green: 0.84, blue: 0.62)
    static let warning = Color(red: 0.95, green: 0.68, blue: 0.38)
    static let danger = Color(red: 0.94, green: 0.42, blue: 0.46)
    static let glassTint = Color.white.opacity(0.105)
    static let glassTintPressed = Color.white.opacity(0.17)
}

extension ShapeStyle where Self == Color {
    static var trainerBackground: Color { TrainerTheme.background }
    static var trainerPanel: Color { TrainerTheme.panel }
    static var trainerAccent: Color { TrainerTheme.accent }
}
