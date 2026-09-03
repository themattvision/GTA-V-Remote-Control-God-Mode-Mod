import UIKit

@MainActor
final class HapticFeedback: SuccessFeedbackProviding {
    private let generator = UIImpactFeedbackGenerator(style: .light)

    func commandWasAcknowledged() {
        generator.impactOccurred(intensity: 0.75)
        generator.prepare()
    }
}
