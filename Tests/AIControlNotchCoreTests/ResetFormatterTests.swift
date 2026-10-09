import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ResetFormatterTests {
    let formatter = ResetFormatter(calendar: TestClock.calendar, language: .portuguese)
    let now = TestClock.now

    private func minutes(_ value: Double) -> Date { now.addingTimeInterval(value * 60) }

    @Test func relativeMinutes() {
        #expect(formatter.relative(minutes(42), now: now) == "em 42 min")
        #expect(formatter.relative(minutes(59), now: now) == "em 59 min")
        #expect(formatter.relative(minutes(0.2), now: now) == "em 0 min")
    }

    @Test func relativeHours() {
        #expect(formatter.relative(minutes(60), now: now) == "em 1h00")
        #expect(formatter.relative(minutes(134), now: now) == "em 2h14")
        #expect(formatter.relative(minutes(1_439), now: now) == "em 23h59")
    }

    @Test func relativeDays() {
        #expect(formatter.relative(minutes(1_440), now: now) == "em 1d 0h")
        #expect(formatter.relative(minutes(2 * 1_440 + 17 * 60 + 5), now: now) == "em 2d 17h")
    }

    @Test func relativePastClampsToZero() {
        #expect(formatter.relative(minutes(-30), now: now) == "em 0 min")
    }

    // MARK: Out-of-range dates must never crash the app

    private func seconds(_ value: Double) -> Date { now.addingTimeInterval(value) }

    @Test func relativeFarFutureSaturates() {
        #expect(formatter.relative(Date(timeIntervalSince1970: 1e25), now: now) == "em 365d+")
        #expect(formatter.relative(.distantFuture, now: now) == "em 365d+")
        #expect(formatter.relative(Date(timeIntervalSince1970: .infinity), now: now) == "em 365d+")
    }

    @Test func relativeCeilingIsOneYear() {
        #expect(formatter.relative(minutes(365 * 1_440), now: now) == "em 365d 0h")
        #expect(formatter.relative(minutes(365 * 1_440 + 1), now: now) == "em 365d+")
    }

    @Test func relativeInvalidOrFarPastIsZero() {
        #expect(formatter.relative(.distantPast, now: now) == "em 0 min")
        #expect(formatter.relative(Date(timeIntervalSince1970: -.infinity), now: now) == "em 0 min")
        #expect(formatter.relative(Date(timeIntervalSince1970: .nan), now: now) == "em 0 min")
        #expect(formatter.relative(Date(timeIntervalSince1970: -1e25), now: now) == "em 0 min")
    }

    @Test func relativeWithInvalidNowIsZero() {
        #expect(formatter.relative(now, now: Date(timeIntervalSince1970: .nan)) == "em 0 min")
    }

    @Test func absoluteOutOfRangeShowsMissingValue() {
        #expect(formatter.absolute(Date(timeIntervalSince1970: 1e25), now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(.distantFuture, now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(.distantPast, now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(Date(timeIntervalSince1970: .nan), now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(Date(timeIntervalSince1970: .infinity), now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(Date(timeIntervalSince1970: -.infinity), now: now) == NotchPresenter.missingValue)
    }

    @Test func absoluteCeilingIsOneYearEitherWay() {
        #expect(formatter.absolute(seconds(366 * 86_400), now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(seconds(-366 * 86_400), now: now) == NotchPresenter.missingValue)
        #expect(formatter.absolute(seconds(300 * 86_400), now: now) != NotchPresenter.missingValue)
    }

    @Test func absoluteToday() {
        #expect(formatter.absolute(TestClock.date(2026, 10, 2, 17, 56), now: now) == "hoje 17:56")
    }

    @Test func absoluteTomorrow() {
        #expect(formatter.absolute(TestClock.date(2026, 10, 3, 9, 0), now: now) == "amanhã 09:00")
    }

    @Test func absoluteWeekdayFromTwoToSixDays() {
        #expect(formatter.absolute(TestClock.date(2026, 10, 4, 9, 0), now: now) == "dom 09:00")
        #expect(formatter.absolute(TestClock.date(2026, 10, 5, 18, 38), now: now) == "seg 18:38")
        #expect(formatter.absolute(TestClock.date(2026, 10, 8, 7, 5), now: now) == "qui 07:05")
    }

    @Test func absoluteDateFromSevenDays() {
        #expect(formatter.absolute(TestClock.date(2026, 10, 9, 9, 0), now: now) == "09/10 09:00")
        #expect(formatter.absolute(TestClock.date(2026, 10, 12, 9, 0), now: now) == "12/10 09:00")
    }

    @Test func absoluteAcrossMidnightUsesCalendarDays() {
        let lateNight = TestClock.date(2026, 10, 2, 23, 50)
        #expect(formatter.absolute(TestClock.date(2026, 10, 3, 0, 10), now: lateNight) == "amanhã 00:10")
    }
}
