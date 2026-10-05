import AppKit

/// Tells whether the pointer is over the visible shape. A global monitor sees
/// moves while the panel lets clicks through; while hovered, the panel takes
/// the events, so a light poll catches the exit.
@MainActor
final class MouseTracker {
    static let pollInterval: TimeInterval = 0.08
    static let exitMargin: CGFloat = 4

    private let hitRect: () -> CGRect
    private let onChange: (Bool) -> Void
    private var monitors: [Any] = []
    private var pollTimer: Timer?
    private(set) var isInside = false

    init(hitRect: @escaping () -> CGRect, onChange: @escaping (Bool) -> Void) {
        self.hitRect = hitRect
        self.onChange = onChange
    }

    func start() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.check() }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func check() {
        let rect = hitRect()
        let area = isInside ? rect.insetBy(dx: -Self.exitMargin, dy: -Self.exitMargin) : rect
        let inside = area.contains(NSEvent.mouseLocation)
        guard inside != isInside else { return }
        isInside = inside
        updatePolling()
        onChange(inside)
    }

    private func updatePolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        guard isInside else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
