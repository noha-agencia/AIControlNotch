import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ProcessRunnerTests {
    let runner = SystemProcessRunner()

    @Test func capturesStdout() async throws {
        let result = try await runner.run(URL(fileURLWithPath: "/bin/echo"), arguments: ["hello"], stdin: nil, timeout: 5)
        #expect(result.exitCode == 0)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "hello\n")
    }

    @Test func passesStdin() async throws {
        let result = try await runner.run(URL(fileURLWithPath: "/bin/cat"), arguments: [], stdin: Data("abc".utf8), timeout: 5)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "abc")
    }

    @Test func reportsExitCodeAndStderr() async throws {
        let result = try await runner.run(
            URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo oops >&2; exit 3"], stdin: nil, timeout: 5
        )
        #expect(result.exitCode == 3)
        #expect(String(decoding: result.stderr, as: UTF8.self) == "oops\n")
    }

    @Test func timesOut() async {
        await #expect(throws: UsageError.timeout) {
            _ = try await runner.run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], stdin: nil, timeout: 0.3)
        }
    }

    @Test func missingExecutableThrows() async {
        await #expect(throws: UsageError.self) {
            _ = try await runner.run(URL(fileURLWithPath: "/nonexistent/tool"), arguments: [], stdin: nil, timeout: 1)
        }
    }
}

@Suite struct InteractiveProcessTests {
    @Test func echoesLinesThroughCat() async throws {
        let process = try SystemInteractiveProcess.spawn(URL(fileURLWithPath: "/bin/cat"), arguments: [])
        defer { process.terminate() }
        try process.send("first")
        try process.send("second")
        var received: [String] = []
        for try await line in process.lines {
            received.append(line)
            if received.count == 2 { break }
        }
        #expect(received == ["first", "second"])
    }

    @Test func streamEndsWhenProcessExits() async throws {
        let process = try SystemInteractiveProcess.spawn(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf 'a\\nb'"])
        defer { process.terminate() }
        var received: [String] = []
        for try await line in process.lines { received.append(line) }
        #expect(received == ["a", "b"])
    }

    @Test func spawnFailureThrows() {
        #expect(throws: UsageError.self) {
            _ = try SystemInteractiveProcess.spawn(URL(fileURLWithPath: "/nonexistent/tool"), arguments: [])
        }
    }
}

/// Process runner fake that returns a canned result and records calls.
final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
    var result: Result<ProcessResult, UsageError>
    private(set) var calls: [(String, [String])] = []
    private(set) var inputs: [Data?] = []

    init(_ result: Result<ProcessResult, UsageError>) { self.result = result }

    func run(_ executable: URL, arguments: [String], stdin: Data?, timeout: TimeInterval) async throws -> ProcessResult {
        calls.append((executable.path, arguments))
        inputs.append(stdin)
        return try result.get()
    }
}

@Suite struct PathsTests {
    @Test func layoutUnderHome() {
        let paths = Paths(home: URL(fileURLWithPath: "/Users/test"))
        #expect(paths.supportDirectory.path == "/Users/test/Library/Application Support/AIControlNotch")
        #expect(paths.stateFile.path == "/Users/test/Library/Application Support/AIControlNotch/state.json")
        #expect(paths.statusLineFile.path == "/Users/test/Library/Application Support/AIControlNotch/claude-statusline.json")
        #expect(paths.tapConfigFile.path == "/Users/test/Library/Application Support/AIControlNotch/tap.json")
        #expect(paths.logFile.path == "/Users/test/Library/Logs/AIControlNotch/aicontrolnotch.log")
        #expect(paths.codexHome.path == "/Users/test/.codex")
    }
}

@Suite struct UsageErrorTests {
    @Test func backoffClassification() {
        #expect(UsageError.network("x").triggersBackoff)
        #expect(UsageError.timeout.triggersBackoff)
        #expect(UsageError.http(status: 429, retryAfter: 10).triggersBackoff)
        #expect(UsageError.http(status: 503, retryAfter: nil).triggersBackoff)
        #expect(UsageError.invalidFormat("x").triggersBackoff)
        #expect(!UsageError.http(status: 404, retryAfter: nil).triggersBackoff)
        #expect(!UsageError.notFound("x").triggersBackoff)
    }

    @Test func retryAfterOnlyFromHTTP() {
        #expect(UsageError.http(status: 429, retryAfter: 60).retryAfter == 60)
        #expect(UsageError.timeout.retryAfter == nil)
    }

    @Test func descriptionsNeverEmpty() {
        let all: [UsageError] = [
            .http(status: 500, retryAfter: nil), .network("offline"),
            .timeout, .invalidFormat("x"), .notFound("codex"), .processFailed("exit 1"),
        ]
        #expect(all.allSatisfy { !$0.logDescription.isEmpty })
    }
}
