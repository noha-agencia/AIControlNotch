import AppKit
import AIControlNotchCore

/// What the menu can ask the app to do.
struct StatusMenuActions {
    let refresh: () -> Void
    let configureModels: () -> Void
    let reloadModels: () -> Void
}

/// Right-click menu: refresh, models, launch at login, where each number comes from, quit.
@MainActor
final class StatusMenu: NSObject {
    private let model: NotchModel
    private let actions: StatusMenuActions
    private let log: LogSink
    private let strings = AppStrings()

    init(model: NotchModel, log: LogSink, actions: StatusMenuActions) {
        self.model = model
        self.log = log
        self.actions = actions
    }

    func build() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item(strings.refreshNow, action: #selector(refreshNow)))
        menu.addItem(item(strings.configureModels, action: #selector(configureModels)))
        menu.addItem(item(strings.reloadModels, action: #selector(reloadModels)))
        let launch = item(strings.openAtLogin, action: #selector(toggleLaunch))
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        launch.isEnabled = LaunchAtLogin.isAvailable
        menu.addItem(launch)
        menu.addItem(.separator())
        for line in statusLines() {
            menu.addItem(info(line))
        }
        menu.addItem(.separator())
        menu.addItem(item(strings.quit, action: #selector(quit)))
        return menu
    }

    private func statusLines() -> [String] {
        let config = model.configError.map { strings.configIgnored($0.message) }
        return (config.map { [$0] } ?? []) + model.catalog.ids.map(statusLine)
    }

    private func statusLine(_ provider: ProviderID) -> String {
        let copy = model.presenter.copy
        let name = model.catalog.descriptor(provider).displayName
        switch model.issues[provider] {
        case let .scriptFailed(failure)?:
            return copy.issueMessage(.scriptFailed(failure), provider: provider)
        case .noData?, nil:
            break
        }
        guard let snapshot = model.snapshots[provider] else { return strings.noData(name) }
        let plan = snapshot.planLabel.map { " \($0)" } ?? ""
        return "\(name)\(plan): \(copy.sourceName(snapshot.source)), \(copy.updatedAgo(snapshot.fetchedAt, now: Date()))"
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshNow() {
        actions.refresh()
    }

    @objc private func configureModels() {
        actions.configureModels()
    }

    @objc private func reloadModels() {
        actions.reloadModels()
    }

    @objc private func toggleLaunch() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            log.log(.error, "launch at login failed: \(type(of: error))")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
