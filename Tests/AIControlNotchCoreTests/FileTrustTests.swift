import Darwin
import Foundation
import Testing
@testable import AIControlNotchCore

/// Second review round: files the app reads or runs, and the files it leaves behind.
@Suite struct ConfigChangeTests {
    private func file(_ dir: TempDir) -> ProvidersConfigFile {
        ProvidersConfigFile(url: dir.file("providers.json"), home: dir.url)
    }

    @Test func changingOnlyThePermissionsCountsAsAChange() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try dir.write("{}", to: "providers.json")
        let before = try #require(file(dir).fingerprint())
        #expect(file(dir).fingerprint() == before, "an untouched file reads the same")
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        #expect(file(dir).fingerprint() != before, "chmod 600 alone must reload the file")
    }

    @Test func fixingTheFolderCountsAsAChange() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write("{}", to: "providers.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: dir.url.path)
        let before = try #require(file(dir).fingerprint())
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.url.path)
        #expect(file(dir).fingerprint() != before, "chmod on the folder alone must reload the file")
    }

    @Test func theTemplateIsWrittenWholeAndLeavesNothingBehind() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(try file(dir).createTemplateIfMissing())
        #expect(try String(contentsOf: dir.file("providers.json"), encoding: .utf8) == ProvidersConfigFile.template)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.url.path) == ["providers.json"])
    }
}

@Suite struct AtomicFileSweepTests {
    @Test func staleTemporaryFilesAreSweptButFreshOnesStay() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let old = Date().addingTimeInterval(-600)
        let stale = try dir.write("x", to: ".state.json.OLD.tmp")
        _ = try dir.write("x", to: ".state.json.NEW.tmp")
        let otherFile = try dir.write("x", to: ".tap.json.OLD.tmp")
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: stale.path)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: otherFile.path)
        try AtomicFile.write(Data("{}".utf8), to: dir.file("state.json"))
        let names = Set(try FileManager.default.contentsOfDirectory(atPath: dir.url.path))
        #expect(names == ["state.json", ".state.json.NEW.tmp", ".tap.json.OLD.tmp"])
    }
}

@Suite struct ScriptFileTrustTests {
    let kimi = ProviderID("kimi")!

    private func failure(_ command: [String], home: URL) async -> ScriptFailure? {
        let config = ScriptProviderConfig(id: kimi, name: "Kimi", accentHex: nil, command: command, interval: 60, timeout: 10)
        do {
            _ = try await ScriptProvider(config: config, home: home).fetch()
            return nil
        } catch let UsageError.script(failure) {
            return failure
        } catch {
            return nil
        }
    }

    private func script(_ dir: TempDir, _ name: String = "k.sh", mode: Int = 0o755) throws -> URL {
        let url = try dir.write("#!/bin/sh\necho '{\"version\": 1, \"windows\": [{\"durationMinutes\": 300, \"usedPercent\": 1}]}'\n", to: name)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
        return url
    }

    @Test func aPrivateScriptRuns() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(await failure([try script(dir).path], home: dir.url) == nil)
    }

    @Test func aScriptOthersCanChangeIsRefused() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(await failure([try script(dir, mode: 0o775).path], home: dir.url) == .unsafeFile)
    }

    @Test func aScriptPassedToAnInterpreterIsCheckedToo() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try script(dir, mode: 0o666)
        #expect(await failure(["/bin/sh", "k.sh"], home: dir.url) == .unsafeFile, "relative to home, where it runs")
    }

    @Test func aScriptInAFolderOthersCanChangeIsRefused() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try script(dir, "shared/k.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: url.deletingLastPathComponent().path)
        #expect(await failure([url.path], home: dir.url) == .unsafeFile)
    }

    @Test func aSymlinkInAFolderOthersCanChangeIsRefused() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let target = try script(dir)
        let shared = dir.file("shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: shared.appendingPathComponent("k"), withDestinationURL: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: shared.path)
        #expect(await failure([shared.appendingPathComponent("k").path], home: dir.url) == .unsafeFile, "the link can be swapped")
    }

    @Test func aFolderOnlyAdminsCanChangeIsFine() async throws {
        // Homebrew's bin folder is group-writable by admin; admins can already act as root.
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try script(dir, "brew/k.sh")
        let folder = url.deletingLastPathComponent().path
        try #require(chown(folder, uid_t.max, ScriptFileTrust.adminGroup) == 0, "the test user is an admin")
        try FileManager.default.setAttributes([.posixPermissions: 0o775], ofItemAtPath: folder)
        #expect(await failure([url.path], home: dir.url) == nil)
    }

    @Test func plainArgumentsAreNotFiles() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(await failure([try script(dir).path, "--plan", "pro", "/no/such/file"], home: dir.url) == nil)
    }
}
