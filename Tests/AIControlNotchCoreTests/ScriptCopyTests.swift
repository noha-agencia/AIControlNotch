import Foundation
import Testing
@testable import AIControlNotchCore

/// Texts for models added by script, in both languages.
@Suite struct ScriptCopyTests {
    static let kimi = ProviderID("kimi")!

    static var catalog: ProviderCatalog {
        ProviderCatalog(config: ProvidersConfig(
            pinned: [.claude, .codex],
            disabled: [],
            scripts: [ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: ["/bin/kimi"], interval: 300, timeout: 15)]
        ))
    }

    let english = Copy(language: .english, calendar: TestClock.calendar, catalog: Self.catalog)
    let portuguese = Copy(language: .portuguese, calendar: TestClock.calendar, catalog: Self.catalog)

    @Test(arguments: [
        (ScriptFailure.launch, "Kimi script failed: could not start (check the path and chmod +x).", "Script do Kimi falhou: não iniciou (confira o caminho e o chmod +x)."),
        (.exit(2), "Kimi script failed: exit code 2.", "Script do Kimi falhou: código de saída 2."),
        (.timedOut(seconds: 15), "Kimi script failed: took longer than 15 s.", "Script do Kimi falhou: passou de 15 s."),
        (.tooMuchOutput(kilobytes: 64), "Kimi script failed: printed more than 64 KB.", "Script do Kimi falhou: imprimiu mais de 64 KB."),
        (.unsafeFile, "Kimi script failed: other users can change its files (run chmod go-w on them).", "Script do Kimi falhou: outros usuários podem alterar os arquivos dele (rode chmod go-w neles)."),
        (.invalidOutput("windows[0].usedPercent"), "Kimi script failed: invalid output (windows[0].usedPercent).", "Script do Kimi falhou: saída inválida (windows[0].usedPercent)."),
    ])
    func scriptFailures(failure: ScriptFailure, inEnglish: String, inPortuguese: String) {
        #expect(english.issueMessage(.scriptFailed(failure), provider: Self.kimi) == inEnglish)
        #expect(portuguese.issueMessage(.scriptFailed(failure), provider: Self.kimi) == inPortuguese)
    }

    @Test func noDataForAScript() {
        #expect(english.issueMessage(.noData, provider: Self.kimi) == "No data from Kimi yet.")
        #expect(portuguese.issueMessage(.noData, provider: Self.kimi) == "Sem dados do Kimi ainda.")
    }

    @Test func alertsUseTheConfiguredName() {
        let alert = ThresholdAlert(provider: Self.kimi, kind: .session, bucket: 50, resetsAt: nil)
        #expect(english.alertTitle(alert) == "Kimi reached 50% of the 5h session")
        #expect(portuguese.alertTitle(alert) == "Kimi chegou a 50% da sessão de 5h")
    }

    @Test func scriptLabelsWinOverTheDurationLabel() {
        let window = UsageWindow(kind: .minutes(180), usedPercent: 10, durationMinutes: 180, resetsAt: nil, label: "Opus 3h")
        #expect(english.windowLabel(window) == "Opus 3h")
        #expect(portuguese.windowLabel(window) == "Opus 3h")
    }

    @Test func scriptSourceName() {
        #expect(english.sourceName(.script) == "script")
        #expect(portuguese.sourceName(.script) == "script")
    }
}
