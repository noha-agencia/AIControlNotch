import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ThresholdTrackerTests {
    let tracker = ThresholdTracker()
    let reset = TestClock.date(2026, 10, 5, 18, 38)

    private func snapshot(_ used: Double, resetsAt: Date? = nil, kind: WindowKind = .week) -> ProviderSnapshot {
        .make(.codex, windows: [.make(kind, used: used, resetsAt: resetsAt ?? reset)])
    }

    /// Runs the tracker over a sequence of readings, returning every alert bucket raised.
    private func run(_ readings: [Double], from state: ThresholdState = ThresholdState()) -> (ThresholdState, [Int]) {
        readings.reduce((state, [Int]())) { acc, used in
            let (next, alerts) = tracker.evaluate(snapshot(used), state: acc.0)
            return (next, acc.1 + alerts.map(\.bucket))
        }
    }

    @Test func firstRunIsSilent() {
        let (state, alerts) = tracker.evaluate(snapshot(91), state: ThresholdState())
        #expect(alerts.isEmpty)
        #expect(state.entries["codex.week"]?.lastNotified == 90)
    }

    @Test func crossingABucketAlertsOnce() {
        let (_, buckets) = run([38, 41, 44])
        #expect(buckets == [40])
    }

    @Test func jumpingSeveralBucketsAlertsOnlyTheCurrent() {
        let (_, buckets) = run([38, 73])
        #expect(buckets == [70])
    }

    @Test func reachingTheLimitAlertsAtHundred() {
        let (_, buckets) = run([91, 100, 104])
        #expect(buckets == [100])
    }

    @Test func belowTenNeverAlerts() {
        let (_, buckets) = run([0, 5, 9.9])
        #expect(buckets.isEmpty)
    }

    @Test func usageDropOfTwentyPointsIsARenewal() {
        let (_, buckets) = run([91, 12])
        #expect(buckets == [10])
    }

    @Test func smallDropIsNotARenewal() {
        let (_, buckets) = run([45, 30, 41])
        #expect(buckets.isEmpty)
    }

    @Test func resetMovingForwardIsARenewal() {
        let start = tracker.evaluate(snapshot(55), state: ThresholdState()).0
        let later = reset.addingTimeInterval(7 * 86_400)
        let (_, alerts) = tracker.evaluate(snapshot(52, resetsAt: later), state: start)
        #expect(alerts.map(\.bucket) == [50])
    }

    @Test func resetJitterIsNotARenewal() {
        let start = tracker.evaluate(snapshot(55), state: ThresholdState()).0
        let (_, alerts) = tracker.evaluate(snapshot(56, resetsAt: reset.addingTimeInterval(9 * 60)), state: start)
        #expect(alerts.isEmpty)
    }

    @Test func restartWithSavedStateDoesNotRepeat() throws {
        let (saved, _) = run([38, 41])
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(ThresholdState.self, from: data)
        let (_, buckets) = run([42, 49], from: restored)
        #expect(buckets.isEmpty)
    }

    @Test func newWindowInitializesSilently() {
        let start = tracker.evaluate(snapshot(20), state: ThresholdState()).0
        let both = ProviderSnapshot.make(.codex, windows: [
            .make(.week, used: 21, resetsAt: reset),
            .make(.session, used: 64, minutes: 300, resetsAt: reset),
        ])
        let (state, alerts) = tracker.evaluate(both, state: start)
        #expect(alerts.isEmpty)
        #expect(state.entries["codex.session"]?.lastNotified == 60)
    }

    @Test func alertCarriesContext() throws {
        let start = tracker.evaluate(snapshot(85), state: ThresholdState()).0
        let (_, alerts) = tracker.evaluate(snapshot(90.4), state: start)
        let alert = try #require(alerts.first)
        #expect(alert.provider == .codex)
        #expect(alert.kind == .week)
        #expect(alert.bucket == 90)
        #expect(alert.resetsAt == reset)
        #expect(alert.key == "codex.week")
        #expect(!alert.isLimit)
    }

    @Test func providersAreTrackedIndependently() {
        var state = ThresholdState()
        state = tracker.evaluate(.make(.claude, windows: [.make(.week, used: 20, resetsAt: reset)]), state: state).0
        state = tracker.evaluate(.make(.codex, windows: [.make(.week, used: 20, resetsAt: reset)]), state: state).0
        let (_, alerts) = tracker.evaluate(.make(.claude, windows: [.make(.week, used: 31, resetsAt: reset)]), state: state)
        #expect(alerts.map(\.provider) == [.claude])
    }

    @Test(arguments: [(9.99, 0), (10, 10), (19.9, 10), (99.9, 90), (100, 100), (130, 100)])
    func bucketFormula(used: Double, expected: Int) {
        #expect(ThresholdTracker.bucket(for: used) == expected)
    }
}

@Suite struct AlertQueueTests {
    private func alert(_ provider: ProviderID, _ kind: WindowKind, _ bucket: Int) -> ThresholdAlert {
        ThresholdAlert(provider: provider, kind: kind, bucket: bucket, resetsAt: nil)
    }

    @Test func isFirstInFirstOut() {
        var queue = AlertQueue()
        queue.enqueue([alert(.claude, .session, 40), alert(.codex, .week, 90)])
        #expect(queue.dequeue()?.provider == .claude)
        #expect(queue.dequeue()?.provider == .codex)
        #expect(queue.dequeue() == nil)
        #expect(queue.isEmpty)
    }

    @Test func newerAlertForSameWindowReplacesQueuedOne() {
        var queue = AlertQueue()
        queue.enqueue([alert(.codex, .week, 90), alert(.claude, .session, 40)])
        queue.enqueue([alert(.codex, .week, 100)])
        #expect(queue.count == 2)
        #expect(queue.dequeue()?.bucket == 100)
    }

    @Test func limitAlertsStayLonger() {
        #expect(AlertQueue.displayDuration(for: alert(.codex, .week, 90)) == 4.5)
        #expect(AlertQueue.displayDuration(for: alert(.codex, .week, 100)) == 8)
    }
}

@Suite struct ThresholdRenewalTests {
    let tracker = ThresholdTracker()
    let now = TestClock.now

    @Test func expiredSessionThenNewSessionAlertsAgain() {
        let end = now.addingTimeInterval(3_600)
        let session = { (used: Double, resetsAt: Date?) in
            ProviderSnapshot.make(.claude, windows: [.make(.session, used: used, minutes: 300, resetsAt: resetsAt)])
        }
        var state = tracker.evaluate(session(15, end), state: ThresholdState()).0
        // The session expires: normalized to 0% with no reset time.
        state = tracker.evaluate(session(0, nil), state: state).0
        let (_, alerts) = tracker.evaluate(session(11, now.addingTimeInterval(5 * 3_600)), state: state)
        #expect(alerts.map(\.bucket) == [10])
    }

    @Test func windowWithoutResetTimesNeverRenewsByTime() {
        let snapshot = { (used: Double) in ProviderSnapshot.make(windows: [.make(used: used)]) }
        let state = tracker.evaluate(snapshot(35), state: ThresholdState()).0
        let (_, alerts) = tracker.evaluate(snapshot(36), state: state)
        #expect(alerts.isEmpty)
    }
}
