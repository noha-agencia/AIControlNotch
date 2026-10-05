import Foundation

/// Renewal texts: "em 2h14" / "in 2h14" and "hoje 17:56" / "today 17:56".
public struct ResetFormatter: Sendable {
    static let minutesPerHour = 60
    static let minutesPerDay = 1_440
    static let weekdayRange = 2...6

    private let calendar: Calendar
    private let strings: any LocalizedStrings

    public init(calendar: Calendar = .current, language: AppLanguage = .current) {
        self.calendar = calendar
        self.strings = language.strings
    }

    /// "em 42 min" (< 1 h), "em 2h14" (< 24 h), "em 2d 17h".
    public func relative(_ date: Date, now: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        if minutes < Self.minutesPerHour {
            return strings.within("\(minutes) min")
        }
        if minutes < Self.minutesPerDay {
            let hours = minutes / Self.minutesPerHour
            let rest = minutes % Self.minutesPerHour
            return strings.within("\(hours)h\(Self.pad(rest))")
        }
        let days = minutes / Self.minutesPerDay
        let hours = (minutes % Self.minutesPerDay) / Self.minutesPerHour
        return strings.within("\(days)d \(hours)h")
    }

    /// "hoje 17:56", "amanhã 09:00", "seg 09:00" (2–6 days), "12/10 09:00" / "Oct 12 09:00" (7+ days).
    public func absolute(_ date: Date, now: Date) -> String {
        let parts = calendar.dateComponents([.month, .day, .hour, .minute, .weekday], from: date)
        let time = "\(Self.pad(parts.hour ?? 0)):\(Self.pad(parts.minute ?? 0))"
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case ...0: return strings.today(time)
        case 1: return strings.tomorrow(time)
        case Self.weekdayRange: return "\(strings.weekdays[((parts.weekday ?? 1) - 1).clamped(to: 0...6)]) \(time)"
        default: return "\(strings.shortDate(day: parts.day ?? 1, month: parts.month ?? 1)) \(time)"
        }
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
