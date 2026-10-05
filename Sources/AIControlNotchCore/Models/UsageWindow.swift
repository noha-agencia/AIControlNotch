import Foundation

/// One plan limit: how much of it is used and when it renews.
public struct UsageWindow: Codable, Equatable, Sendable {
    public let kind: WindowKind
    /// Percent of the limit already used, 0...100 (providers may report more).
    public let usedPercent: Double
    public let durationMinutes: Int
    /// `nil` when the window has not started yet (for example no active Claude session).
    public let resetsAt: Date?
    /// A script's own name for the window ("5h", "Opus"); built-in sources leave it `nil`.
    public let label: String?

    public init(kind: WindowKind, usedPercent: Double, durationMinutes: Int, resetsAt: Date?, label: String? = nil) {
        self.kind = kind
        self.usedPercent = usedPercent
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
        self.label = label
    }

    /// Whole percent clamped to 0...100, as shown in the notch.
    public var displayPercent: Int {
        Int(min(100, max(0, usedPercent)).rounded())
    }

    /// A window whose reset time has passed has renewed: show it as unused.
    public func normalized(now: Date) -> UsageWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        return UsageWindow(kind: kind, usedPercent: 0, durationMinutes: durationMinutes, resetsAt: nil, label: label)
    }
}
