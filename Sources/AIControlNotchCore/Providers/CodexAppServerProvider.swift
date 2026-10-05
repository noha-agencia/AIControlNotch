import Foundation

/// Primary Codex source: asks the local `codex app-server` (JSONL over stdio),
/// which reads limits with Codex's own login. One short-lived process per read.
public struct CodexAppServerProvider: UsageProvider {
    public static let defaultTimeout: TimeInterval = 10
    static let initializeID = 1
    static let rateLimitsID = 2

    public let provider = ProviderID.codex
    public let source = DataSource.codexAppServer

    private let locate: @Sendable () -> URL?
    private let spawner: InteractiveSpawning
    private let clientVersion: String
    private let timeout: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        locate: @escaping @Sendable () -> URL?,
        spawner: InteractiveSpawning,
        clientVersion: String,
        timeout: TimeInterval = CodexAppServerProvider.defaultTimeout,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.locate = locate
        self.spawner = spawner
        self.clientVersion = clientVersion
        self.timeout = timeout
        self.now = now
    }

    public func fetch() async throws -> ProviderSnapshot {
        guard let binary = locate() else { throw UsageError.notFound("codex") }
        let process = try spawner.spawn(binary, arguments: ["app-server"])
        defer { process.terminate() }
        let messages = handshake()
        let reply = try await withTimeout(timeout) {
            try await Self.converse(process, messages: messages)
        }
        let limits = try CodexRateLimitParser.parseAppServerResponse(reply)
        return ProviderSnapshot(provider: provider, windows: limits.windows, planLabel: limits.planLabel, fetchedAt: now(), source: source)
    }

    private func handshake() -> [String] {
        [
            #"{"id":\#(Self.initializeID),"method":"initialize","params":{"clientInfo":{"name":"aicontrolnotch","title":"AIControlNotch","version":"\#(clientVersion)"},"capabilities":null}}"#,
            #"{"method":"initialized"}"#,
            #"{"id":\#(Self.rateLimitsID),"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true}}"#,
        ]
    }

    private static func converse(_ process: InteractiveProcess, messages: [String]) async throws -> Data {
        var lines = process.lines.makeAsyncIterator()
        try process.send(messages[0])
        _ = try await reply(to: initializeID, from: &lines)
        try process.send(messages[1])
        try process.send(messages[2])
        return try await reply(to: rateLimitsID, from: &lines)
    }

    /// Skips notifications until the reply with `id` arrives.
    private static func reply(
        to id: Int,
        from lines: inout AsyncThrowingStream<String, Error>.Iterator
    ) async throws -> Data {
        while let line = try await lines.next() {
            let data = Data(line.utf8)
            if (try? JSONDecoder().decode(IDProbe.self, from: data))?.id == id { return data }
        }
        throw UsageError.processFailed("codex app-server closed before replying")
    }

    private struct IDProbe: Decodable {
        let id: Int?
    }
}
