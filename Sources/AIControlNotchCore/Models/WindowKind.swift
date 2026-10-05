import Foundation

/// A usage window, identified by its duration rather than its position in a payload.
public enum WindowKind: Codable, Hashable, Sendable, Comparable {
    case session
    case week
    case days(Int)
    /// Shorter than a day and not the 5h session, such as a 1h or 12h window.
    case minutes(Int)

    /// Stable identifier used in persisted state.
    public var key: String {
        switch self {
        case .session: "session"
        case .week: "week"
        case let .days(count): "days\(count)"
        case let .minutes(count): "minutes\(count)"
        }
    }

    /// Session, then week, then shorter windows, then longer ones, each by duration.
    private var sortRank: (group: Int, length: Int) {
        switch self {
        case .session: (0, 0)
        case .week: (1, 0)
        case let .minutes(count): (2, count)
        case let .days(count): (3, count)
        }
    }

    public static func < (lhs: WindowKind, rhs: WindowKind) -> Bool {
        lhs.sortRank < rhs.sortRank
    }
}
