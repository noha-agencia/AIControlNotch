import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct NotchPresenterTests {
    let now = TestClock.now
    let presenter = NotchPresenter(copy: Copy(language: .portuguese, calendar: TestClock.calendar))

    var claude: ProviderSnapshot {
        .make(.claude, windows: [
            .make(.session, used: 38, minutes: 300, resetsAt: TestClock.date(2026, 10, 2, 17, 56)),
            .make(.week, used: 58, resetsAt: TestClock.date(2026, 10, 5, 9, 0)),
        ], fetchedAt: now.addingTimeInterval(-60), source: .claudeStatusLine)
    }

    var codex: ProviderSnapshot {
        .make(.codex, windows: [.make(.week, used: 91, resetsAt: TestClock.date(2026, 10, 5, 18, 38))],
              fetchedAt: now.addingTimeInterval(-90), source: .codexAppServer)
    }

    @Test func restShowsTheHighestPercentAndWorstPace() {
        let side = presenter.rest(claude, provider: .claude, now: now)
        #expect(side == RestSide(provider: .claude, percentText: "58", dot: .warn), "week at 58% with 61% elapsed is on pace")
        let codexSide = presenter.rest(codex, provider: .codex, now: now)
        #expect(codexSide.percentText == "91")
        #expect(codexSide.dot == .danger)
    }

    @Test func restWithoutDataShowsADash() {
        #expect(presenter.rest(nil, provider: .codex, now: now) == RestSide(provider: .codex, percentText: "–", dot: nil))
    }

    @Test func staleDataTurnsTheDotGrey() {
        let old = ProviderSnapshot.make(.codex, windows: codex.windows, fetchedAt: now.addingTimeInterval(-31 * 60), source: .codexRollout)
        #expect(presenter.rest(old, provider: .codex, now: now).dot == .stale)
    }

    @Test func openRowsFollowTheMockup() {
        let content = presenter.open([.claude: claude, .codex: codex], issues: [:], now: now)
        #expect(content.title == "Limites do plano")
        #expect(content.updated == "atualizado há 1 min")
        #expect(content.updatedIsStale == false)
        #expect(content.rowCount == 3)
        let session = content.sections[0].rows[0]
        #expect(session.showsProvider)
        #expect(session.label == "Sessão 5h")
        #expect(session.percent == 38)
        #expect(session.segments == [1, 1, 1, 0.8, 0, 0, 0, 0, 0, 0])
        #expect(session.isDanger == false)
        #expect(session.reset == ResetLine(relative: "renova em 2h14", absolute: "hoje 17:56"))
        #expect(content.sections[0].rows[1].showsProvider == false)
        let week = content.sections[1].rows[0]
        #expect(week.isDanger)
        #expect(week.dot == .danger)
        #expect(week.reset.absolute == "seg 18:38")
    }

    @Test func openExplainsMissingData() {
        let content = presenter.open([.claude: claude], issues: [.codex: .noData], now: now)
        #expect(content.sections.count == 2)
        #expect(content.sections[1].rows.isEmpty)
        #expect(content.sections[1].message == "Sem dados. Abra o Codex uma vez para ver os limites.")
        #expect(content.rowCount == 3)
    }

    @Test func openShowsAnIssueNextToCachedData() {
        let content = presenter.open([.claude: claude, .codex: codex], issues: [.claude: .noData], now: now)
        #expect(content.sections[0].rows.count == 2)
        #expect(content.sections[0].message == "Sem dados. Conecte a barra de status do Claude Code e use-o uma vez.")
        #expect(content.rowCount == 4)
    }

    @Test func openUsesTheOldestUpdate() {
        let old = ProviderSnapshot.make(.codex, windows: codex.windows, fetchedAt: now.addingTimeInterval(-40 * 60), source: .codexRollout)
        let content = presenter.open([.claude: claude, .codex: old], issues: [:], now: now)
        #expect(content.updated == "atualizado há 40 min")
        #expect(content.updatedIsStale)
    }

    @Test func alertContentSweepsFromThePreviousStep() {
        let alert = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: TestClock.date(2026, 10, 5, 18, 38))
        let content = presenter.alert(alert, now: now)
        #expect(content.title == "Codex chegou a 90% da semana")
        #expect(content.subtitle == "Restam 10%. Renova seg 18:38, em 3d 2h.")
        #expect(content.fromPercent == 80)
        #expect(content.percent == 90)
        #expect(content.isDanger)
        let low = presenter.alert(ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: nil), now: now)
        #expect(low.isDanger == false)
    }

    @Test func segmentsClampAtTheEnds() {
        #expect(NotchPresenter.segments(for: 0) == Array(repeating: 0, count: 10))
        #expect(NotchPresenter.segments(for: 100) == Array(repeating: 1, count: 10))
        #expect(NotchPresenter.segments(for: 5).first == 0.5)
    }

    @Test func refreshOnOpenOnlyWhenDataIsOld() {
        #expect(NotchPresenter.shouldRefreshOnOpen(lastRefresh: nil, now: now))
        #expect(!NotchPresenter.shouldRefreshOnOpen(lastRefresh: now.addingTimeInterval(-120), now: now))
        #expect(NotchPresenter.shouldRefreshOnOpen(lastRefresh: now.addingTimeInterval(-181), now: now))
    }
}
