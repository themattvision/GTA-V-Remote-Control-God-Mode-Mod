import CoreGraphics
import GTAControlCore

struct DirectionPadSwipeResolver {
    static let minimumDistance: CGFloat = 48

    static func command(
        for translation: CGSize,
        minimumDistance: CGFloat = DirectionPadSwipeResolver.minimumDistance
    ) -> TrainerCommand? {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)

        guard max(horizontalDistance, verticalDistance) >= minimumDistance else {
            return nil
        }

        if horizontalDistance > verticalDistance {
            return translation.width > 0 ? .moveRight : .moveLeft
        }

        if verticalDistance > horizontalDistance {
            return translation.height > 0 ? .moveDown : .moveUp
        }

        return nil
    }
}
