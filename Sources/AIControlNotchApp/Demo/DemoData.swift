import Foundation
import AIControlNotchCore

/// The mockup's numbers: Claude 38% session and 58% week, Codex 91% week,
/// plus "Orbit", a made-up model added by script, for the multi-model states.
enum DemoData {
    static let minute: TimeInterval = 60
    static let orbit = ProviderID("orbit")!

    /// Claude and Codex plus Orbit, as `providers.json` would declare it.
    static var threeModels: ProviderCatalog {
        ProviderCatalog(config: ProvidersConfig(
            pinned: [.claude, .codex],
            disabled: [],
            scripts: [ScriptProviderConfig(
                id: orbit, name: "Orbit", accentHex: "#8B9CF7", command: ["/usr/local/bin/orbit-usage"], interval: 300, timeout: 15
            )]
        ))
    }

    /// Friday, 2 Oct 2026, 15:42 local time (the mockup's clock).
    static var mockupNow: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 15, minute: 42)) ?? Date()
    }

    static func snapshots(now: Date) -> [ProviderID: ProviderSnapshot] {
        let fetched = now.addingTimeInterval(-minute)
        return [
            .claude: ProviderSnapshot(provider: .claude, windows: [
                UsageWindow(kind: .session, usedPercent: 38, durationMinutes: 300, resetsAt: sessionReset(now)),
                UsageWindow(kind: .week, usedPercent: 58, durationMinutes: 10_080, resetsAt: now.addingTimeInterval(3_918 * minute)),
            ], planLabel: "Max", fetchedAt: fetched, source: .demo),
            .codex: ProviderSnapshot(provider: .codex, windows: [
                UsageWindow(kind: .week, usedPercent: 91, durationMinutes: 10_080, resetsAt: codexReset(now)),
            ], planLabel: "Pro Lite", fetchedAt: fetched, source: .demo),
        ]
    }

    /// What the Orbit script would print: a labelled daily window (in the user's language,
    /// as a script would write it) and a month.
    static func orbitSnapshot(now: Date, language: AppLanguage) -> ProviderSnapshot {
        let daily = language == .portuguese ? "Diário" : "Daily"
        return ProviderSnapshot(provider: orbit, windows: [
            UsageWindow(kind: .days(1), usedPercent: 22, durationMinutes: 1_440, resetsAt: now.addingTimeInterval(498 * minute), label: daily),
            UsageWindow(kind: .days(30), usedPercent: 64, durationMinutes: 43_200, resetsAt: now.addingTimeInterval(17_538 * minute)),
        ], planLabel: "Team", fetchedAt: now.addingTimeInterval(-3 * minute), source: .script)
    }

    static func alerts(now: Date) -> [ThresholdAlert] {
        [
            ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: sessionReset(now)),
            ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: codexReset(now)),
            ThresholdAlert(provider: .codex, kind: .week, bucket: 100, resetsAt: codexReset(now)),
        ]
    }

    /// Claude's 5h session at its limit, for the film's last alert.
    static func sessionLimit(now: Date) -> ThresholdAlert {
        ThresholdAlert(provider: .claude, kind: .session, bucket: 100, resetsAt: sessionReset(now))
    }

    private static func sessionReset(_ now: Date) -> Date { now.addingTimeInterval(134 * minute) }
    private static func codexReset(_ now: Date) -> Date { now.addingTimeInterval(4_496 * minute) }
}
