import AppKit
import CoreGraphics
import AIControlNotchCore

/// Decides when to refresh (timer, wake, panel open, menu), keeps the models in step
/// with `providers.json`, and feeds the results into the model and the alert queue.
@MainActor
final class UsageStore {
    private let controller: NotchController
    private let paths: Paths
    private let log: LogSink
    private let configFile: ProvidersConfigFile
    private let scheduler = PollScheduler()
    private var factory: ProviderFactory?
    private var coordinator: RefreshCoordinator?
    private var configFingerprint: FileFingerprint?
    private var configReloadAsked = false
    /// The last accepted `providers.json`; a rejected edit keeps using it.
    private var activeConfig: ProvidersConfig?
    private var timer: Timer?
    private var refreshing = false
    /// A refresh asked for while one runs; `true` once any of the asks was manual.
    private var pendingManual: Bool?
    private(set) var lastRefresh: Date?
    private var wakeObserver: NSObjectProtocol?

    init(controller: NotchController, paths: Paths, log: LogSink) {
        self.controller = controller
        self.paths = paths
        self.log = log
        self.configFile = ProvidersConfigFile(url: paths.providersFile, home: paths.home)
    }

    func start() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon(manual: false) }
        }
        Task {
            let factory = ProviderFactory.make(paths: paths, log: log)
            self.factory = factory
            let update = applyConfig()
            let coordinator = RefreshCoordinator(
                sources: factory.sources(for: update.config),
                store: StateStore(fileURL: paths.stateFile, log: log),
                pruningSavedState: update.error == nil,
                log: log
            )
            self.coordinator = coordinator
            show(await coordinator.cached(), alerts: false)
            await refresh(manual: false)
        }
    }

    func panelOpened() {
        guard NotchPresenter.shouldRefreshOnOpen(lastRefresh: lastRefresh, now: Date()) else { return }
        refreshSoon(manual: false)
    }

    func refreshSoon(manual: Bool) {
        Task { await refresh(manual: manual) }
    }

    /// "Reload models": reread `providers.json` now, then refresh.
    func reloadModels() {
        configReloadAsked = true
        refreshSoon(manual: true)
    }

    /// "Configure models…": create a starting `providers.json` if needed and open it.
    func configureModels() {
        do {
            if try configFile.createTemplateIfMissing() { log.log(.info, "created providers.json") }
        } catch {
            log.log(.error, "providers.json could not be created: \(type(of: error))")
        }
        if !NSWorkspace.shared.open(configFile.url) {
            NSWorkspace.shared.activateFileViewerSelecting([configFile.url])
        }
    }

    /// One refresh at a time. Asks that arrive meanwhile (a menu click, "Reload models")
    /// are merged into one more run right after, instead of being lost.
    func refresh(manual: Bool) async {
        guard let coordinator else { return }
        guard !refreshing else {
            pendingManual = (pendingManual ?? false) || manual
            return
        }
        refreshing = true
        await reloadConfigIfChanged(coordinator)
        lastRefresh = Date()
        show(await coordinator.refresh(manual: manual), alerts: true)
        refreshing = false
        if let again = pendingManual {
            pendingManual = nil
            await refresh(manual: again)
        } else {
            scheduleNext()
        }
    }

    private func reloadConfigIfChanged(_ coordinator: RefreshCoordinator) async {
        guard let factory, configReloadAsked || configFile.fingerprint() != configFingerprint else { return }
        configReloadAsked = false
        let update = applyConfig()
        await coordinator.replaceSources(factory.sources(for: update.config), restarting: update.restarting)
    }

    /// Reads `providers.json` into the model and logs problems. A rejected file keeps the
    /// last good models (Claude and Codex at launch) and shows why in the menu.
    private func applyConfig() -> ProvidersConfigUpdate {
        configFingerprint = configFile.fingerprint()
        let update = ProvidersConfigUpdate.resolve(configFile.load(), previous: activeConfig)
        if let error = update.error { log.log(.warning, "providers.json rejected: \(error.message)") }
        activeConfig = update.config
        controller.model.setCatalog(ProviderCatalog(config: update.config), error: update.error)
        controller.fitCanvas()
        return update
    }

    private func show(_ result: RefreshResult, alerts: Bool) {
        controller.model.update(snapshots: result.snapshots, issues: result.issues)
        controller.model.setNow(Date())
        controller.fitCanvas()
        if alerts { controller.enqueue(result.alerts) }
    }

    private func scheduleNext() {
        timer?.invalidate()
        let interval = scheduler.interval(idleSeconds: Self.idleSeconds())
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon(manual: false) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Seconds since the last keyboard or mouse input, system wide.
    static func idleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
