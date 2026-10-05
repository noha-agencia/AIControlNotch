import Foundation

/// Where a snapshot came from. Shown in the menu and logs; alerts treat all sources the same.
public enum DataSource: String, Codable, Sendable {
    case claudeStatusLine
    case codexAppServer
    case codexRollout
    /// A user-configured program.
    case script
    case demo

    /// Local copies of what the AI last reported, which can replay an older number.
    public var replaysOlderReadings: Bool {
        self == .claudeStatusLine || self == .codexRollout
    }
}

/// Everything known about one AI's limits at a point in time.
public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: ProviderID
    public let windows: [UsageWindow]
    public let planLabel: String?
    /// When the data was produced (not when the app read it), used for staleness.
    public let fetchedAt: Date
    public let source: DataSource

    public init(provider: ProviderID, windows: [UsageWindow], planLabel: String?, fetchedAt: Date, source: DataSource) {
        self.provider = provider
        self.windows = windows
        self.planLabel = planLabel
        self.fetchedAt = fetchedAt
        self.source = source
    }

    /// Windows with renewed ones reset to zero, ordered session → week → others.
    public func normalized(now: Date) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            windows: windows.map { $0.normalized(now: now) }.sorted { $0.kind < $1.kind },
            planLabel: planLabel,
            fetchedAt: fetchedAt,
            source: source
        )
    }

    /// Highest display percent across windows, shown in the resting notch.
    public var maxPercent: Int? {
        windows.map(\.displayPercent).max()
    }
}
