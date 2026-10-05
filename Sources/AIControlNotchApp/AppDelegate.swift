import AppKit
import AIControlNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo: Bool
    private let snapshots: URL?
    private var controller: NotchController?
    private var store: UsageStore?
    private var menu: StatusMenu?
    private var script: DemoScript?

    init(demo: Bool, snapshots: URL?) {
        self.demo = demo
        self.snapshots = snapshots
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !demo, Self.anotherInstanceIsRunning() {
            NSApp.terminate(nil)
            return
        }
        let screen = ScreenGeometry.notchScreen()
        let model = NotchModel(layout: NotchLayout(notch: ScreenGeometry.notchSize(on: screen)))
        let controller = NotchController(model: model, screen: screen)
        self.controller = controller
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.reposition(on: ScreenGeometry.notchScreen()) }
        }

        if demo {
            controller.show(trackMouse: false)
            let script = DemoScript(controller: controller, snapshots: snapshots)
            self.script = script
            script.run()
            return
        }

        let paths = Paths.current()
        let log = FileLogger(fileURL: paths.logFile)
        log.log(.info, "AIControlNotch started")
        let store = UsageStore(controller: controller, paths: paths, log: log)
        let menu = StatusMenu(model: model, log: log, actions: StatusMenuActions(
            refresh: { [weak store] in store?.refreshSoon(manual: true) },
            configureModels: { [weak store] in store?.configureModels() },
            reloadModels: { [weak store] in store?.reloadModels() }
        ))
        controller.onOpen = { [weak store] in store?.panelOpened() }
        controller.menuBuilder = { [weak menu] in menu?.build() ?? NSMenu() }
        self.store = store
        self.menu = menu
        controller.show()
        store.start()
    }

    /// Two copies would double-poll the APIs and race on state.json. The newer one quits,
    /// so two copies started at the same moment never both exit.
    private static func anotherInstanceIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { other in
            other.processIdentifier != current.processIdentifier && launchedFirst(other, before: current)
        }
    }

    private static func launchedFirst(_ lhs: NSRunningApplication, before rhs: NSRunningApplication) -> Bool {
        if let left = lhs.launchDate, let right = rhs.launchDate, left != right { return left < right }
        return lhs.processIdentifier < rhs.processIdentifier
    }
}
