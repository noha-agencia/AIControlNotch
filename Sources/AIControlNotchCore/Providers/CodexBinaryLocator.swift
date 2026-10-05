import Foundation

/// Finds the `codex` CLI. GUI apps get a minimal PATH, so known install
/// locations are checked after PATH (the ChatGPT app bundles its own copy).
public struct CodexBinaryLocator: Sendable {
    private let environment: [String: String]
    private let home: URL
    private let isExecutable: @Sendable (String) -> Bool

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.environment = environment
        self.home = home
        self.isExecutable = isExecutable
    }

    var candidates: [URL] {
        [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex"),
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
        ]
    }

    public func locate() -> URL? {
        let fromPath = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("codex") }
        return (fromPath + candidates).first { isExecutable($0.path) }
    }
}
