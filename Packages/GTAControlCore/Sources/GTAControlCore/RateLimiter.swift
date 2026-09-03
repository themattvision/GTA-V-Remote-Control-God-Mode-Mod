import Foundation

public struct RateLimiter: Sendable {
    public let limit: Int
    public let interval: Duration
    private var accepted: [ContinuousClock.Instant]

    public init(
        limit: Int = ProtocolConstants.maximumCommandsPerSecond,
        interval: Duration = .seconds(1)
    ) {
        precondition(limit > 0 && limit <= ProtocolConstants.maximumCommandsPerSecond)
        precondition(interval > .zero)
        self.limit = limit
        self.interval = interval
        accepted = []
        accepted.reserveCapacity(limit)
    }

    @discardableResult
    public mutating func allow(at now: ContinuousClock.Instant = .now) -> Bool {
        accepted.removeAll { instant in
            instant.duration(to: now) >= interval
        }
        guard accepted.count < limit else { return false }
        accepted.append(now)
        return true
    }
}

