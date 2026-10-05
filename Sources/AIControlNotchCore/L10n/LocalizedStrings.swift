import Foundation

/// Every phrase the notch shows, per language. Whole phrases live here (not fragments)
/// so each language keeps its own grammar.
public protocol LocalizedStrings: Sendable {
    // Open panel
    var panelTitle: String { get }
    var loading: String { get }
    func legend(_ tone: PaceTone) -> String
    func windowLabel(_ kind: WindowKind) -> String

    // Alerts
    func reached(_ name: String, percent: Int, of kind: WindowKind) -> String
    func hitLimit(_ name: String, of kind: WindowKind) -> String
    func remaining(_ percent: Int) -> String
    var waitForReset: String { get }
    func resets(at absolute: String, in relative: String) -> String

    // Freshness
    var noDataYet: String { get }
    var updatedNow: String { get }
    func updated(minutesAgo: Int) -> String
    func updated(hoursAgo: Int) -> String
    func updated(daysAgo: Int) -> String

    // Reset cell and formatter
    func resetsIn(_ relative: String) -> String
    var startsOnNextUse: String { get }
    /// "em 2h14" / "in 2h14" from the language-neutral "2h14".
    func within(_ duration: String) -> String
    func today(_ time: String) -> String
    func tomorrow(_ time: String) -> String
    /// Short weekday names, Sunday first.
    var weekdays: [String] { get }
    func shortDate(day: Int, month: Int) -> String

    // Problems and sources
    func noData(_ provider: ProviderDescriptor) -> String
    func scriptFailed(_ name: String, reason: String) -> String
    func scriptReason(_ failure: ScriptFailure) -> String
    func source(_ source: DataSource) -> String
}

/// Duration text shared by both languages: "45 min", "3h", "1h30".
enum DurationText {
    static let minutesPerHour = 60

    static func minutes(_ minutes: Int) -> String {
        if minutes < minutesPerHour { return "\(minutes) min" }
        let hours = minutes / minutesPerHour
        let rest = minutes % minutesPerHour
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest < 10 ? "0" : "")\(rest)"
    }
}
