import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ScriptOutputParserTests {
    let kimi = ProviderID("kimi")!

    private func parse(_ json: String) throws -> ProviderSnapshot {
        try ScriptOutputParser.parse(Data(json.utf8), provider: kimi, now: TestClock.now)
    }

    private func failure(_ json: String) -> ScriptFailure? {
        do {
            _ = try parse(json)
            return nil
        } catch {
            return error as? ScriptFailure
        }
    }

    @Test func readsVersionOne() throws {
        let snapshot = try parse("""
        {"version": 1, "plan": " Pro ", "windows": [
          {"label": "5h", "durationMinutes": 300, "usedPercent": 38.5, "resetsAt": "2026-10-05T18:00:00Z"},
          {"durationMinutes": 10080, "usedPercent": 12},
          {"label": "", "durationMinutes": 180, "usedPercent": 140, "resetsAt": "2026-10-02T18:00:00.250-03:00"}]}
        """)
        #expect(snapshot.provider == kimi)
        #expect(snapshot.source == .script)
        #expect(snapshot.planLabel == "Pro")
        #expect(snapshot.fetchedAt == TestClock.now)
        #expect(snapshot.windows.map(\.kind) == [.session, .week, .minutes(180)])
        #expect(snapshot.windows[0].label == "5h")
        #expect(snapshot.windows[0].usedPercent == 38.5)
        #expect(snapshot.windows[0].resetsAt == ISO8601DateFormatter().date(from: "2026-10-05T18:00:00Z"))
        #expect(snapshot.windows[1].label == nil)
        #expect(snapshot.windows[1].resetsAt == nil)
        #expect(snapshot.windows[2].label == nil, "an empty label falls back to the duration")
        #expect(snapshot.windows[2].displayPercent == 100)
        #expect(snapshot.windows[2].resetsAt == TestClock.date(2026, 10, 2, 18, 0).addingTimeInterval(0.25))
    }

    @Test(arguments: [
        ("nope", "JSON"),
        ("[]", "JSON"),
        (#"{"windows": []}"#, "version"),
        (#"{"version": 2, "windows": []}"#, "version"),
        (#"{"version": "1", "windows": []}"#, "version"),
        (#"{"version": 1}"#, "windows"),
        (#"{"version": 1, "windows": []}"#, "windows"),
        (#"{"version": 1, "windows": [1, 2, 3, 4, 5]}"#, "windows"),
        (#"{"version": 1, "plan": 3, "windows": [{"durationMinutes": 300, "usedPercent": 1}]}"#, "plan"),
        (#"{"version": 1, "plan": "\#(String(repeating: "x", count: 25))", "windows": [{"durationMinutes": 300, "usedPercent": 1}]}"#, "plan"),
        (#"{"version": 1, "windows": ["x"]}"#, "windows[0]"),
        (#"{"version": 1, "windows": [{"usedPercent": 1}]}"#, "windows[0].durationMinutes"),
        (#"{"version": 1, "windows": [{"durationMinutes": 0, "usedPercent": 1}]}"#, "windows[0].durationMinutes"),
        (#"{"version": 1, "windows": [{"durationMinutes": 525601, "usedPercent": 1}]}"#, "windows[0].durationMinutes"),
        (#"{"version": 1, "windows": [{"durationMinutes": 30.5, "usedPercent": 1}]}"#, "windows[0].durationMinutes"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300}]}"#, "windows[0].usedPercent"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": -1}]}"#, "windows[0].usedPercent"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": true}]}"#, "windows[0].usedPercent"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": 1, "resetsAt": "tomorrow"}]}"#, "windows[0].resetsAt"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": 1, "label": "line\nbreak"}]}"#, "windows[0].label"),
        (#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": 1}, {"durationMinutes": 299, "usedPercent": 2}]}"#, "windows[1].durationMinutes, same length as windows[0]"),
    ])
    func rejectsWithTheFieldAtFault(json: String, field: String) {
        #expect(failure(json) == .invalidOutput(field))
    }
}

@Suite struct ScriptProviderTests {
    let kimi = ProviderID("kimi")!
    static let validOutput = #"{"version":1,"plan":"Pro","windows":[{"label":"5h","durationMinutes":300,"usedPercent":42}]}"#

    private func provider(_ dir: TempDir, script body: String, timeout: TimeInterval = 5, log: LogSink = NullLog()) throws -> ScriptProvider {
        let url = try dir.write("#!/bin/bash\n\(body)\n", to: "bin/usage.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        let config = ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: [url.path, "--json"], interval: 120, timeout: timeout)
        return ScriptProvider(config: config, home: dir.url, log: log, now: { TestClock.now })
    }

    private func failure(_ provider: ScriptProvider) async -> ScriptFailure? {
        do {
            _ = try await provider.fetch()
            return nil
        } catch let UsageError.script(failure) {
            return failure
        } catch {
            return nil
        }
    }

    @Test func runsTheProgramAndReadsItsJSON() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let script = try provider(dir, script: #"[ "$1" = "--json" ] && echo '\#(Self.validOutput)'"#)
        let snapshot = try await script.fetch()
        #expect(snapshot.provider == kimi)
        #expect(snapshot.windows.first?.usedPercent == 42)
        #expect(snapshot.planLabel == "Pro")
        #expect(script.policy == FetchPolicy(timeout: 7, minimumSpacing: 120))
        #expect(script.source == .script)
    }

    @Test func runsInHomeWithAMinimalEnvironment() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        setenv("AICN_TEST_SECRET", "leaked", 1)
        let body = #"""
        ok=no
        if [ "$(pwd -P)" = "$(cd "$HOME" && pwd -P)" ] && [ -z "$AICN_TEST_SECRET" ] && [ "$LANG" = "en_US.UTF-8" ] && [ -n "$PATH" ]; then ok=yes; fi
        echo "{\"version\":1,\"windows\":[{\"label\":\"$ok\",\"durationMinutes\":300,\"usedPercent\":1}]}"
        """#
        let snapshot = try await provider(dir, script: body).fetch()
        #expect(snapshot.windows.first?.label == "yes")
    }

    @Test func nonZeroExitIsAFailureAndStderrGoesToTheLogTruncated() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let log = MemoryLog()
        let script = try provider(dir, script: #"printf 'x%.0s' {1..2000} >&2; exit 3"#, log: log)
        #expect(await failure(script) == .exit(3))
        let line = try #require(log.lines.first { $0.contains("script kimi") })
        #expect(line.contains("xxxx"))
        #expect(line.count < 400)
    }

    @Test func slowScriptsAreStopped() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let started = Date()
        #expect(await failure(try provider(dir, script: "sleep 10", timeout: 1)) == .timedOut(seconds: 1))
        #expect(Date().timeIntervalSince(started) < 5)
    }

    @Test func floodingOutputIsCut() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let script = try provider(dir, script: "yes aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(await failure(script) == .tooMuchOutput(kilobytes: 64))
    }

    @Test func invalidOutputNamesTheField() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let script = try provider(dir, script: #"echo '{"version":1,"windows":[{"durationMinutes":300,"usedPercent":-5}]}'"#)
        #expect(await failure(script) == .invalidOutput("windows[0].usedPercent"))
    }

    @Test func missingOrNotExecutableProgramsCannotStart() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let plain = try dir.write("#!/bin/bash\necho hi\n", to: "plain.sh")
        for path in [plain.path, dir.file("missing.sh").path] {
            let config = ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: [path], interval: 60, timeout: 5)
            #expect(await failure(ScriptProvider(config: config, home: dir.url)) == .launch)
        }
    }
}
