import AIControlNotchCore
import Foundation

/// What a `--render-frames` scene shows and when things happen, on the mockup's clock.
struct FilmScript {
    /// Seconds at rest before anything happens, so each scene starts settled.
    static let lead: TimeInterval = 0.5
    static let restHold: TimeInterval = 2
    static let openHold: TimeInterval = 3
    static let modelsHold: TimeInterval = 3.5
    static let tail: TimeInterval = 1

    let catalog: ProviderCatalog
    let snapshots: [ProviderID: ProviderSnapshot]
    let events: [SceneEvent]
    let tail: TimeInterval

    static func make(_ scene: FilmScene, now: Date, language: AppLanguage) -> FilmScript {
        let demo = DemoData.snapshots(now: now)
        switch scene {
        case .rest:
            return FilmScript(catalog: .builtIn, snapshots: demo, events: [], tail: restHold)
        case .open:
            return FilmScript(catalog: .builtIn, snapshots: demo, events: hover(for: openHold), tail: tail)
        case .alerts:
            return FilmScript(catalog: .builtIn, snapshots: demo, events: alerts(now: now), tail: tail)
        case .models:
            var snapshots = demo
            snapshots[DemoData.orbit] = DemoData.orbitSnapshot(now: now, language: language)
            return FilmScript(catalog: DemoData.threeModels, snapshots: snapshots, events: hover(for: modelsHold), tail: tail)
        }
    }

    /// The pointer enters the notch, stays `hold` seconds, leaves.
    private static func hover(for hold: TimeInterval) -> [SceneEvent] {
        [SceneEvent(time: lead, action: .hover(true)), SceneEvent(time: lead + hold, action: .hover(false))]
    }

    /// Claude 40% and Codex 90% from one refresh; Claude's session limit from the next
    /// (queued together, the 100% step would replace the 40% one, as in the app).
    private static func alerts(now: Date) -> [SceneEvent] {
        let demo = DemoData.alerts(now: now)
        return [
            SceneEvent(time: lead, action: .enqueue([demo[0], demo[1]])),
            SceneEvent(time: lead * 2, action: .enqueue([DemoData.sessionLimit(now: now)])),
        ]
    }
}
