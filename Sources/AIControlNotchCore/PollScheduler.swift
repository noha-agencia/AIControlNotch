import Foundation

/// Per-source attempt history used for minimum intervals and backoff.
public struct BackoffState: Codable, Equatable, Sendable {
    public let failures: Int
    public let nextAllowed: Date?
    public let lastAttempt: Date?

    public init(failures: Int = 0, nextAllowed: Date? = nil, lastAttempt: Date? = nil) {
        self.failures = failures
        self.nextAllowed = nextAllowed
        self.lastAttempt = lastAttempt
    }
}

/// Poll intervals, minimum spacing and progressive backoff.
public struct PollScheduler: Sendable {
    static let activeInterval: TimeInterval = 5 * 60
    static let idleInterval: TimeInterval = 15 * 60
    static let idleThreshold: TimeInterval = 10 * 60
    static let minimumSpacing: TimeInterval = 3 * 60
    static let manualSpacing: TimeInterval = 60
    static let maximumRetryAfter: TimeInterval = 60 * 60
    static let backoffSteps: [TimeInterval] = [5 * 60, 10 * 60, 20 * 60, 30 * 60]

    public init() {}

    public func interval(idleSeconds: TimeInterval) -> TimeInterval {
        idleSeconds > Self.idleThreshold ? Self.idleInterval : Self.activeInterval
    }

    /// `spacing` replaces the automatic minimum (a script's own interval).
    public func canAttempt(_ state: BackoffState, now: Date, manual: Bool, spacing: TimeInterval? = nil) -> Bool {
        if let nextAllowed = state.nextAllowed, now < nextAllowed { return false }
        guard let lastAttempt = state.lastAttempt else { return true }
        let minimum = manual ? Self.manualSpacing : spacing ?? Self.minimumSpacing
        return now.timeIntervalSince(lastAttempt) >= minimum
    }

    public func recordSuccess(_ state: BackoffState, now: Date) -> BackoffState {
        BackoffState(failures: 0, nextAllowed: nil, lastAttempt: now)
    }

    public func recordFailure(_ state: BackoffState, now: Date, retryAfter: TimeInterval?) -> BackoffState {
        let failures = state.failures + 1
        let step = Self.backoffSteps[min(failures, Self.backoffSteps.count) - 1]
        let wait = max(step, min(retryAfter ?? 0, Self.maximumRetryAfter))
        return BackoffState(failures: failures, nextAllowed: now.addingTimeInterval(wait), lastAttempt: now)
    }
}
