import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct CopyTests {
    let copy = Copy(language: .portuguese, calendar: TestClock.calendar)
    let now = TestClock.now

    @Test func alertTitles() {
        let alert = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: nil)
        #expect(copy.alertTitle(alert) == "Codex chegou a 90% da semana")
        let session = ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: nil)
        #expect(copy.alertTitle(session) == "Claude chegou a 40% da sessão de 5h")
        let limit = ThresholdAlert(provider: .codex, kind: .week, bucket: 100, resetsAt: nil)
        #expect(copy.alertTitle(limit) == "Codex atingiu o limite da semana")
    }

    @Test func alertSubtitles() {
        let reset = TestClock.date(2026, 10, 5, 18, 38)
        let alert = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: reset)
        #expect(copy.alertSubtitle(alert, now: now) == "Restam 10%. Renova seg 18:38, em 3d 2h.")
        let limit = ThresholdAlert(provider: .codex, kind: .week, bucket: 100, resetsAt: reset)
        #expect(copy.alertSubtitle(limit, now: now) == "Renova seg 18:38, em 3d 2h.")
        let noReset = ThresholdAlert(provider: .codex, kind: .week, bucket: 40, resetsAt: nil)
        #expect(copy.alertSubtitle(noReset, now: now) == "Restam 60%.")
        let limitNoReset = ThresholdAlert(provider: .codex, kind: .week, bucket: 100, resetsAt: nil)
        #expect(copy.alertSubtitle(limitNoReset, now: now) == "Aguarde a renovação.")
    }

    @Test func updatedAgo() {
        #expect(copy.updatedAgo(now.addingTimeInterval(-20), now: now) == "atualizado agora")
        #expect(copy.updatedAgo(now.addingTimeInterval(-60), now: now) == "atualizado há 1 min")
        #expect(copy.updatedAgo(now.addingTimeInterval(-59 * 60), now: now) == "atualizado há 59 min")
        #expect(copy.updatedAgo(now.addingTimeInterval(-125 * 60), now: now) == "atualizado há 2h")
        #expect(copy.updatedAgo(now.addingTimeInterval(-50 * 3_600), now: now) == "atualizado há 2 dias")
        #expect(copy.updatedAgo(nil, now: now) == "sem dados ainda")
    }

    @Test func resetLines() {
        let window = UsageWindow.make(.session, used: 38, minutes: 300, resetsAt: TestClock.date(2026, 10, 2, 17, 56))
        let line = copy.resetLine(window, now: now)
        #expect(line.relative == "renova em 2h14")
        #expect(line.absolute == "hoje 17:56")
        let idle = copy.resetLine(.make(.session, used: 0, minutes: 300), now: now)
        #expect(idle.relative == "inicia no próximo uso")
        #expect(idle.absolute == "")
    }

    @Test func issueMessages() {
        #expect(copy.issueMessage(.noData, provider: .claude) == "Sem dados. Conecte a barra de status do Claude Code e use-o uma vez.")
        #expect(copy.issueMessage(.noData, provider: .codex) == "Sem dados. Abra o Codex uma vez para ver os limites.")
    }
}
