import AppKit
import AIControlNotchCore

/// `--demo`: rest → open → Claude 40% → Codex 90% → Codex 100% on the real notch, then quits.
/// With `--snapshots <dir>` it saves what the panel shows at each step.
@MainActor
final class DemoScript {
    private let controller: NotchController
    private let snapshots: URL?

    init(controller: NotchController, snapshots: URL?) {
        self.controller = controller
        self.snapshots = snapshots
    }

    func run() {
        let now = Date()
        controller.model.update(snapshots: DemoData.snapshots(now: now), issues: [:])
        Task {
            await pause(1.5)
            snapshot("1-rest")
            await pause(0.5)
            controller.hover(true)
            await pause(1.2)
            snapshot("2-open")
            await pause(2.3)
            controller.hover(false)
            await pause(1.5)
            controller.enqueue(DemoData.alerts(now: Date()))
            // 4.5 s + 4.5 s + 8 s of alerts, then a moment at rest.
            await pause(2)
            snapshot("3-alert-claude-40")
            await pause(4.5)
            snapshot("4-alert-codex-90")
            await pause(4.5)
            snapshot("5-alert-codex-100")
            await pause(8)
            NSApp.terminate(nil)
        }
    }

    private func snapshot(_ name: String) {
        guard let snapshots else { return }
        do {
            try controller.writeSnapshot(to: snapshots.appendingPathComponent("\(name).png"))
        } catch {
            FileHandle.standardError.write(Data("snapshot \(name) failed: \(error)\n".utf8))
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
