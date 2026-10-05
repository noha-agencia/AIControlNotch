import Foundation

/// ISO 8601 parsing that tolerates any number of fractional digits
/// (Codex logs and scripts may send microseconds, which `ISO8601DateFormatter` rejects).
enum ISODate {
    static func parse(_ text: String) -> Date? {
        let pattern = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})$/
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let whole = formatter.date(from: "\(match.1)\(match.3)") else { return nil }
        let fraction = match.2.flatMap { Double("0.\($0)") } ?? 0
        return whole.addingTimeInterval(fraction)
    }
}
