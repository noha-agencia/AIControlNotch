import Foundation

/// Classifies windows by duration, never by their position in a payload.
public enum WindowClassifier {
    static let sessionRange = 240...360
    static let weekRange = 9_360...10_800
    static let minutesPerDay = 1_440.0

    public static func kind(minutes: Int) -> WindowKind {
        if sessionRange.contains(minutes) { return .session }
        if weekRange.contains(minutes) { return .week }
        if Double(minutes) < minutesPerDay { return .minutes(max(1, minutes)) }
        let days = Int((Double(minutes) / minutesPerDay).rounded())
        return .days(max(1, days))
    }
}
