import Foundation

/// Reads every AI, applies backoff and spacing, merges with the cache, raises
/// 10% alerts and persists the result. One instance lives for the app's lifetime.
public actor RefreshCoordinator {
    private enum Plan: Sendable {
        case skip
        case fetch(skipPrimary: Bool)
    }

    /// Covers both legs: the slowest primary (a Codex app-server read), then the local fallback.
    public static let defaultSourceTimeout: TimeInterval = 45

    private var sources: [FallbackProvider]
    private let store: StateStore
    private let scheduler: PollScheduler
    private let tracker: ThresholdTracker
    private let log: LogSink
    private let sourceTimeout: TimeInterval
    private let now: @Sendable () -> Date
    private var state: PersistedState
    private var issues: [ProviderID: ProviderIssue] = [:]
    private var inFlight: Task<RefreshResult, Never>?

    /// `pruningSavedState: false` keeps the saved state of models not in `sources`, for a
    /// launch with a rejected `providers.json`: once it is fixed, its scripts come back as
    /// they were. The next `replaceSources` prunes.
    public init(
        sources: [FallbackProvider],
        store: StateStore,
        pruningSavedState: Bool = true,
        scheduler: PollScheduler = PollScheduler(),
        tracker: ThresholdTracker = ThresholdTracker(),
        log: LogSink = NullLog(),
        sourceTimeout: TimeInterval = RefreshCoordinator.defaultSourceTimeout,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sources = sources
        self.store = store
        self.scheduler = scheduler
        self.tracker = tracker
        self.log = log
        self.sourceTimeout = sourceTimeout
        self.now = now
        let saved = store.load() ?? PersistedState()
        self.state = pruningSavedState ? Self.pruned(saved, to: sources) : saved
    }

    /// Swaps the models read (after `providers.json` changes). Models that left take their
    /// numbers, alert steps, spacing and problems with them, so coming back starts clean.
    /// `restarting` models (a changed script) keep their numbers but may run at once.
    public func replaceSources(_ newSources: [FallbackProvider], restarting: Set<ProviderID> = []) {
        sources = newSources
        let active = Set(newSources.map(\.provider))
        issues = issues.filter { active.contains($0.key) }
        state = Self.pruned(state, to: newSources, restarting: restarting)
        persist()
    }

    /// The last known numbers, available instantly at launch.
    public func cached() -> RefreshResult {
        RefreshResult(snapshots: normalizedSnapshots(at: now()), issues: issues)
    }

    /// Callers that arrive while a refresh runs share its numbers, so spacing and
    /// backoff hold and no source is spawned twice. Its alerts go to the starter only.
    public func refresh(manual: Bool) async -> RefreshResult {
        if let inFlight {
            let shared = await inFlight.value
            return RefreshResult(snapshots: shared.snapshots, issues: shared.issues)
        }
        let task = Task { await performRefresh(manual: manual) }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private func performRefresh(manual: Bool) async -> RefreshResult {
        let started = now()
        let plans = sources.map { (source: $0, plan: plan(for: $0, manual: manual, at: started)) }
        let steps = await fetchAll(plans, at: started)
        apply(steps)

        let finished = now()
        let snapshots = normalizedSnapshots(at: finished)
        let (thresholds, alerts) = evaluate(snapshots)
        state = PersistedState(snapshots: state.snapshots, thresholds: thresholds, backoff: state.backoff)
        persist()
        return RefreshResult(snapshots: snapshots, alerts: alerts, issues: issues)
    }

    // MARK: - Planning and fetching

    private func plan(for source: FallbackProvider, manual: Bool, at date: Date) -> Plan {
        let backoff = state.backoff[Self.backoffKey(source)] ?? BackoffState()
        if let nextAllowed = backoff.nextAllowed, nextAllowed > date {
            return source.fallback == nil ? .skip : .fetch(skipPrimary: true)
        }
        let spacing = source.policy.minimumSpacing
        return scheduler.canAttempt(backoff, now: date, manual: manual, spacing: spacing) ? .fetch(skipPrimary: false) : .skip
    }

    private func fetchAll(_ plans: [(source: FallbackProvider, plan: Plan)], at date: Date) async -> [ProviderStep] {
        let previous = state
        let (scheduler, log, timeout) = (self.scheduler, self.log, self.sourceTimeout)
        return await withTaskGroup(of: ProviderStep?.self) { group in
            for (source, plan) in plans {
                guard case let .fetch(skipPrimary) = plan else { continue }
                group.addTask {
                    await Self.fetch(
                        source, skipPrimary: skipPrimary, timeout: timeout,
                        previous: previous, at: date, scheduler: scheduler, log: log
                    )
                }
            }
            var steps: [ProviderStep] = []
            for await step in group {
                if let step { steps.append(step) }
            }
            return steps
        }
    }

    private static func fetch(
        _ source: FallbackProvider,
        skipPrimary: Bool,
        timeout: TimeInterval,
        previous: PersistedState,
        at date: Date,
        scheduler: PollScheduler,
        log: LogSink
    ) async -> ProviderStep {
        let clock = ContinuousClock()
        let started = clock.now
        let deadline = max(timeout, source.policy.timeout ?? 0)
        let outcome = await (try? withDeadline(deadline) { await source.fetch(skipPrimary: skipPrimary) })
            ?? FallbackOutcome.timedOut(skipPrimary: skipPrimary)
        let elapsed = clock.now - started
        let key = backoffKey(source)
        let backoff = previous.backoff[key] ?? BackoffState()
        let cached = previous.snapshots[source.provider]
        let snapshot = SnapshotMerge.merge(outcome.snapshot, into: cached)
        logOutcome(outcome, source: source, skipPrimary: skipPrimary, elapsed: elapsed, log: log)
        return ProviderStep(
            provider: source.provider,
            backoffKey: key,
            backoff: skipPrimary ? backoff : nextBackoff(
                backoff, after: outcome.primaryError, at: date, scheduler: scheduler, backsOff: source.policy.backsOff
            ),
            snapshot: snapshot,
            issue: issue(for: outcome, hasData: snapshot != nil)
        )
    }

    // MARK: - Merging

    /// Steps of models removed while their fetch ran are dropped, so they cannot return.
    private func apply(_ allSteps: [ProviderStep]) {
        let active = Set(sources.map(\.provider))
        let steps = allSteps.filter { active.contains($0.provider) }
        let snapshots = steps.reduce(into: state.snapshots) { result, step in
            result[step.provider] = step.snapshot
        }
        let backoff = steps.reduce(into: state.backoff) { result, step in
            result[step.backoffKey] = step.backoff
        }
        issues = steps.reduce(into: issues) { result, step in
            result[step.provider] = step.issue
        }
        state = PersistedState(snapshots: snapshots, thresholds: state.thresholds, backoff: backoff)
    }

    private func evaluate(_ snapshots: [ProviderID: ProviderSnapshot]) -> (ThresholdState, [ThresholdAlert]) {
        sources.compactMap { snapshots[$0.provider] }.reduce((state.thresholds, [ThresholdAlert]())) { partial, snapshot in
            let (thresholds, alerts) = tracker.evaluate(snapshot, state: partial.0)
            return (thresholds, partial.1 + alerts)
        }
    }

    private func normalizedSnapshots(at date: Date) -> [ProviderID: ProviderSnapshot] {
        state.snapshots.mapValues { $0.normalized(now: date) }
    }

    private func persist() {
        do {
            try store.save(state)
        } catch {
            log.log(.error, "state save failed: \(type(of: error))")
        }
    }

    // MARK: - Rules

    /// Keeps only what belongs to `sources`; `restarting` models also lose their spacing.
    static func pruned(_ state: PersistedState, to sources: [FallbackProvider], restarting: Set<ProviderID> = []) -> PersistedState {
        let active = Set(sources.map(\.provider))
        let keys = Set(sources.filter { !restarting.contains($0.provider) }.map(backoffKey))
        return PersistedState(
            snapshots: state.snapshots.filter { active.contains($0.key) },
            thresholds: ThresholdState(entries: state.thresholds.entries.filter { key, _ in
                ThresholdState.provider(ofKey: key).map(active.contains) ?? false
            }),
            backoff: state.backoff.filter { keys.contains($0.key) }
        )
    }

    /// One entry per source; scripts share `DataSource.script`, so they add their model.
    static func backoffKey(_ source: FallbackProvider) -> String {
        let kind = source.primary.source
        return kind == .script ? "script.\(source.provider.rawValue)" : kind.rawValue
    }

    static func nextBackoff(
        _ backoff: BackoffState, after error: UsageError?, at date: Date, scheduler: PollScheduler, backsOff: Bool
    ) -> BackoffState {
        guard let error else { return scheduler.recordSuccess(backoff, now: date) }
        if backsOff, error.triggersBackoff {
            return scheduler.recordFailure(backoff, now: date, retryAfter: error.retryAfter)
        }
        return BackoffState(failures: backoff.failures, nextAllowed: backoff.nextAllowed, lastAttempt: date)
    }

    static func issue(for outcome: FallbackOutcome, hasData: Bool) -> ProviderIssue? {
        switch outcome.primaryError {
        case let .script(failure)?: .scriptFailed(failure)
        default: hasData ? nil : .noData
        }
    }

    private static func logOutcome(
        _ outcome: FallbackOutcome, source: FallbackProvider, skipPrimary: Bool, elapsed: Duration, log: LogSink
    ) {
        let primary = skipPrimary ? "skipped (backoff)" : outcome.primaryError?.logDescription ?? "ok"
        let fallback = source.fallback == nil
            ? "none"
            : outcome.fallbackError?.logDescription ?? (outcome.primaryError == nil && !skipPrimary ? "unused" : "ok")
        let used = outcome.snapshot?.source.rawValue ?? "none"
        let millis = Int(elapsed / .milliseconds(1))
        let message = "refresh \(source.provider.rawValue) used=\(used) primary=\(primary) fallback=\(fallback) \(millis)ms"
        log.log(outcome.snapshot == nil || outcome.primaryError != nil ? .warning : .info, message)
    }
}
