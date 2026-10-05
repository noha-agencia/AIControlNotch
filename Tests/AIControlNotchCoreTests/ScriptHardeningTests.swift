import Darwin
import Foundation
import Testing
@testable import AIControlNotchCore

/// Findings from the code and security reviews of the script providers.
@Suite struct ScriptOutputHardeningTests {
    let kimi = ProviderID("kimi")!

    private func failure(_ json: String) -> ScriptFailure? {
        do {
            _ = try ScriptOutputParser.parse(Data(json.utf8), provider: kimi, now: TestClock.now)
            return nil
        } catch {
            return error as? ScriptFailure
        }
    }

    @Test func hugeIntegersAreNotWrappedIntoRange() {
        // NSNumber.intValue wraps 2^64 + 4096 to 4096; it must be rejected, not guessed.
        #expect(failure(#"{"version": 1, "windows": [{"durationMinutes": 18446744073709555712, "usedPercent": 1}]}"#)
            == .invalidOutput("windows[0].durationMinutes"))
    }

    @Test func usedPercentHasACeiling() {
        #expect(failure(#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": 1e308}]}"#)
            == .invalidOutput("windows[0].usedPercent"))
        #expect(failure(#"{"version": 1, "windows": [{"durationMinutes": 300, "usedPercent": 1000}]}"#) == nil)
    }

    @Test(arguments: [
        "\u{202E}evil",        // right-to-left override (Cf)
        "zero\u{200B}width",   // zero-width space (Cf)
        "line\u{2028}sep",     // line separator (Zl)
        "private\u{E000}",     // private use (Co)
        "e" + String(repeating: "\u{0301}", count: 200), // one grapheme, 201 scalars
    ])
    func invisibleOrOversizedTextIsRejected(label: String) throws {
        let json = String(data: try JSONSerialization.data(withJSONObject: [
            "version": 1, "windows": [["durationMinutes": 300, "usedPercent": 1, "label": label]],
        ]), encoding: .utf8)!
        #expect(failure(json) == .invalidOutput("windows[0].label"))
    }

    @Test func accentsAndEmojiStillPass() {
        #expect(failure(#"{"version": 1, "plan": "Pró 🚀", "windows": [{"durationMinutes": 300, "usedPercent": 1, "label": "Diário"}]}"#) == nil)
    }

    @Test func twoWindowsOfTheSameLengthNameTheEarlierOne() {
        #expect(failure(#"{"version": 1, "windows": [{"durationMinutes": 10080, "usedPercent": 1}, {"durationMinutes": 10000, "usedPercent": 2}]}"#)
            == .invalidOutput("windows[1].durationMinutes, same length as windows[0]"))
    }
}

@Suite struct LogRedactionTests {
    @Test(arguments: [
        ("Authorization: Bearer abc.def-123", "Authorization: [redacted]"),
        ("key sk-ant-api03-AbCdEf_12 failed", "key [redacted] failed"),
        ("GET /x?token=s3cr3t&page=2", "GET /x?token=[redacted]&page=2"),
        ("password: hunter2", "password: [redacted]"),
        ("api_key=\"xyz\"", "api_key=[redacted]"),
        ("could not read usage file", "could not read usage file"),
    ])
    func hidesLikelySecrets(input: String, expected: String) {
        #expect(LogRedaction.redact(input) == expected)
    }
}

@Suite struct ScriptProcessHardeningTests {
    let kimi = ProviderID("kimi")!

    /// Polls `condition` every 50 ms for up to `seconds`; process start-up is slow under load.
    private func eventually(_ seconds: Double = 10, _ condition: () -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func stoppingAScriptAlsoStopsWhatItLeftRunning() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let pidFile = dir.file("child.pid")
        let script = try dir.write("#!/bin/bash\nsleep 30 &\necho $! > '\(pidFile.path)'\nwait\n", to: "spawn.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let config = ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: [script.path], interval: 60, timeout: 30)
        let task = Task { try await ScriptProvider(config: config, home: dir.url).fetch() }
        let readPID = { (try? String(contentsOf: pidFile, encoding: .utf8)).flatMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) } }
        #expect(try await eventually { readPID() != nil }, "the script started its background job")
        task.cancel()
        _ = await task.result
        let pid = try #require(readPID())
        #expect(try await eventually { kill(pid, 0) == -1 && errno == ESRCH }, "the backgrounded grandchild is gone")
    }

    @Test func cancellingTheFetchStopsTheScriptAndSaysItTimedOut() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let script = try dir.write("#!/bin/bash\nsleep 30\n", to: "slow.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let config = ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: [script.path], interval: 60, timeout: 20)
        let provider = ScriptProvider(config: config, home: dir.url)
        let started = Date()
        let task = Task { try await provider.fetch() }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let result = await task.result
        #expect(Date().timeIntervalSince(started) < 5, "cancellation does not wait for the script")
        guard case let .failure(UsageError.script(failure)) = result else {
            Issue.record("expected a script failure, got \(result)")
            return
        }
        #expect(failure == .timedOut(seconds: 20))
    }
}

@Suite struct ProvidersConfigHardeningTests {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)

    private func parse(_ json: String) throws -> ProvidersConfig {
        try ProvidersConfig.parse(Data(json.utf8), home: home)
    }

    @Test func disablingAPinnedModelUnpinsIt() throws {
        let config = try parse(#"{"pinned": ["claude", "codex"], "disabled": ["codex"]}"#)
        #expect(config.pinned == [.claude])
        #expect(try parse(#"{"pinned": ["codex"], "disabled": ["codex"]}"#).pinned == [.claude], "nothing left: the first enabled")
        #expect(try parse(#"{"pinned": []}"#).pinned == [.claude, .codex], "an empty rest view is never wanted")
    }

    @Test func homeIsExpandedInEveryArgument() throws {
        let config = try parse(#"{"providers": [{"id": "k", "name": "K", "command": ["/usr/bin/python3", "~/bin/k.py", "x~/y"]}]}"#)
        #expect(config.scripts.first?.command == ["/usr/bin/python3", "/Users/someone/bin/k.py", "x~/y"])
    }

    @Test func invisibleCharactersInNamesAreRejected() {
        #expect(throws: ProvidersConfigError("providers[0].name: 1-24 characters")) {
            try parse(#"{"providers": [{"id": "k", "name": "K\u202Eimi", "command": ["/bin/k"]}]}"#)
        }
    }

    @Test func echoedValuesAreShortened() {
        let long = String(repeating: "x", count: 200)
        #expect(throws: ProvidersConfigError("pinned: unknown model \"\(String(repeating: "x", count: 32))…\"")) {
            try parse(#"{"pinned": ["\#(long)"]}"#)
        }
    }

    @Test func catalogToleratesRepeatedIDsFromCode() {
        let script = ScriptProviderConfig(id: ProviderID("k")!, name: "K", accentHex: nil, command: ["/bin/k"], interval: 60, timeout: 5)
        let catalog = ProviderCatalog(config: ProvidersConfig(pinned: [.claude], disabled: [], scripts: [script, script]))
        #expect(catalog.descriptor(ProviderID("k")!).displayName == "K")
    }
}

@Suite struct ProvidersConfigFileHardeningTests {
    private func file(_ dir: TempDir) -> ProvidersConfigFile {
        ProvidersConfigFile(url: dir.file("providers.json"), home: dir.url)
    }

    @Test func filesOthersCanWriteAreRefused() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try dir.write("{}", to: "providers.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: url.path)
        #expect(file(dir).load().error == ProvidersConfigError("providers.json can be changed by other users; run chmod 600 on it"))
    }

    @Test func aFolderOthersCanWriteIsRefused() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write("{}", to: "providers.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: dir.url.path)
        #expect(file(dir).load().error == ProvidersConfigError("the folder of providers.json can be changed by other users"))
    }

    @Test func onlyRegularFilesAreRead() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(mkfifo(dir.file("providers.json").path, 0o600) == 0)
        #expect(file(dir).load().error == ProvidersConfigError("providers.json must be a regular file"))
    }

    @Test func aSymlinkToAPrivateFileIsFine() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let target = try dir.write(#"{"disabled": ["codex"]}"#, to: "dotfiles/providers.json")
        try FileManager.default.createSymbolicLink(at: dir.file("providers.json"), withDestinationURL: target)
        let loaded = file(dir).load()
        #expect(loaded.error == nil)
        #expect(loaded.config.disabled == [.codex])
    }

    @Test func templateNeverReplacesAFileThatAppearedMeanwhile() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write(#"{"disabled": ["codex"]}"#, to: "providers.json")
        #expect(try !file(dir).createTemplateIfMissing())
        #expect(file(dir).load().config.disabled == [.codex])
    }

    @Test func atomicWritesArePrivateFromTheStart() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = dir.file("nested/state.json")
        try AtomicFile.write(Data("{}".utf8), to: url)
        let file = try FileManager.default.attributesOfItem(atPath: url.path)
        let folder = try FileManager.default.attributesOfItem(atPath: url.deletingLastPathComponent().path)
        #expect((file[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect((folder[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(leftovers == ["state.json"])
    }
}

/// Review: a broken edit must not take the scripts away; a changed script runs again at once.
@Suite struct ProvidersConfigUpdateTests {
    let kimi = ProviderID("kimi")!

    private func script(interval: TimeInterval = 300) -> ScriptProviderConfig {
        ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: ["/bin/kimi"], interval: interval, timeout: 15)
    }

    private func config(_ scripts: [ScriptProviderConfig]) -> ProvidersConfig {
        ProvidersConfig(pinned: [.claude, .codex], disabled: [], scripts: scripts)
    }

    @Test func aRejectedFileKeepsTheLastGoodSettings() {
        let broken = ProvidersConfigLoad(config: .default, error: ProvidersConfigError("providers.json is not valid JSON"))
        let update = ProvidersConfigUpdate.resolve(broken, previous: config([script()]))
        #expect(update.config == config([script()]))
        #expect(update.error == broken.error)
        #expect(update.restarting.isEmpty)
    }

    @Test func aRejectedFileAtLaunchFallsBackToTheBuiltIns() {
        let broken = ProvidersConfigLoad(config: .default, error: ProvidersConfigError("x"))
        #expect(ProvidersConfigUpdate.resolve(broken, previous: nil).config == .default)
    }

    @Test func onlyChangedScriptsRestart() {
        let same = ProvidersConfigUpdate.resolve(ProvidersConfigLoad(config: config([script()]), error: nil), previous: config([script()]))
        #expect(same.restarting.isEmpty)
        let changed = ProvidersConfigUpdate.resolve(ProvidersConfigLoad(config: config([script(interval: 600)]), error: nil), previous: config([script()]))
        #expect(changed.restarting == [kimi])
        #expect(changed.config == config([script(interval: 600)]))
        #expect(changed.error == nil)
        let added = ProvidersConfigUpdate.resolve(ProvidersConfigLoad(config: config([script()]), error: nil), previous: config([]))
        #expect(added.restarting.isEmpty, "a new script has nothing to forget")
    }
}
