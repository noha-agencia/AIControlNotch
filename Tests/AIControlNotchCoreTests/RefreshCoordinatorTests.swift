import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct RefreshCoordinatorTests {
    let reset = TestClock.date(2026, 10, 5, 18, 38)

    private func codex(_ used: Double, at date: Date, source: DataSource = .codexAppServer) -> ProviderSnapshot {
        .make(.codex, windows: [.make(.week, used: used, resetsAt: reset)], fetchedAt: date, source: source)
    }

    private func claude(_ used: Double, at date: Date, source: DataSource = .claudeStatusLine) -> ProviderSnapshot {
        .make(.claude, windows: [.make(.session, used: used, minutes: 300, resetsAt: date.addingTimeInterval(3_600))], fetchedAt: date, source: source)
    }

    private struct Rig {
        let dir: TempDir
        let clock: MutableClock
        let claudeSource: StubProvider
        let codexPrimary: StubProvider
        let codexFallback: StubProvider
        let log = MemoryLog()

        var store: StateStore { StateStore(fileURL: dir.file("state.json")) }

        func coordinator() -> RefreshCoordinator {
            RefreshCoordinator(
                sources: [
                    FallbackProvider(primary: claudeSource),
                    FallbackProvider(primary: codexPrimary, fallback: codexFallback),
                ],
                store: store,
                log: log,
                now: { [clock] in clock.now }
            )
        }
    }

    private func rig() throws -> Rig {
        let clock = MutableClock()
        return Rig(
            dir: try TempDir(),
            clock: clock,
            claudeSource: StubProvider(.claudeStatusLine, .success(claude(38, at: clock.now)), provider: .claude),
            codexPrimary: StubProvider(.codexAppServer, .success(codex(91, at: clock.now))),
            codexFallback: StubProvider(.codexRollout, .failure(.notFound("logs")))
        )
    }

    @Test func firstRefreshLoadsBothSilently() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let result = await rig.coordinator().refresh(manual: false)
        #expect(result.snapshots[.claude]?.maxPercent == 38)
        #expect(result.snapshots[.codex]?.maxPercent == 91)
        #expect(result.alerts.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(rig.store.load()?.snapshots.count == 2)
    }

    @Test func crossingAStepRaisesAnAlert() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        _ = await coordinator.refresh(manual: false)
        rig.clock.advance(minutes: 5)
        rig.claudeSource.outcome = .success(claude(41, at: rig.clock.now))
        let result = await coordinator.refresh(manual: false)
        #expect(result.alerts.map(\.bucket) == [40])
        #expect(result.alerts.first?.provider == .claude)
    }

    @Test func alertsSurviveARestartWithoutRepeating() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        _ = await rig.coordinator().refresh(manual: false)
        rig.clock.advance(minutes: 5)
        rig.claudeSource.outcome = .success(claude(41, at: rig.clock.now))
        _ = await rig.coordinator().refresh(manual: false)
        rig.clock.advance(minutes: 5)
        let result = await rig.coordinator().refresh(manual: false)
        #expect(result.alerts.isEmpty)
    }

    @Test func minimumSpacingSkipsFetching() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        _ = await coordinator.refresh(manual: false)
        rig.clock.advance(minutes: 2)
        let result = await coordinator.refresh(manual: false)
        #expect(rig.codexPrimary.calls == 1)
        #expect(result.snapshots[.codex]?.maxPercent == 91)
        rig.clock.advance(minutes: 0.5)
        _ = await coordinator.refresh(manual: true)
        #expect(rig.codexPrimary.calls == 2)
    }

    @Test func failingPrimaryBacksOffAndUsesFallback() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        rig.codexPrimary.outcome = .failure(.timeout)
        rig.codexFallback.outcome = .success(codex(40, at: rig.clock.now, source: .codexRollout))
        let first = await coordinator.refresh(manual: false)
        #expect(first.snapshots[.codex]?.source == .codexRollout)
        #expect(rig.store.load()?.backoff["codexAppServer"]?.failures == 1)

        rig.clock.advance(minutes: 4)
        _ = await coordinator.refresh(manual: true)
        #expect(rig.codexPrimary.calls == 1, "primary stays paused during backoff")
        #expect(rig.codexFallback.calls == 2)

        rig.clock.advance(minutes: 2)
        rig.codexPrimary.outcome = .success(codex(42, at: rig.clock.now))
        let recovered = await coordinator.refresh(manual: false)
        #expect(recovered.snapshots[.codex]?.source == .codexAppServer)
        #expect(rig.store.load()?.backoff["codexAppServer"]?.failures == 0)
    }

    @Test func olderFallbackDataDoesNotReplaceFresherCache() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        _ = await coordinator.refresh(manual: false)
        rig.clock.advance(minutes: 5)
        rig.codexPrimary.outcome = .failure(.timeout)
        rig.codexFallback.outcome = .success(codex(70, at: rig.clock.now.addingTimeInterval(-3_600), source: .codexRollout))
        let result = await coordinator.refresh(manual: false)
        #expect(result.snapshots[.codex]?.source == .codexAppServer)
        #expect(result.snapshots[.codex]?.maxPercent == 91)
    }

    @Test func noDataAtAllIsAnIssue() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        rig.codexPrimary.outcome = .failure(.notFound("codex"))
        let result = await rig.coordinator().refresh(manual: false)
        #expect(result.snapshots[.codex] == nil)
        #expect(result.issues[.codex] == .noData)
    }

    @Test func renewedWindowsAreNormalized() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        _ = await coordinator.refresh(manual: false)
        rig.clock.advance(minutes: 4 * 24 * 60)
        rig.codexPrimary.outcome = .failure(.timeout)
        let result = await coordinator.refresh(manual: false)
        #expect(result.snapshots[.codex]?.maxPercent == 0)
    }

    @Test func cachedStateIsAvailableBeforeRefreshing() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        _ = await rig.coordinator().refresh(manual: false)
        let cached = await rig.coordinator().cached()
        #expect(cached.snapshots[.codex]?.maxPercent == 91)
        #expect(cached.alerts.isEmpty)
    }

    /// Two Claude Code sessions: the idle one saves its older numbers after the busy one did.
    @Test func idleSessionReplayRaisesNoRepeatAlert() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        let coordinator = rig.coordinator()
        let weekly = { [reset] (used: Double) in
            ProviderSnapshot.make(.claude, windows: [.make(.week, used: used, resetsAt: reset)], fetchedAt: rig.clock.now, source: .claudeStatusLine)
        }
        rig.claudeSource.outcome = .success(weekly(45))
        _ = await coordinator.refresh(manual: false)
        rig.clock.advance(minutes: 5)
        rig.claudeSource.outcome = .success(weekly(52))
        #expect(await coordinator.refresh(manual: false).alerts.map(\.bucket) == [50])

        rig.clock.advance(minutes: 5)
        rig.claudeSource.outcome = .success(weekly(20))
        let replayed = await coordinator.refresh(manual: false)
        #expect(replayed.snapshots[.claude]?.maxPercent == 52)
        #expect(replayed.alerts.isEmpty)

        rig.clock.advance(minutes: 5)
        rig.claudeSource.outcome = .success(weekly(53))
        #expect(await coordinator.refresh(manual: false).alerts.isEmpty)
    }

    @Test func failuresAreLoggedWithoutSecrets() async throws {
        let rig = try rig()
        defer { rig.dir.cleanup() }
        rig.codexPrimary.outcome = .failure(.timeout)
        _ = await rig.coordinator().refresh(manual: false)
        #expect(rig.log.lines.contains { $0.contains("codex") && $0.contains("timeout") })
        #expect(!rig.log.lines.contains { $0.contains("Bearer") })
    }
}

/// Never resumes, like a read stuck on a pipe: only a deadline gets the caller out.
private struct HangingProvider: UsageProvider {
    let provider = ProviderID.codex
    let source = DataSource.codexAppServer

    func fetch() async throws -> ProviderSnapshot {
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
        throw UsageError.timeout
    }
}

@Suite struct RefreshCoordinatorHardeningTests {
    let reset = TestClock.date(2026, 10, 5, 18, 38)

    private func codex(_ used: Double, at date: Date, source: DataSource) -> ProviderSnapshot {
        .make(.codex, windows: [.make(.week, used: used, resetsAt: reset)], fetchedAt: date, source: source)
    }

    @Test func staleLowerReadingOfTheSameWindowNeverLowersUsage() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let primary = StubProvider(.codexAppServer, .success(codex(91, at: clock.now, source: .codexAppServer)))
        let fallback = StubProvider(.codexRollout, .failure(.notFound("logs")))
        let coordinator = RefreshCoordinator(
            sources: [FallbackProvider(primary: primary, fallback: fallback)],
            store: StateStore(fileURL: dir.file("state.json")),
            now: { clock.now }
        )
        _ = await coordinator.refresh(manual: false)
        clock.advance(minutes: 5)
        primary.outcome = .failure(.timeout)
        fallback.outcome = .success(codex(70, at: clock.now, source: .codexRollout))
        let result = await coordinator.refresh(manual: false)
        #expect(result.snapshots[.codex]?.maxPercent == 91)
        #expect(result.alerts.isEmpty)
    }

    @Test func hungSourceTimesOutWithoutBlockingTheRefresh() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let store = StateStore(fileURL: dir.file("state.json"))
        let coordinator = RefreshCoordinator(
            sources: [FallbackProvider(primary: HangingProvider(), fallback: StubProvider(.codexRollout, .failure(.notFound("logs"))))],
            store: store,
            sourceTimeout: 0.2
        )
        let started = Date()
        let result = await coordinator.refresh(manual: false)
        #expect(Date().timeIntervalSince(started) < 2)
        #expect(result.issues[.codex] == .noData)
        #expect(store.load()?.backoff["codexAppServer"]?.failures == 1)
    }

    @Test func concurrentRefreshesShareOneFetch() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let primary = StubProvider(.codexAppServer, .success(codex(10, at: TestClock.now, source: .codexAppServer)))
        let coordinator = RefreshCoordinator(
            sources: [FallbackProvider(primary: primary, fallback: StubProvider(.codexRollout, .failure(.notFound("logs"))))],
            store: StateStore(fileURL: dir.file("state.json")),
            now: { TestClock.now }
        )
        async let first = coordinator.refresh(manual: true)
        async let second = coordinator.refresh(manual: true)
        let results = await [first, second]
        #expect(primary.calls == 1)
        #expect(results.allSatisfy { $0.snapshots[.codex]?.maxPercent == 10 })
    }
}
