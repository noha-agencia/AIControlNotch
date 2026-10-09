import Foundation

/// Renewal texts: "em 2h14" / "in 2h14" and "hoje 17:56" / "today 17:56".
public struct ResetFormatter: Sendable {
    static let minutesPerHour = 60
    static let minutesPerDay = 1_440
    static let weekdayRange = 2...6
    /// A real renewal is never more than a year away; anything beyond is treated as out of range.
    static let ceilingDays = 365
    static let ceilingSeconds = TimeInterval(ceilingDays * minutesPerDay * 60)

    private let calendar: Calendar
    private let strings: any LocalizedStrings

    public init(calendar: Calendar = .current, language: AppLanguage = .current) {
        self.calendar = calendar
        self.strings = language.strings
    }

    /// "em 42 min" (< 1 h), "em 2h14" (< 24 h), "em 2d 17h".
    /// Past, NaN and invalid dates read "em 0 min"; beyond a year reads "em 365d+".
    public func relative(_ date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds > Self.ceilingSeconds {
            return strings.within("\(Self.ceilingDays)d+")
        }
        let minutes = seconds.isNaN ? 0 : Int(max(0, seconds) / 60)
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
    /// The ceiling is symmetric on purpose: dates more than 365 days away, in the future
    /// or in the past, or not finite, read "–" (the app's missing value).
    public func absolute(_ date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds.isFinite, abs(seconds) <= Self.ceilingSeconds else {
            return NotchPresenter.missingValue
        }
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
