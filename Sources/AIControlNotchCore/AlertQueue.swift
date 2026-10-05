import Foundation

/// FIFO of pending alerts. One alert per window: a newer step replaces a queued one.
public struct AlertQueue: Equatable, Sendable {
    static let normalDuration: TimeInterval = 4.5
    static let limitDuration: TimeInterval = 8

    private var items: [ThresholdAlert] = []

    public init() {}

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }

    public mutating func enqueue(_ alerts: [ThresholdAlert]) {
        for alert in alerts {
            if let index = items.firstIndex(where: { $0.key == alert.key }) {
                items[index] = alert
            } else {
                items.append(alert)
            }
        }
    }

    public mutating func dequeue() -> ThresholdAlert? {
        items.isEmpty ? nil : items.removeFirst()
    }

    public static func displayDuration(for alert: ThresholdAlert) -> TimeInterval {
        alert.isLimit ? limitDuration : normalDuration
    }
}
