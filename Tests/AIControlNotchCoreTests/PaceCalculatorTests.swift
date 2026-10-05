import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct PaceCalculatorTests {
    let now = TestClock.now
    let week = 10_080

    /// A week window with `elapsed` percent of its duration already gone.
    private func window(used: Double, elapsed: Double, minutes: Int = 10_080) -> UsageWindow {
        let remaining = Double(minutes) * 60 * (1 - elapsed / 100)
        return .make(.week, used: used, minutes: minutes, resetsAt: now.addingTimeInterval(remaining))
    }

    @Test func elapsedPercent() {
        let value = PaceCalculator.elapsedPercent(window(used: 10, elapsed: 25), now: now)
        #expect(abs((value ?? 0) - 25) < 0.001)
    }

    @Test func elapsedIsNilWithoutReset() {
        #expect(PaceCalculator.elapsedPercent(.make(used: 10), now: now) == nil)
    }

    @Test func okWhenProjectedAtMost85() {
        #expect(PaceCalculator.tone(window(used: 42.5, elapsed: 50), now: now) == .ok)
    }

    @Test func warnWhenProjectedAtMost105() {
        #expect(PaceCalculator.tone(window(used: 43, elapsed: 50), now: now) == .warn)
        #expect(PaceCalculator.tone(window(used: 52.5, elapsed: 50), now: now) == .warn)
    }

    @Test func dangerWhenProjectedAbove105() {
        #expect(PaceCalculator.tone(window(used: 53, elapsed: 50), now: now) == .danger)
    }

    @Test func dangerAtFullUsage() {
        #expect(PaceCalculator.tone(window(used: 100, elapsed: 99), now: now) == .danger)
        #expect(PaceCalculator.tone(.make(used: 100), now: now) == .danger)
    }

    @Test func earlyWindowIsOkUnlessNinety() {
        #expect(PaceCalculator.tone(window(used: 30, elapsed: 1), now: now) == .ok)
        #expect(PaceCalculator.tone(window(used: 90, elapsed: 1), now: now) == .danger)
    }

    @Test func noResetMeansOk() {
        #expect(PaceCalculator.tone(.make(used: 50), now: now) == .ok)
    }

    @Test func worstToneAcrossWindows() {
        let windows = [window(used: 10, elapsed: 50), window(used: 53, elapsed: 50)]
        #expect(PaceCalculator.worst(windows, now: now) == .danger)
        #expect(PaceCalculator.worst([], now: now) == .ok)
    }

    @Test func staleAfterThirtyMinutes() {
        #expect(!PaceCalculator.isStale(fetchedAt: now.addingTimeInterval(-30 * 60), now: now))
        #expect(PaceCalculator.isStale(fetchedAt: now.addingTimeInterval(-30 * 60 - 1), now: now))
    }

    @Test func tonesAreOrdered() {
        #expect(PaceTone.ok < .warn)
        #expect(PaceTone.warn < .danger)
    }
}

@Suite struct UsageWindowTests {
    let now = TestClock.now

    @Test func expiredWindowNormalizesToZero() {
        let expired = UsageWindow.make(used: 91, resetsAt: now.addingTimeInterval(-1))
        let normalized = expired.normalized(now: now)
        #expect(normalized.usedPercent == 0)
        #expect(normalized.resetsAt == nil)
        #expect(normalized.kind == expired.kind)
    }

    @Test func activeWindowIsUnchanged() {
        let active = UsageWindow.make(used: 91, resetsAt: now.addingTimeInterval(60))
        #expect(active.normalized(now: now) == active)
    }

    @Test func roundedPercentIsClampedForDisplay() {
        #expect(UsageWindow.make(used: 37.6).displayPercent == 38)
        #expect(UsageWindow.make(used: 120).displayPercent == 100)
        #expect(UsageWindow.make(used: -3).displayPercent == 0)
    }

    @Test func snapshotNormalizesAndSortsWindows() {
        let snapshot = ProviderSnapshot.make(windows: [
            .make(.week, used: 50, resetsAt: now.addingTimeInterval(-5)),
            .make(.session, used: 20, minutes: 300, resetsAt: now.addingTimeInterval(60)),
        ])
        let normalized = snapshot.normalized(now: now)
        #expect(normalized.windows.map(\.kind) == [.session, .week])
        #expect(normalized.windows[1].usedPercent == 0)
        #expect(normalized.maxPercent == 20)
    }

    @Test func maxPercentIsNilWithoutWindows() {
        #expect(ProviderSnapshot.make(windows: []).maxPercent == nil)
    }
}
