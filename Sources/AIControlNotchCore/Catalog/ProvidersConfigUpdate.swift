import Foundation

/// What the app does with a fresh read of `providers.json`.
public struct ProvidersConfigUpdate: Equatable, Sendable {
    public let config: ProvidersConfig
    /// Shown in the menu; the config above is then the last good one.
    public let error: ProvidersConfigError?
    /// Scripts whose settings changed: they may run again at once.
    public let restarting: Set<ProviderID>

    /// A rejected file keeps the last good settings, so a typo never takes the scripts away.
    /// At launch there is none yet and the built-in models are used.
    public static func resolve(_ loaded: ProvidersConfigLoad, previous: ProvidersConfig?) -> ProvidersConfigUpdate {
        if let error = loaded.error {
            return ProvidersConfigUpdate(config: previous ?? loaded.config, error: error, restarting: [])
        }
        let before = Dictionary((previous?.scripts ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let changed = loaded.config.scripts.filter { script in before[script.id].map { $0 != script } ?? false }
        return ProvidersConfigUpdate(config: loaded.config, error: nil, restarting: Set(changed.map(\.id)))
    }
}
