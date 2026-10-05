import Foundation

/// Persisted alert state, one entry per provider window.
public struct ThresholdState: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let lastNotified: Int
        public let resetsAt: Date?
        public let lastUsed: Double
    }

    public let entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    static func key(_ provider: ProviderID, _ kind: WindowKind) -> String {
        "\(provider.rawValue).\(kind.key)"
    }

    /// The model a key belongs to. Ids never contain a dot, so it ends at the first one.
    static func provider(ofKey key: String) -> ProviderID? {
        ProviderID(String(key.prefix { $0 != "." }))
    }

    func setting(_ key: String, to entry: Entry) -> ThresholdState {
        var copy = entries
        copy[key] = entry
        return ThresholdState(entries: copy)
    }
}

/// One alert each time a window crosses a new 10% step.
public struct ThresholdTracker: Sendable {
    static let step = 10
    static let renewalDrop = 20.0
    static let renewalResetShift: TimeInterval = 10 * 60

    public init() {}

    static let percentRange = 0.0...100.0

    public static func bucket(for used: Double) -> Int {
        let percent = used.isNaN ? 0 : used.clamped(to: percentRange)
        return Int((percent / Double(step)).rounded(.down)) * step
    }

    public func evaluate(_ snapshot: ProviderSnapshot, state: ThresholdState) -> (ThresholdState, [ThresholdAlert]) {
        snapshot.windows.reduce((state, [ThresholdAlert]())) { acc, window in
            let key = ThresholdState.key(snapshot.provider, window.kind)
            let (entry, alert) = evaluate(window, provider: snapshot.provider, previous: acc.0.entries[key])
            return (acc.0.setting(key, to: entry), acc.1 + (alert.map { [$0] } ?? []))
        }
    }

    private func evaluate(
        _ window: UsageWindow,
        provider: ProviderID,
        previous: ThresholdState.Entry?
    ) -> (ThresholdState.Entry, ThresholdAlert?) {
        let bucket = Self.bucket(for: window.usedPercent)
        guard let previous else {
            // First sighting of this window: remember where it is, never alert.
            return (entry(window, notified: bucket), nil)
        }
        let baseline = isRenewal(previous, window) ? 0 : previous.lastNotified
        guard bucket >= Self.step, bucket > baseline else {
            return (entry(window, notified: baseline), nil)
        }
        let alert = ThresholdAlert(provider: provider, kind: window.kind, bucket: bucket, resetsAt: window.resetsAt)
        return (entry(window, notified: bucket), alert)
    }

    private func entry(_ window: UsageWindow, notified: Int) -> ThresholdState.Entry {
        ThresholdState.Entry(lastNotified: notified, resetsAt: window.resetsAt, lastUsed: window.usedPercent)
    }

    private func isRenewal(_ previous: ThresholdState.Entry, _ window: UsageWindow) -> Bool {
        if previous.lastUsed - window.usedPercent >= Self.renewalDrop { return true }
        switch (previous.resetsAt, window.resetsAt) {
        case let (old?, new?): return new.timeIntervalSince(old) > Self.renewalResetShift
        case (.some, nil): return true // the window expired
        case (nil, .some): return true // a new window started
        case (nil, nil): return false
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
