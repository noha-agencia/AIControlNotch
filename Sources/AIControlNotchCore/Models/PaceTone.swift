import Foundation

/// Pace dot: will the limit last until it renews?
public enum PaceTone: Int, Codable, Sendable, Comparable {
    /// "folga"
    case ok
    /// "no limite do ritmo"
    case warn
    /// "acaba antes de renovar"
    case danger

    public static func < (lhs: PaceTone, rhs: PaceTone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
