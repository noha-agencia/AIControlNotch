import AppKit
import AIControlNotchCore
import SwiftUI

/// Owns the panel and drives the state machine from hover, clicks, alerts and time.
@MainActor
final class NotchController {
    static let clockInterval: TimeInterval = 30

    let model: NotchModel
    private let panel: NotchPanel
    private var screen: NSScreen?
    private lazy var tracker = MouseTracker(
        hitRect: { [weak self] in self?.hitRect() ?? .zero },
        onChange: { [weak self] inside in self?.hover(inside) }
    )
    private var deadlineTimer: Timer?
    private var clockTimer: Timer?
    private var clickMonitor: Any?

    var onOpen: (() -> Void)?
    var menuBuilder: (() -> NSMenu)?

    init(model: NotchModel, screen: NSScreen?) {
        self.model = model
        self.screen = screen
        panel = NotchPanel(contentRect: .zero)
        panel.contentView = NSHostingView(rootView: NotchRootView(model: model))
        reposition(on: screen)
    }

    func show(trackMouse: Bool = true) {
        panel.orderFrontRegardless()
        if trackMouse {
            tracker.start()
            installClickMonitor()
        }
        startClock()
    }

    func reposition(on newScreen: NSScreen?) {
        screen = newScreen
        let canvas = model.canvas
        let frame = newScreen?.frame ?? .zero
        panel.setFrame(
            NSRect(x: frame.midX - canvas.width / 2, y: frame.maxY - canvas.height, width: canvas.width, height: canvas.height),
            display: true
        )
    }

    /// Resizes the panel when the models or their rows need a different canvas.
    func fitCanvas() {
        guard panel.frame.size != model.canvas else { return }
        reposition(on: screen)
    }

    func hover(_ inside: Bool) {
        let wasOpen = model.mode == .open
        apply(model.machine.hover(inside, now: Date()))
        panel.ignoresMouseEvents = !inside
        if !wasOpen, model.mode == .open {
            model.setNow(Date())
            onOpen?()
        }
    }

    func enqueue(_ alerts: [ThresholdAlert]) {
        apply(model.machine.enqueue(alerts, now: Date()))
    }

    /// Saves the live panel content (no screen-recording permission needed) and logs where it sits.
    func writeSnapshot(to url: URL) throws {
        guard let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let notch = model.layout.notch
        print("\(url.lastPathComponent): panel \(panel.frame), screen \(screen?.frame ?? .zero), notch \(notch.width)x\(notch.height)")
    }

    private func apply(_ machine: NotchMachine) {
        model.apply(machine)
        scheduleDeadline()
    }

    private func scheduleDeadline() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        guard let deadline = model.machine.nextDeadline else { return }
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.apply(self.model.machine.tick(now: Date()))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        deadlineTimer = timer
    }

    private func startClock() {
        let timer = Timer(timeInterval: Self.clockInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.setNow(Date()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func hitRect() -> CGRect {
        model.layout.hitRect(for: model.shapeKind, screenFrame: screen?.frame ?? .zero)
    }

    private func installClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Local monitors run on the main thread.
            nonisolated(unsafe) let mainThreadEvent = event
            let consumed = MainActor.assumeIsolated { self?.handleClick(mainThreadEvent) ?? false }
            return consumed ? nil : event
        }
    }

    /// Returns true when the click was handled here.
    private func handleClick(_ event: NSEvent) -> Bool {
        guard event.window === panel, hitRect().contains(NSEvent.mouseLocation) else { return false }
        if event.type == .rightMouseDown, let menu = menuBuilder?(), let view = panel.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return true
        }
        guard case .alert = model.mode else { return false }
        apply(model.machine.dismissAlert(now: Date()))
        if model.mode == .open { onOpen?() }
        return true
    }
}
