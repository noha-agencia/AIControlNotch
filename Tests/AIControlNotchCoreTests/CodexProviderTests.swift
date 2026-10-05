import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct CodexRateLimitParserTests {
    @Test func prefersTheCodexBucket() throws {
        let parsed = try CodexRateLimitParser.parseAppServerResponse(try fixture("codex_rate_limits_response.json"))
        #expect(parsed.windows == [UsageWindow(kind: .week, usedPercent: 91, durationMinutes: 10_080, resetsAt: Date(timeIntervalSince1970: 1_791_237_522))])
        #expect(parsed.planLabel == "Pro Lite")
    }

    @Test func classifiesByDurationNotPosition() throws {
        let parsed = try CodexRateLimitParser.parseAppServerResponse(try fixture("codex_rate_limits_two_windows.json"))
        #expect(parsed.windows.map(\.kind) == [.session, .week])
        #expect(parsed.windows[0].usedPercent == 37.5)
        #expect(parsed.planLabel == "Plus")
    }

    @Test func errorReplyIsProcessFailure() {
        let line = Data(#"{"id":2,"error":{"code":-32600,"message":"not logged in"}}"#.utf8)
        #expect(throws: UsageError.self) { _ = try CodexRateLimitParser.parseAppServerResponse(line) }
    }

    @Test func missingWindowsIsInvalid() {
        let line = Data(#"{"id":2,"result":{"rateLimits":{"primary":null,"secondary":null}}}"#.utf8)
        #expect(throws: UsageError.self) { _ = try CodexRateLimitParser.parseAppServerResponse(line) }
    }

    @Test func windowsWithoutResetOrDurationAreSkipped() throws {
        let line = Data(#"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":null,"resetsAt":1},"secondary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1791585404}}}}"#.utf8)
        let parsed = try CodexRateLimitParser.parseAppServerResponse(line)
        #expect(parsed.windows.map(\.usedPercent) == [7])
    }

    @Test(arguments: [("plus", "Plus"), ("pro", "Pro"), ("prolite", "Pro Lite"), ("team", "Team"),
                      ("self_serve_business_prolite", "Self Serve Business Prolite"), ("unknown", nil)])
    func planLabels(raw: String, expected: String?) {
        #expect(CodexRateLimitParser.planLabel(raw) == expected)
    }

    @Test func rolloutLineParses() throws {
        let line = Data(#"{"timestamp":"2026-10-02T18:05:00.443Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":91.0,"window_minutes":10080,"resets_at":1791237522},"secondary":{"used_percent":3.0,"window_minutes":300,"resets_at":0},"plan_type":"prolite"}}}"#.utf8)
        let parsed = try #require(CodexRateLimitParser.parseRolloutLine(line))
        #expect(parsed.windows.map(\.kind) == [.week])
        #expect(parsed.timestamp == ISODate.parse("2026-10-02T18:05:00.443Z"))
    }

    @Test func rolloutLineWithoutRateLimitsIsNil() {
        #expect(CodexRateLimitParser.parseRolloutLine(Data(#"{"payload":{"type":"token_count","rate_limits":null}}"#.utf8)) == nil)
        #expect(CodexRateLimitParser.parseRolloutLine(Data(#"{"payload":{"type":"message"}}"#.utf8)) == nil)
        #expect(CodexRateLimitParser.parseRolloutLine(Data("not json".utf8)) == nil)
    }
}

@Suite struct CodexBinaryLocatorTests {
    let home = URL(fileURLWithPath: "/Users/test")

    @Test func pathWinsFirst() {
        let locator = CodexBinaryLocator(environment: ["PATH": "/a:/b"], home: home) { $0 == "/b/codex" || $0.hasPrefix("/Applications") }
        #expect(locator.locate()?.path == "/b/codex")
    }

    @Test func chatGPTBundleBeforeOthers() {
        let locator = CodexBinaryLocator(environment: ["PATH": "/usr/bin"], home: home) { _ in true }
        #expect(CodexBinaryLocator(environment: [:], home: home) { $0 != "/nonexistent" }.locate()?.path
            == "/Applications/ChatGPT.app/Contents/Resources/codex")
        #expect(locator.locate()?.path == "/usr/bin/codex")
    }

    @Test func fallsThroughKnownLocations() {
        let order = CodexBinaryLocator(environment: [:], home: home) { _ in false }.candidates.map(\.path)
        #expect(order == [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Users/test/.local/bin/codex",
            "/opt/homebrew/bin/codex",
        ])
        let locator = CodexBinaryLocator(environment: [:], home: home) { $0 == "/opt/homebrew/bin/codex" }
        #expect(locator.locate()?.path == "/opt/homebrew/bin/codex")
    }

    @Test func nothingFound() {
        #expect(CodexBinaryLocator(environment: ["PATH": "/x"], home: home) { _ in false }.locate() == nil)
    }
}

@Suite struct CodexAppServerProviderTests {
    let now = Date(timeIntervalSince1970: 1_790_960_000)

    /// Writes an executable shell script standing in for `codex`.
    private func fakeCodex(_ dir: TempDir, body: String) throws -> URL {
        let url = try dir.write("#!/bin/sh\n\(body)\n", to: "codex")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func provider(_ binary: URL?, timeout: TimeInterval = 5) -> CodexAppServerProvider {
        CodexAppServerProvider(
            locate: { binary },
            spawner: SystemInteractiveSpawner(),
            clientVersion: "0.1.0",
            timeout: timeout,
            now: { [now] in now }
        )
    }

    @Test func readsRateLimitsAfterHandshake() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let response = String(decoding: try fixture("codex_rate_limits_response.json"), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let log = dir.file("received.jsonl").path
        let script = """
        [ "$1" = "app-server" ] || exit 9
        read init; echo "$init" >> '\(log)'
        echo '{"id":1,"result":{"userAgent":"fake"}}'
        read initialized; echo "$initialized" >> '\(log)'
        read request; echo "$request" >> '\(log)'
        echo '{"method":"remoteControl/status/changed","params":{"status":"disabled"}}'
        echo '\(response)'
        """
        let snapshot = try await provider(try fakeCodex(dir, body: script)).fetch()
        #expect(snapshot.provider == .codex)
        #expect(snapshot.source == .codexAppServer)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.windows.first?.usedPercent == 91)
        #expect(snapshot.planLabel == "Pro Lite")

        let sent = try String(contentsOfFile: log, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(sent.count == 3)
        #expect(sent[0].contains(#""method":"initialize""#))
        #expect(sent[0].contains(#""name":"aicontrolnotch""#))
        #expect(sent[1] == #"{"method":"initialized"}"#)
        #expect(sent[2].contains(#""method":"account/rateLimits/read""#))
        #expect(sent[2].contains(#""id":2"#))
    }

    @Test func errorReplyFails() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let script = """
        read init; echo '{"id":1,"result":{}}'
        read initialized; read request
        echo '{"id":2,"error":{"code":-32603,"message":"auth required"}}'
        """
        await #expect(throws: UsageError.self) { _ = try await provider(try fakeCodex(dir, body: script)).fetch() }
    }

    @Test func serverThatExitsEarlyFails() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        await #expect(throws: UsageError.self) { _ = try await provider(try fakeCodex(dir, body: "exit 1")).fetch() }
    }

    @Test func hangingServerTimesOut() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let binary = try fakeCodex(dir, body: "exec sleep 30")
        await #expect(throws: UsageError.timeout) { _ = try await provider(binary, timeout: 0.5).fetch() }
    }

    @Test func missingBinaryIsNotFound() async {
        await #expect(throws: UsageError.notFound("codex")) { _ = try await provider(nil).fetch() }
    }
}

@Suite struct CodexRolloutProviderTests {
    private func touch(_ url: URL, minutesAgo: Double) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-minutesAgo * 60)], ofItemAtPath: url.path
        )
    }

    private func line(used: Double, resetsAt: Int = 1_791_237_522, timestamp: String) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":\#(used),"window_minutes":10080,"resets_at":\#(resetsAt)},"secondary":null,"plan_type":"plus"}}}"#
    }

    @Test func readsTheLastTokenCountOfTheNewestFile() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let content = String(decoding: try fixture("codex_rollout.jsonl"), as: UTF8.self)
        let newest = try dir.write(content, to: "sessions/2026/10/02/rollout-2026-10-02T15-04-10-a.jsonl")
        let older = try dir.write(line(used: 50, timestamp: "2026-10-01T10:00:00Z"), to: "sessions/2026/10/01/rollout-2026-10-01T10-00-00-b.jsonl")
        try touch(newest, minutesAgo: 1)
        try touch(older, minutesAgo: 600)

        let snapshot = try await CodexRolloutProvider(codexHome: dir.url).fetch()
        #expect(snapshot.source == .codexRollout)
        #expect(snapshot.windows == [UsageWindow(kind: .week, usedPercent: 91, durationMinutes: 10_080, resetsAt: Date(timeIntervalSince1970: 1_791_237_522))])
        #expect(snapshot.fetchedAt == ISODate.parse("2026-10-02T18:05:00.443Z"))
        #expect(snapshot.planLabel == "Pro Lite")
    }

    @Test func includesArchivedSessions() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let archived = try dir.write(line(used: 64, timestamp: "2026-10-02T12:00:00Z"), to: "archived_sessions/rollout-x.jsonl")
        let stale = try dir.write("{\"payload\":{\"type\":\"message\"}}", to: "sessions/2026/10/02/rollout-y.jsonl")
        try touch(archived, minutesAgo: 30)
        try touch(stale, minutesAgo: 1)

        let snapshot = try await CodexRolloutProvider(codexHome: dir.url).fetch()
        #expect(snapshot.windows.first?.usedPercent == 64)
    }

    @Test func ignoresOtherFiles() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write(line(used: 64, timestamp: "2026-10-02T12:00:00Z"), to: "sessions/notes.jsonl")
        await #expect(throws: UsageError.self) { _ = try await CodexRolloutProvider(codexHome: dir.url).fetch() }
    }

    @Test func onlyTheNewestTwentyFilesAreRead() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let match = try dir.write(line(used: 70, timestamp: "2026-09-01T12:00:00Z"), to: "sessions/old/rollout-match.jsonl")
        try touch(match, minutesAgo: 10_000)
        for index in 0..<20 {
            let empty = try dir.write("{}", to: "sessions/new/rollout-\(index).jsonl")
            try touch(empty, minutesAgo: Double(index))
        }
        await #expect(throws: UsageError.self) { _ = try await CodexRolloutProvider(codexHome: dir.url).fetch() }
    }

    @Test func missingCodexHomeIsNotFound() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        await #expect(throws: UsageError.self) {
            _ = try await CodexRolloutProvider(codexHome: dir.file("missing")).fetch()
        }
    }
}

/// Provider fake with a fixed outcome, counting calls.
final class StubProvider: UsageProvider, @unchecked Sendable {
    let provider: ProviderID
    let source: DataSource
    var outcome: Result<ProviderSnapshot, UsageError>
    private(set) var calls = 0

    init(_ source: DataSource, _ outcome: Result<ProviderSnapshot, UsageError>, provider: ProviderID = .codex) {
        self.provider = provider
        self.source = source
        self.outcome = outcome
    }

    func fetch() async throws -> ProviderSnapshot {
        calls += 1
        return try outcome.get()
    }
}

@Suite struct FallbackProviderTests {
    let primarySnapshot = ProviderSnapshot.make(windows: [.make(used: 10)], source: .codexAppServer)
    let fallbackSnapshot = ProviderSnapshot.make(windows: [.make(used: 20)], source: .codexRollout)

    @Test func primarySuccessSkipsFallback() async throws {
        let primary = StubProvider(.codexAppServer, .success(primarySnapshot))
        let fallback = StubProvider(.codexRollout, .success(fallbackSnapshot))
        let outcome = await FallbackProvider(primary: primary, fallback: fallback).fetch(skipPrimary: false)
        #expect(outcome.snapshot == primarySnapshot)
        #expect(outcome.primaryError == nil)
        #expect(fallback.calls == 0)
    }

    @Test func primaryFailureUsesFallback() async throws {
        let primary = StubProvider(.codexAppServer, .failure(.timeout))
        let fallback = StubProvider(.codexRollout, .success(fallbackSnapshot))
        let outcome = await FallbackProvider(primary: primary, fallback: fallback).fetch(skipPrimary: false)
        #expect(outcome.snapshot == fallbackSnapshot)
        #expect(outcome.primaryError == .timeout)
        #expect(outcome.fallbackError == nil)
    }

    @Test func skippingPrimaryGoesStraightToFallback() async throws {
        let primary = StubProvider(.codexAppServer, .success(primarySnapshot))
        let fallback = StubProvider(.codexRollout, .success(fallbackSnapshot))
        let outcome = await FallbackProvider(primary: primary, fallback: fallback).fetch(skipPrimary: true)
        #expect(outcome.snapshot == fallbackSnapshot)
        #expect(primary.calls == 0)
    }

    @Test func bothFailing() async throws {
        let provider = FallbackProvider(
            primary: StubProvider(.codexAppServer, .failure(.processFailed("exit 1"))),
            fallback: StubProvider(.codexRollout, .failure(.notFound("logs")))
        )
        let outcome = await provider.fetch(skipPrimary: false)
        #expect(outcome.snapshot == nil)
        #expect(outcome.primaryError == .processFailed("exit 1"))
        #expect(outcome.fallbackError == .notFound("logs"))
        await #expect(throws: UsageError.processFailed("exit 1")) { _ = try await provider.fetch() }
        #expect(provider.provider == .codex)
    }

    @Test func plainFetchReturnsSnapshot() async throws {
        let provider = FallbackProvider(
            primary: StubProvider(.codexAppServer, .failure(.timeout)),
            fallback: StubProvider(.codexRollout, .success(fallbackSnapshot))
        )
        #expect(try await provider.fetch() == fallbackSnapshot)
    }
}
