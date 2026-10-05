import Foundation
import AIControlNotchCore

/// Wires the real data sources: Claude (the status line it hands `aicontrolnotch-tap`),
/// Codex (app-server → logs) and one source per enabled script in `providers.json`.
/// The app never reads the Claude login and makes no network requests of its own.
struct ProviderFactory {
    static let clientVersion = ClientVersion.sanitized(
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    )

    let paths: Paths
    let log: LogSink
    let runner: SystemProcessRunner

    /// Sources are rebuilt from the factory on every config change.
    static func make(paths: Paths, log: LogSink) -> ProviderFactory {
        ProviderFactory(paths: paths, log: log, runner: SystemProcessRunner())
    }

    func sources(for config: ProvidersConfig) -> [FallbackProvider] {
        let enabled = Set(config.enabledIDs)
        let builtIns = [claude(), codex()].filter { enabled.contains($0.provider) }
        let scripts = config.enabledScripts.map { script in
            FallbackProvider(primary: ScriptProvider(config: script, home: paths.home, runner: runner, log: log))
        }
        return builtIns + scripts
    }

    private func claude() -> FallbackProvider {
        FallbackProvider(primary: ClaudeStatusLineProvider(fileURL: paths.statusLineFile))
    }

    private func codex() -> FallbackProvider {
        let locator = CodexBinaryLocator(home: paths.home)
        return FallbackProvider(
            primary: CodexAppServerProvider(
                locate: { locator.locate() },
                spawner: SystemInteractiveSpawner(),
                clientVersion: Self.clientVersion
            ),
            fallback: CodexRolloutProvider(codexHome: paths.codexHome)
        )
    }
}
