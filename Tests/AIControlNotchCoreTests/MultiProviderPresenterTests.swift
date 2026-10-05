import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct MultiProviderPresenterTests {
    let now = TestClock.now
    let kimi = ProviderID("kimi")!

    private func presenter(pinned: [ProviderID], disabled: [ProviderID] = []) -> NotchPresenter {
        let config = ProvidersConfig(
            pinned: pinned,
            disabled: disabled,
            scripts: [ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: "#5B8CFF", command: ["/bin/kimi"], interval: 300, timeout: 15)]
        )
        return NotchPresenter(copy: Copy(language: .english, calendar: TestClock.calendar, catalog: ProviderCatalog(config: config)))
    }

    private var snapshots: [ProviderID: ProviderSnapshot] {
        [
            .claude: .make(.claude, windows: [.make(.session, used: 38, minutes: 300)], fetchedAt: now, source: .claudeStatusLine),
            kimi: .make(kimi, windows: [UsageWindow(kind: .minutes(180), usedPercent: 12, durationMinutes: 180, resetsAt: nil, label: "Opus")],
                        fetchedAt: now, source: .script),
        ]
    }

    @Test func sectionsFollowTheCatalog() {
        let open = presenter(pinned: [kimi, .claude]).open(snapshots, issues: [:], now: now)
        #expect(open.sections.map(\.provider) == [kimi, .claude, .codex])
        #expect(open.sections[0].rows.first?.label == "Opus")
        #expect(open.sections[2].message == "Fetching limits…")
    }

    @Test func disabledModelsAreNotListed() {
        let open = presenter(pinned: [.claude], disabled: [.codex]).open(snapshots, issues: [:], now: now)
        #expect(open.sections.map(\.provider) == [.claude, kimi])
    }

    @Test func aFailingScriptShowsItsNumbersAndTheReason() {
        let open = presenter(pinned: [.claude, .codex]).open(snapshots, issues: [kimi: .scriptFailed(.exit(1))], now: now)
        let section = open.sections.first { $0.provider == kimi }
        #expect(section?.rows.count == 1)
        #expect(section?.message == "Kimi script failed: exit code 1.")
        #expect(section?.lineCount == 2)
    }

    @Test func restSidesArePinnedModels() {
        let sides = presenter(pinned: [kimi, .claude]).restSides(snapshots, now: now)
        #expect(sides.map(\.provider) == [kimi, .claude])
        #expect(sides.map(\.percentText) == ["12", "38"])
    }

    @Test func aSinglePinnedModelHasOneSide() {
        let sides = presenter(pinned: [.claude]).restSides(snapshots, now: now)
        #expect(sides.map(\.provider) == [.claude])
    }

    @Test func alertTitlesUseTheScriptName() {
        let alert = ThresholdAlert(provider: kimi, kind: .minutes(180), bucket: 90, resetsAt: nil)
        let content = presenter(pinned: [.claude, .codex]).alert(alert, now: now)
        #expect(content.title == "Kimi reached 90% of the 3h window")
        #expect(content.provider == kimi)
    }

    @Test func catalogIsExposedForTheViews() {
        #expect(presenter(pinned: [kimi]).catalog.descriptor(kimi).accentHex == "#5B8CFF")
    }

    @Test func updatedIgnoresModelsThatAreNotShown() {
        let old = ProviderSnapshot.make(ProviderID("gone")!, windows: [.make(used: 1)], fetchedAt: now.addingTimeInterval(-3 * 86_400))
        let shown = presenter(pinned: [.claude]).open(snapshots, issues: [:], now: now)
        let withOld = presenter(pinned: [.claude]).open(snapshots.merging([ProviderID("gone")!: old]) { $1 }, issues: [:], now: now)
        #expect(withOld.updated == shown.updated)
        #expect(withOld.updatedIsStale == false)
    }
}

/// Review M8: six models with four windows each would not fit on the screen.
@Suite struct OpenPanelBudgetTests {
    let now = TestClock.now
    let scripts = ["a", "b", "c", "d"].map { ProviderID($0)! }
    /// Minutes and use of each script window, in the order the script prints them.
    let windows: [(minutes: Int, used: Double)] = [(60, 5), (300, 60), (1_440, 40), (10_080, 20)]

    private var presenter: NotchPresenter {
        let configs = scripts.map {
            ScriptProviderConfig(id: $0, name: $0.rawValue.uppercased(), accentHex: nil, command: ["/bin/x"], interval: 300, timeout: 15)
        }
        let catalog = ProviderCatalog(config: ProvidersConfig(pinned: [.claude, .codex], disabled: [], scripts: configs))
        return NotchPresenter(copy: Copy(language: .english, calendar: TestClock.calendar, catalog: catalog))
    }

    private var snapshots: [ProviderID: ProviderSnapshot] {
        let two = [UsageWindow.make(.session, used: 10, minutes: 300), .make(.week, used: 20)]
        let builtIns: [ProviderID: ProviderSnapshot] = [
            .claude: .make(.claude, windows: two, fetchedAt: now, source: .claudeStatusLine),
            .codex: .make(.codex, windows: two, fetchedAt: now),
        ]
        return scripts.reduce(into: builtIns) { result, id in
            let list = windows.map {
                UsageWindow(kind: WindowClassifier.kind(minutes: $0.minutes), usedPercent: $0.used, durationMinutes: $0.minutes, resetsAt: nil)
            }
            result[id] = .make(id, windows: list, fetchedAt: now, source: .script)
        }
    }

    @Test func keepsTheMostUsedLimitsOfTheLargestSections() {
        let open = presenter.open(snapshots, issues: [:], now: now)
        #expect(open.rowCount == NotchPresenter.maxOpenLines)
        #expect(open.sections.map(\.rows.count) == [2, 2, 2, 2, 2, 2])
        for section in open.sections.dropFirst(2) {
            #expect(section.rows.map(\.percent) == [60, 40], "\(section.provider.rawValue) keeps its two busiest, in order")
        }
    }

    @Test func onlyTheFirstKeptRowNamesTheModel() {
        let open = presenter.open(snapshots, issues: [:], now: now)
        for section in open.sections {
            #expect(section.rows.map(\.showsProvider) == [true] + Array(repeating: false, count: section.rows.count - 1))
        }
    }

    @Test func everyModelKeepsAtLeastOneRow() {
        let issues = Dictionary(uniqueKeysWithValues: (scripts + [.claude, .codex]).map { ($0, ProviderIssue.scriptFailed(.exit(1))) })
        let open = presenter.open(snapshots, issues: issues, now: now)
        #expect(open.rowCount == NotchPresenter.maxOpenLines)
        #expect(open.sections.allSatisfy { $0.rows.count == 1 && $0.message != nil })
    }

    @Test func smallPanelsAreUntouched() {
        let few = snapshots.filter { [.claude, .codex].contains($0.key) }
        let open = presenter.open(few, issues: [:], now: now)
        #expect(open.sections.prefix(2).map(\.rows.count) == [2, 2])
    }
}
