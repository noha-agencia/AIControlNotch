import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct SnapshotMergeTests {
    let reset = TestClock.date(2026, 10, 5, 18, 38)
    let week: TimeInterval = 7 * 86_400

    private func later(_ minutes: Double) -> Date { TestClock.now.addingTimeInterval(minutes * 60) }

    private func reading(_ used: Double, minutesLater: Double, source: DataSource) -> ProviderSnapshot {
        .make(.codex, windows: [.make(.week, used: used, resetsAt: reset)], fetchedAt: later(minutesLater), source: source)
    }

    /// A Claude status line reading: a local replay, which an idle Claude Code session can also write.
    private func claude(_ windows: [UsageWindow], minutesLater: Double) -> ProviderSnapshot {
        .make(.claude, windows: windows, fetchedAt: later(minutesLater), source: .claudeStatusLine)
    }

    private func claude(_ used: Double, minutesLater: Double, resetsAt: Date?) -> ProviderSnapshot {
        claude([.make(.week, used: used, resetsAt: resetsAt)], minutesLater: minutesLater)
    }

    private func session(_ used: Double, resetsAt: Date?) -> UsageWindow {
        .make(.session, used: used, minutes: 300, resetsAt: resetsAt)
    }

    // MARK: Primary sources

    @Test func primaryReadingMayLowerUsage() {
        let merged = SnapshotMerge.merge(reading(40, minutesLater: 5, source: .codexAppServer), into: reading(60, minutesLater: 0, source: .codexAppServer))
        #expect(merged?.maxPercent == 40)
    }

    @Test func primaryReadingOfAnOlderPeriodReplacesOutright() {
        let older = ProviderSnapshot.make(.codex, windows: [.make(.week, used: 80, resetsAt: reset.addingTimeInterval(-week))], fetchedAt: later(5))
        #expect(SnapshotMerge.merge(older, into: reading(5, minutesLater: 0, source: .codexAppServer))?.maxPercent == 80)
    }

    @Test func olderCandidateNeverWins() {
        let cached = reading(60, minutesLater: 10, source: .codexAppServer)
        #expect(SnapshotMerge.merge(reading(70, minutesLater: 0, source: .codexAppServer), into: cached) == cached)
    }

    // MARK: Local replays

    @Test func fallbackReplayKeepsThePrimaryPeak() {
        let merged = SnapshotMerge.merge(reading(40, minutesLater: 5, source: .codexRollout), into: reading(60, minutesLater: 0, source: .codexAppServer))
        #expect(merged?.maxPercent == 60)
        #expect(merged?.source == .codexRollout)
    }

    @Test func newWindowFromAFallbackStartsFresh() {
        let next = ProviderSnapshot.make(.codex, windows: [.make(.week, used: 5, resetsAt: reset.addingTimeInterval(week))], fetchedAt: later(5), source: .codexRollout)
        #expect(SnapshotMerge.merge(next, into: reading(60, minutesLater: 0, source: .codexAppServer))?.maxPercent == 5)
    }

    @Test func replayKeepsItsOwnPeakInTheSamePeriod() {
        let merged = SnapshotMerge.merge(claude(40, minutesLater: 5, resetsAt: reset), into: claude(60, minutesLater: 0, resetsAt: reset))
        #expect(merged?.maxPercent == 60)
    }

    @Test func resetTimesLessThanTenMinutesApartAreTheSamePeriod() {
        let nearby = SnapshotMerge.merge(claude(40, minutesLater: 5, resetsAt: reset.addingTimeInterval(9 * 60)), into: claude(60, minutesLater: 0, resetsAt: reset))
        let apart = SnapshotMerge.merge(claude(40, minutesLater: 5, resetsAt: reset.addingTimeInterval(10 * 60)), into: claude(60, minutesLater: 0, resetsAt: reset))
        #expect(nearby?.maxPercent == 60)
        #expect(apart?.maxPercent == 40)
    }

    @Test func replayOfARenewedPeriodStartsFresh() {
        let merged = SnapshotMerge.merge(claude(5, minutesLater: 5, resetsAt: reset.addingTimeInterval(week)), into: claude(60, minutesLater: 0, resetsAt: reset))
        #expect(merged?.maxPercent == 5)
    }

    @Test func replayOfAnOlderPeriodNeverReplacesANewerOne() {
        let stale = claude(80, minutesLater: 5, resetsAt: reset.addingTimeInterval(-week))
        let merged = SnapshotMerge.merge(stale, into: claude(5, minutesLater: 0, resetsAt: reset))
        #expect(merged?.maxPercent == 5)
        #expect(merged?.windows.first?.resetsAt == reset)
        #expect(merged?.fetchedAt == stale.fetchedAt)
    }

    /// A reset further away than the window's own length is impossible, so it never holds readings back.
    @Test func impossibleCachedResetIsIgnored() {
        let poisoned = claude(90, minutesLater: 0, resetsAt: reset.addingTimeInterval(52 * week))
        #expect(SnapshotMerge.merge(claude(40, minutesLater: 5, resetsAt: reset), into: poisoned)?.maxPercent == 40)
    }

    @Test func replayWithoutAResetTimeBelongsToTheRunningPeriod() {
        let merged = SnapshotMerge.merge(claude(40, minutesLater: 5, resetsAt: nil), into: claude(60, minutesLater: 0, resetsAt: reset))
        #expect(merged?.maxPercent == 60)
        #expect(merged?.windows.first?.resetsAt == reset)
    }

    @Test func renewedCachedWindowNeverHoldsAReplayBack() {
        let merged = SnapshotMerge.merge(claude(5, minutesLater: 60, resetsAt: nil), into: claude(60, minutesLater: 0, resetsAt: later(30)))
        #expect(merged?.maxPercent == 5)
    }

    @Test func replayMissingAWindowKeepsTheRunningOne() {
        let cached = claude([session(30, resetsAt: later(120)), .make(.week, used: 60, resetsAt: reset)], minutesLater: 0)
        let merged = SnapshotMerge.merge(claude([session(35, resetsAt: later(120))], minutesLater: 5), into: cached)
        #expect(merged?.windows.map(\.kind) == [.session, .week])
        #expect(merged?.windows.map(\.displayPercent) == [35, 60])
    }

    @Test func replayMissingARenewedWindowDropsIt() {
        let cached = claude([session(30, resetsAt: later(3)), .make(.week, used: 60, resetsAt: reset)], minutesLater: 0)
        let merged = SnapshotMerge.merge(claude([.make(.week, used: 61, resetsAt: reset)], minutesLater: 5), into: cached)
        #expect(merged?.windows.map(\.kind) == [.week])
    }

    @Test func eachWindowIsReconciledOnItsOwn() {
        let cached = claude([session(90, resetsAt: later(2)), .make(.week, used: 60, resetsAt: reset)], minutesLater: 0)
        let candidate = claude([session(3, resetsAt: later(302)), .make(.week, used: 55, resetsAt: reset)], minutesLater: 5)
        #expect(SnapshotMerge.merge(candidate, into: cached)?.windows.map(\.displayPercent) == [3, 60])
    }
}
