import Foundation

/// Projects usage to the end of the window to color the pace dot.
public enum PaceCalculator {
    static let okLimit = 85.0
    static let warnLimit = 105.0
    static let earlyElapsed = 2.0
    static let earlyDangerUsage = 90.0
    static let staleAfter: TimeInterval = 30 * 60

    /// Percent of the window's duration already gone, or `nil` without a reset time.
    public static func elapsedPercent(_ window: UsageWindow, now: Date) -> Double? {
        guard let resetsAt = window.resetsAt, window.durationMinutes > 0 else { return nil }
        let duration = Double(window.durationMinutes) * 60
        let remaining = resetsAt.timeIntervalSince(now)
        return min(100, max(0, (duration - remaining) / duration * 100))
    }

    public static func tone(_ window: UsageWindow, now: Date) -> PaceTone {
        if window.usedPercent >= 100 { return .danger }
        guard let elapsed = elapsedPercent(window, now: now) else { return .ok }
        if elapsed < earlyElapsed {
            return window.usedPercent >= earlyDangerUsage ? .danger : .ok
        }
        let projected = window.usedPercent / elapsed * 100
        if projected <= okLimit { return .ok }
        if projected <= warnLimit { return .warn }
        return .danger
    }

    public static func worst(_ windows: [UsageWindow], now: Date) -> PaceTone {
        windows.map { tone($0, now: now) }.max() ?? .ok
    }

    public static func isStale(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > staleAfter
    }
}
