import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct StatusLineTapTests {
    let original = ProcessResult(exitCode: 0, stdout: Data("~/project  main  Opus\n".utf8), stderr: Data())

    private func input() throws -> Data {
        try fixture("statusline_input.json")
    }

    private func tap(_ dir: TempDir, runner: FakeProcessRunner) -> StatusLineTap {
        StatusLineTap(paths: Paths(home: dir.url), runner: runner, now: { TestClock.now })
    }

    private func writeConfig(_ dir: TempDir, command: String) throws {
        let paths = Paths(home: dir.url)
        let config = try JSONEncoder().encode(TapConfig(command: command))
        try AtomicFile.write(config, to: paths.tapConfigFile)
    }

    @Test func savesTheLimitsAndRunsTheOriginalCommand() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try writeConfig(dir, command: "node \"/Users/me/.claude/statusline.js\"")
        let runner = FakeProcessRunner(.success(original))
        let output = await tap(dir, runner: runner).run(input: try input())

        #expect(output == TapOutput(stdout: original.stdout, exitCode: 0))
        #expect(runner.calls.first?.0 == "/bin/sh")
        #expect(runner.calls.first?.1 == ["-c", "node \"/Users/me/.claude/statusline.js\""])
        #expect(runner.inputs.first == (try input()), "the original command gets the same stdin")

        let saved = try StatusLineRecord.decode(Data(contentsOf: Paths(home: dir.url).statusLineFile))
        #expect(saved.capturedAt == TestClock.now)
        #expect(saved.fiveHour != nil)
    }

    @Test func passesTheOriginalExitCodeThrough() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try writeConfig(dir, command: "false")
        let runner = FakeProcessRunner(.success(ProcessResult(exitCode: 3, stdout: Data(), stderr: Data())))
        let output = await tap(dir, runner: runner).run(input: try input())
        #expect(output.exitCode == 3)
    }

    @Test func withoutConfigPrintsNothing() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let runner = FakeProcessRunner(.success(original))
        let output = await tap(dir, runner: runner).run(input: try input())
        #expect(output == TapOutput(stdout: Data(), exitCode: 0))
        #expect(runner.calls.isEmpty)
        #expect(FileManager.default.fileExists(atPath: Paths(home: dir.url).statusLineFile.path))
    }

    @Test func inputWithoutLimitsKeepsThePreviousRecord() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let runner = FakeProcessRunner(.success(original))
        _ = await tap(dir, runner: runner).run(input: try input())
        let before = try Data(contentsOf: Paths(home: dir.url).statusLineFile)
        _ = await tap(dir, runner: runner).run(input: try fixture("statusline_input_no_limits.json"))
        #expect(try Data(contentsOf: Paths(home: dir.url).statusLineFile) == before)
    }

    @Test func garbageInputNeverFails() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try writeConfig(dir, command: "cat")
        let runner = FakeProcessRunner(.success(original))
        let output = await tap(dir, runner: runner).run(input: Data("not json".utf8))
        #expect(output.stdout == original.stdout)
    }

    @Test func failingCommandStillExitsCleanly() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try writeConfig(dir, command: "node missing.js")
        let runner = FakeProcessRunner(.failure(.timeout))
        let output = await tap(dir, runner: runner).run(input: try input())
        #expect(output == TapOutput(stdout: Data(), exitCode: 0))
    }

    @Test func brokenConfigIsIgnored() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try AtomicFile.write(Data("{".utf8), to: Paths(home: dir.url).tapConfigFile)
        let runner = FakeProcessRunner(.success(original))
        let output = await tap(dir, runner: runner).run(input: try input())
        #expect(output.stdout.isEmpty)
        #expect(runner.calls.isEmpty)
    }

    @Test func aTapConfigOthersCanChangeIsNotRun() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        try writeConfig(dir, command: "echo hi")
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: Paths(home: dir.url).tapConfigFile.path)
        let runner = FakeProcessRunner(.success(original))
        let output = await tap(dir, runner: runner).run(input: try input())
        #expect(runner.calls.isEmpty, "tap.json runs through the shell, so it gets the providers.json checks")
        #expect(String(decoding: output.stdout, as: UTF8.self)
            == "AIControlNotch: tap.json ignored: tap.json can be changed by other users; run chmod 600 on it\n")
        #expect(output.exitCode == 0)
    }

    @Test func configRoundTrips() throws {
        let data = try JSONEncoder().encode(TapConfig(command: "echo hi"))
        #expect(try TapConfig.decode(data) == TapConfig(command: "echo hi"))
        #expect(throws: (any Error).self) { _ = try TapConfig.decode(Data("{\"command\":\"\"}".utf8)) }
    }
}

@Suite struct PathsEnvironmentTests {
    @Test func honorsHomeFromTheEnvironment() {
        let paths = Paths.current(environment: ["HOME": "/tmp/someone"])
        #expect(paths.home.path == "/tmp/someone")
    }

    @Test func ignoresAMissingOrRelativeHome() {
        let fallback = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(Paths.current(environment: [:]).home.path == fallback)
        #expect(Paths.current(environment: ["HOME": "relative"]).home.path == fallback)
    }
}
