import Foundation

/// What the notch is showing.
public enum NotchMode: Equatable, Sendable {
    case rest
    case open
    case alert(ThresholdAlert)
}

/// Rest / open / alert rules: one alert at a time, alerts wait for
/// the open panel to close, and hovering an alert holds it until the mouse leaves.
public struct NotchMachine: Equatable, Sendable {
    public let mode: NotchMode
    public let hovering: Bool
    /// When the current alert should go away; `nil` while held or not alerting.
    public let nextDeadline: Date?
    private let queue: AlertQueue

    public init() {
        self.init(mode: .rest, hovering: false, nextDeadline: nil, queue: AlertQueue())
    }

    private init(mode: NotchMode, hovering: Bool, nextDeadline: Date?, queue: AlertQueue) {
        self.mode = mode
        self.hovering = hovering
        self.nextDeadline = nextDeadline
        self.queue = queue
    }

    public func hover(_ isHovering: Bool, now: Date) -> NotchMachine {
        switch (mode, isHovering) {
        case (.rest, true):
            return copy(mode: .open, hovering: true, deadline: nil)
        case (.open, false):
            return copy(mode: .rest, hovering: false, deadline: nil).showNext(now: now)
        case (.alert, true):
            return copy(hovering: true, deadline: nil)
        case let (.alert(alert), false):
            return copy(hovering: false, deadline: now.addingTimeInterval(AlertQueue.displayDuration(for: alert)))
        default:
            return copy(hovering: isHovering, deadline: nextDeadline)
        }
    }

    public func enqueue(_ alerts: [ThresholdAlert], now: Date) -> NotchMachine {
        guard !alerts.isEmpty else { return self }
        var updated = queue
        updated.enqueue(alerts)
        return copy(deadline: nextDeadline, queue: updated).showNext(now: now)
    }

    public func tick(now: Date) -> NotchMachine {
        guard case .alert = mode, !hovering, let deadline = nextDeadline, now >= deadline else { return self }
        return copy(mode: .rest, deadline: nil).showNext(now: now)
    }

    /// A click on the alert: open the panel if the mouse is there, otherwise move on.
    public func dismissAlert(now: Date) -> NotchMachine {
        guard case .alert = mode else { return self }
        if hovering { return copy(mode: .open, deadline: nil) }
        return copy(mode: .rest, deadline: nil).showNext(now: now)
    }

    private func showNext(now: Date) -> NotchMachine {
        guard mode == .rest, !hovering else { return self }
        var remaining = queue
        guard let next = remaining.dequeue() else { return self }
        let deadline = now.addingTimeInterval(AlertQueue.displayDuration(for: next))
        return NotchMachine(mode: .alert(next), hovering: false, nextDeadline: deadline, queue: remaining)
    }

    private func copy(
        mode: NotchMode? = nil, hovering: Bool? = nil, deadline: Date?, queue: AlertQueue? = nil
    ) -> NotchMachine {
        NotchMachine(
            mode: mode ?? self.mode,
            hovering: hovering ?? self.hovering,
            nextDeadline: deadline,
            queue: queue ?? self.queue
        )
    }
}
