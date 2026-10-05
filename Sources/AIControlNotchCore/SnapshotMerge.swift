import Foundation

/// How a new reading combines with the cached one for the same AI.
enum SnapshotMerge {
    /// Readings whose resets differ by less than this describe the same window.
    static let samePeriodTolerance: TimeInterval = 10 * 60

    /// The fresher reading wins. A local replay (an idle Claude Code session, old session logs)
    /// cannot lower the usage of a window that is still running, bring back a period that has
    /// already renewed, or drop a running window it does not mention. The primary sources are
    /// authoritative and may lower usage (a provider-side reset or correction).
    static func merge(_ candidate: ProviderSnapshot?, into cached: ProviderSnapshot?) -> ProviderSnapshot? {
        guard let candidate else { return cached }
        guard let cached else { return candidate }
        guard candidate.fetchedAt >= cached.fetchedAt else { return cached }
        guard candidate.source.replaysOlderReadings else { return candidate }
        let running = cached.windows.filter { isRunning($0, at: candidate.fetchedAt) }
        let replayed = candidate.windows.map { window in
            reconciled(window, with: running.first { $0.kind == window.kind })
        }
        let unmentioned = running.filter { old in !candidate.windows.contains { $0.kind == old.kind } }
        return ProviderSnapshot(
            provider: candidate.provider,
            windows: replayed + unmentioned,
            planLabel: candidate.planLabel,
            fetchedAt: candidate.fetchedAt,
            source: candidate.source
        )
    }

    /// A replayed window checked against the running window of the same kind, if any.
    private static func reconciled(_ window: UsageWindow, with running: UsageWindow?) -> UsageWindow {
        guard let running, let runningReset = running.resetsAt else { return window }
        // Without a reset time, the replay is taken to belong to the running period.
        guard let reset = window.resetsAt else { return peak(window, running) }
        let shift = reset.timeIntervalSince(runningReset)
        if shift <= -samePeriodTolerance { return running } // an older period, replayed
        if shift < samePeriodTolerance { return peak(window, running) }
        return window // a newer period: the window renewed
    }

    /// The higher usage of two readings of the same period.
    private static func peak(_ window: UsageWindow, _ running: UsageWindow) -> UsageWindow {
        UsageWindow(
            kind: window.kind,
            usedPercent: max(window.usedPercent, running.usedPercent),
            durationMinutes: window.durationMinutes,
            resetsAt: window.resetsAt ?? running.resetsAt,
            label: window.label
        )
    }

    /// Not renewed yet, and renewing no further away than the window's own length
    /// (anything later is a bad reading that must not hold new ones back).
    private static func isRunning(_ window: UsageWindow, at date: Date) -> Bool {
        guard let reset = window.resetsAt else { return false }
        let remaining = reset.timeIntervalSince(date)
        return remaining > 0 && remaining <= TimeInterval(window.durationMinutes) * 60 + samePeriodTolerance
    }
}
