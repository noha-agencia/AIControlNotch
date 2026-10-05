import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct AppLanguageTests {
    @Test(arguments: [
        (["pt-BR"], AppLanguage.portuguese),
        (["pt-PT"], .portuguese),
        (["pt"], .portuguese),
        (["en-US"], .english),
        (["en-GB", "pt-BR"], .english),
        (["es-ES", "pt-BR"], .portuguese),
        (["fr-FR"], .english),
        ([], .english),
    ])
    func picksTheFirstSupportedLanguage(languages: [String], expected: AppLanguage) {
        #expect(AppLanguage.preferred(from: languages) == expected)
    }
}

@Suite struct EnglishCopyTests {
    let copy = Copy(language: .english, calendar: TestClock.calendar)
    let formatter = ResetFormatter(calendar: TestClock.calendar, language: .english)
    let now = TestClock.now

    @Test func alertTitles() {
        #expect(copy.alertTitle(.init(provider: .codex, kind: .week, bucket: 90, resetsAt: nil)) == "Codex reached 90% of the week")
        #expect(copy.alertTitle(.init(provider: .claude, kind: .session, bucket: 40, resetsAt: nil)) == "Claude reached 40% of the 5h session")
        #expect(copy.alertTitle(.init(provider: .codex, kind: .week, bucket: 100, resetsAt: nil)) == "Codex hit the weekly limit")
        #expect(copy.alertTitle(.init(provider: .claude, kind: .session, bucket: 100, resetsAt: nil)) == "Claude hit the 5h session limit")
        #expect(copy.alertTitle(.init(provider: .codex, kind: .days(30), bucket: 50, resetsAt: nil)) == "Codex reached 50% of the 30-day window")
        #expect(copy.alertTitle(.init(provider: .codex, kind: .minutes(180), bucket: 100, resetsAt: nil)) == "Codex hit the 3h limit")
    }

    @Test func alertSubtitles() {
        let reset = TestClock.date(2026, 10, 5, 18, 38)
        #expect(copy.alertSubtitle(.init(provider: .codex, kind: .week, bucket: 90, resetsAt: reset), now: now)
            == "10% left. Resets Mon 18:38, in 3d 2h.")
        #expect(copy.alertSubtitle(.init(provider: .codex, kind: .week, bucket: 100, resetsAt: reset), now: now)
            == "Resets Mon 18:38, in 3d 2h.")
        #expect(copy.alertSubtitle(.init(provider: .codex, kind: .week, bucket: 40, resetsAt: nil), now: now) == "60% left.")
        #expect(copy.alertSubtitle(.init(provider: .codex, kind: .week, bucket: 100, resetsAt: nil), now: now) == "Wait for the reset.")
    }

    @Test func updatedAgo() {
        #expect(copy.updatedAgo(now.addingTimeInterval(-20), now: now) == "updated just now")
        #expect(copy.updatedAgo(now.addingTimeInterval(-59 * 60), now: now) == "updated 59 min ago")
        #expect(copy.updatedAgo(now.addingTimeInterval(-125 * 60), now: now) == "updated 2h ago")
        #expect(copy.updatedAgo(now.addingTimeInterval(-26 * 3_600), now: now) == "updated 1 day ago")
        #expect(copy.updatedAgo(now.addingTimeInterval(-50 * 3_600), now: now) == "updated 2 days ago")
        #expect(copy.updatedAgo(nil, now: now) == "no data yet")
    }

    @Test func resetLines() {
        let window = UsageWindow.make(.session, used: 38, minutes: 300, resetsAt: TestClock.date(2026, 10, 2, 17, 56))
        #expect(copy.resetLine(window, now: now) == ResetLine(relative: "resets in 2h14", absolute: "today 17:56"))
        #expect(copy.resetLine(.make(.session, used: 0, minutes: 300), now: now) == ResetLine(relative: "starts on next use", absolute: ""))
    }

    @Test func formatsRelativeAndAbsoluteTimes() {
        #expect(formatter.relative(now.addingTimeInterval(42 * 60), now: now) == "in 42 min")
        #expect(formatter.relative(now.addingTimeInterval((2 * 1_440 + 17 * 60) * 60), now: now) == "in 2d 17h")
        #expect(formatter.absolute(TestClock.date(2026, 10, 3, 9, 0), now: now) == "tomorrow 09:00")
        #expect(formatter.absolute(TestClock.date(2026, 10, 8, 7, 5), now: now) == "Thu 07:05")
        #expect(formatter.absolute(TestClock.date(2026, 10, 12, 9, 0), now: now) == "Oct 12 09:00")
    }

    @Test func labelsMessagesAndSources() {
        #expect(copy.windowLabel(.make(.session, used: 0, minutes: 300)) == "5h session")
        #expect(copy.windowLabel(.make(.week, used: 0)) == "Week")
        #expect(copy.windowLabel(.make(.days(1), used: 0, minutes: 1_440)) == "1 day")
        #expect(copy.windowLabel(.make(.days(30), used: 0, minutes: 43_200)) == "30 days")
        #expect(copy.windowLabel(.make(.minutes(90), used: 0, minutes: 90)) == "1h30")
        #expect(copy.windowLabel(.make(.minutes(45), used: 0, minutes: 45)) == "45 min")
        #expect(copy.panelTitle == "Plan limits")
        #expect(copy.loading == "Fetching limits…")
        #expect(copy.legend(.ok) == "on track")
        #expect(copy.legend(.warn) == "at the pace limit")
        #expect(copy.legend(.danger) == "runs out before reset")
        #expect(copy.issueMessage(.noData, provider: .claude) == "No data. Connect the Claude Code status line, then use Claude Code once.")
        #expect(copy.issueMessage(.noData, provider: .codex) == "No data. Open Codex once to see the limits.")
        #expect(copy.sourceName(.claudeStatusLine) == "Claude Code status line")
        #expect(copy.sourceName(.codexRollout) == "Codex logs")
    }
}

@Suite struct PortugueseLabelTests {
    let copy = Copy(language: .portuguese, calendar: TestClock.calendar)

    @Test func windowLabelsAndNouns() {
        #expect(copy.windowLabel(.make(.session, used: 0, minutes: 300)) == "Sessão 5h")
        #expect(copy.windowLabel(.make(.week, used: 0)) == "Semana")
        #expect(copy.windowLabel(.make(.days(30), used: 0, minutes: 43_200)) == "30 dias")
        #expect(copy.windowLabel(.make(.days(1), used: 0, minutes: 1_440)) == "1 dia")
        #expect(copy.windowLabel(.make(.minutes(180), used: 0, minutes: 180)) == "3h")
        #expect(copy.alertTitle(.init(provider: .codex, kind: .days(30), bucket: 50, resetsAt: nil)) == "Codex chegou a 50% da janela de 30 dias")
        #expect(copy.alertTitle(.init(provider: .codex, kind: .minutes(180), bucket: 100, resetsAt: nil)) == "Codex atingiu o limite da janela de 3h")
        #expect(copy.alertTitle(.init(provider: .claude, kind: .session, bucket: 100, resetsAt: nil)) == "Claude atingiu o limite da sessão de 5h")
    }

    @Test func panelLegendAndSources() {
        #expect(copy.panelTitle == "Limites do plano")
        #expect(copy.loading == "Buscando os limites…")
        #expect(copy.legend(.ok) == "folga")
        #expect(copy.legend(.warn) == "no limite do ritmo")
        #expect(copy.legend(.danger) == "acaba antes de renovar")
        #expect(copy.sourceName(.claudeStatusLine) == "barra de status do Claude Code")
        #expect(copy.sourceName(.codexAppServer) == "servidor do Codex")
        #expect(copy.updatedAgo(TestClock.now.addingTimeInterval(-26 * 3_600), now: TestClock.now) == "atualizado há 1 dia")
    }
}
