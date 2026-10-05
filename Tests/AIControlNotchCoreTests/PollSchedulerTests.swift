import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct PollSchedulerTests {
    let scheduler = PollScheduler()
    let now = TestClock.now

    @Test func intervalDependsOnIdleTime() {
        #expect(scheduler.interval(idleSeconds: 0) == 300)
        #expect(scheduler.interval(idleSeconds: 600) == 300)
        #expect(scheduler.interval(idleSeconds: 601) == 900)
    }

    @Test func freshStateCanAttempt() {
        #expect(scheduler.canAttempt(BackoffState(), now: now, manual: false))
    }

    @Test func minimumIntervalBetweenAttempts() {
        let state = scheduler.recordSuccess(BackoffState(), now: now)
        #expect(!scheduler.canAttempt(state, now: now.addingTimeInterval(179), manual: false))
        #expect(scheduler.canAttempt(state, now: now.addingTimeInterval(180), manual: false))
    }

    @Test func manualRefreshHasShorterMinimum() {
        let state = scheduler.recordSuccess(BackoffState(), now: now)
        #expect(!scheduler.canAttempt(state, now: now.addingTimeInterval(59), manual: true))
        #expect(scheduler.canAttempt(state, now: now.addingTimeInterval(60), manual: true))
    }

    @Test func backoffStepsGrowAndCap() {
        let waits = (0..<6).reduce(into: (BackoffState(), [TimeInterval]())) { acc, _ in
            acc.0 = scheduler.recordFailure(acc.0, now: now, retryAfter: nil)
            acc.1.append(acc.0.nextAllowed!.timeIntervalSince(now))
        }.1
        #expect(waits == [300, 600, 1_200, 1_800, 1_800, 1_800])
    }

    @Test func backoffBlocksEvenManualRefresh() {
        let state = scheduler.recordFailure(BackoffState(), now: now, retryAfter: nil)
        #expect(!scheduler.canAttempt(state, now: now.addingTimeInterval(299), manual: true))
        #expect(scheduler.canAttempt(state, now: now.addingTimeInterval(300), manual: false))
    }

    @Test func retryAfterLongerThanStepWins() {
        let state = scheduler.recordFailure(BackoffState(), now: now, retryAfter: 2_400)
        #expect(state.nextAllowed == now.addingTimeInterval(2_400))
    }

    @Test func retryAfterShorterThanStepIsIgnored() {
        let state = scheduler.recordFailure(BackoffState(), now: now, retryAfter: 30)
        #expect(state.nextAllowed == now.addingTimeInterval(300))
    }

    @Test func zeroOrNegativeRetryAfterIsIgnored() {
        #expect(scheduler.recordFailure(BackoffState(), now: now, retryAfter: 0).nextAllowed == now.addingTimeInterval(300))
        #expect(scheduler.recordFailure(BackoffState(), now: now, retryAfter: -5).nextAllowed == now.addingTimeInterval(300))
    }

    @Test func successResetsBackoff() {
        let failed = scheduler.recordFailure(
            scheduler.recordFailure(BackoffState(), now: now, retryAfter: nil), now: now, retryAfter: nil
        )
        let recovered = scheduler.recordSuccess(failed, now: now)
        #expect(recovered.failures == 0)
        #expect(recovered.nextAllowed == nil)
        #expect(recovered.lastAttempt == now)
    }
}
