import Foundation

/// Something that happens to the notch during a scripted scene.
public enum SceneAction: Equatable, Sendable {
    case hover(Bool)
    case enqueue([ThresholdAlert])
}

public struct SceneEvent: Equatable, Sendable {
    public let time: TimeInterval
    public let action: SceneAction

    public init(time: TimeInterval, action: SceneAction) {
        self.time = time
        self.action = action
    }
}

/// The state machine as it stood from `time` (seconds into the scene) on.
public struct ModeChange: Equatable, Sendable {
    public let time: TimeInterval
    public let machine: NotchMachine

    public init(time: TimeInterval, machine: NotchMachine) {
        self.time = time
        self.machine = machine
    }
}

/// Plays scripted events through the real `NotchMachine`, firing alert deadlines at
/// their exact time, so a rendered scene follows the app's own rules and durations.
public enum SceneRunner {
    /// Stops a scene that would never settle (an alert held by hover forever).
    public static let limit: TimeInterval = 600

    public static func run(_ events: [SceneEvent], start: Date) -> [ModeChange] {
        var machine = NotchMachine()
        var changes = [ModeChange(time: 0, machine: machine)]
        var pending = events.sorted { $0.time < $1.time }
        while let (time, next) = advance(machine, pending: &pending, start: start), time <= limit {
            if next.mode != machine.mode { changes.append(ModeChange(time: time, machine: next)) }
            machine = next
        }
        return changes
    }

    /// When the scene is over: the last change or event, plus `tail` seconds of rest.
    public static func end(of changes: [ModeChange], events: [SceneEvent], tail: TimeInterval) -> TimeInterval {
        let last = (changes.map(\.time) + events.map(\.time)).max() ?? 0
        return last + tail
    }

    /// The next thing to happen: the alert deadline or the next event, whichever comes first.
    private static func advance(
        _ machine: NotchMachine, pending: inout [SceneEvent], start: Date
    ) -> (TimeInterval, NotchMachine)? {
        let deadline = machine.nextDeadline.map { $0.timeIntervalSince(start) }
        if let deadline, pending.first.map({ deadline <= $0.time }) ?? true {
            return (deadline, machine.tick(now: start.addingTimeInterval(deadline)))
        }
        guard !pending.isEmpty else { return nil }
        let event = pending.removeFirst()
        let now = start.addingTimeInterval(event.time)
        switch event.action {
        case let .hover(inside): return (event.time, machine.hover(inside, now: now))
        case let .enqueue(alerts): return (event.time, machine.enqueue(alerts, now: now))
        }
    }
}
