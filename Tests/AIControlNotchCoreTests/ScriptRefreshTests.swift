import Foundation
import Testing
@testable import AIControlNotchCore

/// A source with no fallback and its own spacing and deadline, like a script provider.
private final class ScriptStub: UsageProvider, @unchecked Sendable {
    let provider: ProviderID
    let source = DataSource.script
    let policy: FetchPolicy
    var outcome: Result<ProviderSnapshot, UsageError>
    var delay: TimeInterval = 0
    private(set) var calls = 0

    init(_ provider: ProviderID, _ outcome: Result<ProviderSnapshot, UsageError>, policy: FetchPolicy) {
        self.provider = provider
        self.outcome = outcome
        self.policy = policy
    }

    func fetch() async throws -> ProviderSnapshot {
        calls += 1
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        return try outcome.get()
    }
}

@Suite struct ScriptRefreshTests {
    let kimi = ProviderID("kimi")!

    private func snapshot(_ used: Double, at date: Date) -> ProviderSnapshot {
        .make(kimi, windows: [.make(.session, used: used, minutes: 300, resetsAt: date.addingTimeInterval(3_600))], fetchedAt: date, source: .script)
    }

    private func coordinator(_ sources: [FallbackProvider], dir: TempDir, clock: MutableClock, timeout: TimeInterval = 5) -> RefreshCoordinator {
        RefreshCoordinator(sources: sources, store: StateStore(fileURL: dir.file("state.json")), sourceTimeout: timeout, now: { clock.now })
    }

    @Test func failingScriptKeepsItsNumbersAndSaysWhy() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: FetchPolicy(timeout: nil, minimumSpacing: 60))
        let coordinator = coordinator([FallbackProvider(primary: script)], dir: dir, clock: clock)
        _ = await coordinator.refresh(manual: false)
        clock.advance(minutes: 5)
        script.outcome = .failure(.script(.exit(3)))
        let result = await coordinator.refresh(manual: false)
        #expect(result.snapshots[kimi]?.maxPercent == 30)
        #expect(result.issues[kimi] == .scriptFailed(.exit(3)))
        #expect(StateStore(fileURL: dir.file("state.json")).load()?.backoff["script.kimi"]?.failures == 0, "script errors never back off")
    }

    @Test func scriptsUseTheirOwnSpacing() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: FetchPolicy(timeout: nil, minimumSpacing: 600))
        let coordinator = coordinator([FallbackProvider(primary: script)], dir: dir, clock: clock)
        _ = await coordinator.refresh(manual: false)
        clock.advance(minutes: 5)
        _ = await coordinator.refresh(manual: false)
        #expect(script.calls == 1, "600 s apart, not the built-in 180 s")
        clock.advance(minutes: 5)
        _ = await coordinator.refresh(manual: false)
        #expect(script.calls == 2)
    }

    @Test func aLongerScriptTimeoutExtendsTheDeadline() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: FetchPolicy(timeout: 2, minimumSpacing: 60))
        script.delay = 0.3
        let result = await coordinator([FallbackProvider(primary: script)], dir: dir, clock: clock, timeout: 0.1).refresh(manual: false)
        #expect(result.snapshots[kimi]?.maxPercent == 30)
    }

    @Test func backingOffWithoutAFallbackSkipsAndKeepsTheIssue() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .failure(.timeout), policy: FetchPolicy(timeout: nil, minimumSpacing: 60))
        let coordinator = coordinator([FallbackProvider(primary: script)], dir: dir, clock: clock)
        let first = await coordinator.refresh(manual: false)
        #expect(first.issues[kimi] == .noData)
        clock.advance(minutes: 2)
        let second = await coordinator.refresh(manual: true)
        #expect(script.calls == 1, "still backing off")
        #expect(second.issues[kimi] == .noData)
    }

    @Test func replacingSourcesDropsModelsThatLeft() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: .standard)
        let codex = StubProvider(.codexAppServer, .success(.make(.codex, windows: [.make(used: 50)], fetchedAt: clock.now)))
        let coordinator = coordinator([FallbackProvider(primary: script), FallbackProvider(primary: codex)], dir: dir, clock: clock)
        _ = await coordinator.refresh(manual: false)
        await coordinator.replaceSources([FallbackProvider(primary: codex)])
        let cached = await coordinator.cached()
        #expect(Array(cached.snapshots.keys) == [.codex])
        #expect(StateStore(fileURL: dir.file("state.json")).load()?.snapshots[kimi] == nil)
    }

    /// Review H1: a model removed and later re-added must not inherit old spacing or alert steps.
    @Test func replacingSourcesForgetsTheSpacingAndAlertsOfModelsThatLeft() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: FetchPolicy(timeout: nil, minimumSpacing: 600))
        let codex = StubProvider(.codexAppServer, .success(.make(.codex, windows: [.make(used: 50)], fetchedAt: clock.now)))
        let coordinator = coordinator([FallbackProvider(primary: script), FallbackProvider(primary: codex)], dir: dir, clock: clock)
        _ = await coordinator.refresh(manual: false)
        await coordinator.replaceSources([FallbackProvider(primary: codex)])
        let saved = StateStore(fileURL: dir.file("state.json")).load()
        #expect(saved?.backoff["script.kimi"] == nil)
        #expect(saved?.backoff["codexAppServer"] != nil)
        #expect(saved?.thresholds.entries.keys.contains { $0.hasPrefix("kimi.") } == false)
        #expect(saved?.thresholds.entries.keys.contains { $0.hasPrefix("codex.") } == true)

        await coordinator.replaceSources([FallbackProvider(primary: script), FallbackProvider(primary: codex)])
        _ = await coordinator.refresh(manual: false)
        #expect(script.calls == 2, "back at once, not 600 s later")
    }

    @Test func aRestartedScriptRunsAgainAtOnce() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: FetchPolicy(timeout: nil, minimumSpacing: 600))
        let coordinator = coordinator([FallbackProvider(primary: script)], dir: dir, clock: clock)
        _ = await coordinator.refresh(manual: false)
        await coordinator.replaceSources([FallbackProvider(primary: script)])
        _ = await coordinator.refresh(manual: false)
        #expect(script.calls == 1, "an unchanged script keeps its spacing")
        await coordinator.replaceSources([FallbackProvider(primary: script)], restarting: [kimi])
        _ = await coordinator.refresh(manual: false)
        #expect(script.calls == 2)
        #expect(await coordinator.cached().snapshots[kimi]?.maxPercent == 30, "its numbers stay until the new run")
    }

    @Test func savedStateOfModelsNoLongerConfiguredIsDroppedAtLaunch() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let store = StateStore(fileURL: dir.file("state.json"))
        let entry = ThresholdState.Entry(lastNotified: 30, resetsAt: nil, lastUsed: 30)
        try store.save(PersistedState(
            snapshots: [kimi: snapshot(30, at: clock.now)],
            thresholds: ThresholdState(entries: ["kimi.session": entry, "codex.week": entry]),
            backoff: ["script.kimi": BackoffState(lastAttempt: clock.now)]
        ))
        let codex = StubProvider(.codexAppServer, .success(.make(.codex, windows: [.make(used: 50)], fetchedAt: clock.now)))
        let coordinator = coordinator([FallbackProvider(primary: codex)], dir: dir, clock: clock)
        #expect(await coordinator.cached().snapshots[kimi] == nil)
        _ = await coordinator.refresh(manual: false)
        let saved = store.load()
        #expect(saved?.backoff["script.kimi"] == nil)
        #expect(saved?.thresholds.entries["kimi.session"] == nil)
        #expect(saved?.thresholds.entries["codex.week"] != nil)
    }

    @Test func aRejectedFileAtLaunchKeepsTheScriptsSavedState() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let store = StateStore(fileURL: dir.file("state.json"))
        let entry = ThresholdState.Entry(lastNotified: 30, resetsAt: nil, lastUsed: 30)
        try store.save(PersistedState(
            snapshots: [kimi: snapshot(30, at: clock.now)],
            thresholds: ThresholdState(entries: ["kimi.session": entry]),
            backoff: ["script.kimi": BackoffState(lastAttempt: clock.now)]
        ))
        let codex = StubProvider(.codexAppServer, .success(.make(.codex, windows: [.make(used: 50)], fetchedAt: clock.now)))
        // A typo in providers.json at launch runs the built-ins for now; fixing it brings Kimi back as it was.
        let coordinator = RefreshCoordinator(
            sources: [FallbackProvider(primary: codex)], store: store, pruningSavedState: false, now: { clock.now }
        )
        _ = await coordinator.refresh(manual: false)
        let saved = store.load()
        #expect(saved?.snapshots[kimi] != nil)
        #expect(saved?.backoff["script.kimi"] != nil)
        #expect(saved?.thresholds.entries["kimi.session"] != nil)
    }

    @Test func aRefreshThatOutlivesItsModelDoesNotBringItBack() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let script = ScriptStub(kimi, .success(snapshot(30, at: clock.now)), policy: .standard)
        script.delay = 0.3
        let codex = StubProvider(.codexAppServer, .success(.make(.codex, windows: [.make(used: 50)], fetchedAt: clock.now)))
        let coordinator = coordinator([FallbackProvider(primary: script), FallbackProvider(primary: codex)], dir: dir, clock: clock)
        let running = Task { await coordinator.refresh(manual: false) }
        try await Task.sleep(for: .milliseconds(100))
        await coordinator.replaceSources([FallbackProvider(primary: codex)])
        let result = await running.value
        #expect(result.snapshots[kimi] == nil)
        #expect(result.issues[kimi] == nil)
        #expect(StateStore(fileURL: dir.file("state.json")).load()?.backoff["script.kimi"] == nil)
    }

    @Test func backoffKeysSeparateScripts() {
        let script = ScriptStub(kimi, .failure(.timeout), policy: .standard)
        #expect(RefreshCoordinator.backoffKey(FallbackProvider(primary: script)) == "script.kimi")
        let claude = StubProvider(.claudeStatusLine, .failure(.timeout), provider: .claude)
        #expect(RefreshCoordinator.backoffKey(FallbackProvider(primary: claude)) == "claudeStatusLine")
    }

    @Test func schedulerHonorsACustomSpacing() {
        let scheduler = PollScheduler()
        let state = scheduler.recordSuccess(BackoffState(), now: TestClock.now)
        #expect(!scheduler.canAttempt(state, now: TestClock.now.addingTimeInterval(599), manual: false, spacing: 600))
        #expect(scheduler.canAttempt(state, now: TestClock.now.addingTimeInterval(600), manual: false, spacing: 600))
        #expect(scheduler.canAttempt(state, now: TestClock.now.addingTimeInterval(60), manual: true, spacing: 600), "manual keeps its 60 s")
    }
}
