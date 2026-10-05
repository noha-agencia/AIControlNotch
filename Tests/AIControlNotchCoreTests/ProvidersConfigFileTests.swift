import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ProvidersConfigFileTests {
    private func file(_ dir: TempDir) -> ProvidersConfigFile {
        ProvidersConfigFile(url: dir.file("providers.json"), home: dir.url)
    }

    @Test func missingFileMeansTheBuiltIns() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let loaded = file(dir).load()
        #expect(loaded.config == .default)
        #expect(loaded.error == nil)
        #expect(file(dir).fingerprint() == nil)
    }

    @Test func invalidFileFallsBackAndExplains() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write(#"{"pinned": ["gemini"]}"#, to: "providers.json")
        let loaded = file(dir).load()
        #expect(loaded.config == .default)
        #expect(loaded.error == ProvidersConfigError("pinned: unknown model \"gemini\""))
    }

    @Test func oversizedFileIsRefused() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write("{\"x\": \"\(String(repeating: "a", count: 70_000))\"}", to: "providers.json")
        #expect(file(dir).load().error == ProvidersConfigError("providers.json is larger than 64 KB"))
    }

    @Test func readsAValidFile() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        _ = try dir.write(#"{"providers": [{"id": "kimi", "name": "Kimi", "command": ["~/bin/k"]}]}"#, to: "providers.json")
        let loaded = file(dir).load()
        #expect(loaded.error == nil)
        #expect(loaded.config.scripts.first?.command == [dir.url.appendingPathComponent("bin/k").path])
        #expect(file(dir).fingerprint() != nil)
    }

    @Test func templateIsCreatedOnceAndParses() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(try file(dir).createTemplateIfMissing())
        #expect(file(dir).load() == ProvidersConfigLoad(config: .default, error: nil))
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.file("providers.json").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(try !file(dir).createTemplateIfMissing())
    }
}
