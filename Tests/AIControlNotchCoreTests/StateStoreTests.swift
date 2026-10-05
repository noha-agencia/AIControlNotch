import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct StateStoreTests {
    @Test func missingFileLoadsNil() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        #expect(StateStore(fileURL: dir.file("state.json")).load() == nil)
    }

    @Test func roundTrip() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let store = StateStore(fileURL: dir.file("nested/state.json"))
        let snapshot = ProviderSnapshot.make(.claude, windows: [.make(.session, used: 38, minutes: 300, resetsAt: TestClock.now)])
        let state = PersistedState(
            snapshots: [.claude: snapshot],
            thresholds: ThresholdState(entries: ["claude.session": .init(lastNotified: 30, resetsAt: nil, lastUsed: 38)]),
            backoff: ["codexAppServer": BackoffState(failures: 2, nextAllowed: TestClock.now, lastAttempt: TestClock.now)]
        )
        try store.save(state)
        #expect(store.load() == state)
    }

    @Test func fileIsPrivate() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let store = StateStore(fileURL: dir.file("state.json"))
        try store.save(PersistedState())
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.file("state.json").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test func corruptFileLoadsNilAndLogs() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try dir.write("{not json", to: "state.json")
        let log = MemoryLog()
        #expect(StateStore(fileURL: url, log: log).load() == nil)
        #expect(log.lines.contains { $0.contains("state.json") })
    }

    @Test func emptyStateDefaults() {
        let state = PersistedState()
        #expect(state.snapshots.isEmpty)
        #expect(state.thresholds.entries.isEmpty)
        #expect(state.backoff.isEmpty)
    }
}

@Suite struct FileLoggerTests {
    @Test func writesLinesWithLevel() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let logger = FileLogger(fileURL: dir.file("logs/app.log"), now: { TestClock.now })
        logger.log(.info, "claude ok 200 120ms")
        let text = try String(contentsOf: dir.file("logs/app.log"), encoding: .utf8)
        #expect(text.contains("INFO claude ok 200 120ms"))
        #expect(text.hasSuffix("\n"))
    }

    @Test func rotatesAtLimit() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = dir.file("app.log")
        let logger = FileLogger(fileURL: url, maxBytes: 200, now: { TestClock.now })
        for index in 0..<20 { logger.log(.info, "line \(index) padding padding") }
        let rotated = url.appendingPathExtension("1")
        #expect(FileManager.default.fileExists(atPath: rotated.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        #expect(size <= 200)
    }

    @Test func newlinesInMessagesAreFlattened() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let logger = FileLogger(fileURL: dir.file("app.log"), now: { TestClock.now })
        logger.log(.error, "first\nsecond")
        let text = try String(contentsOf: dir.file("app.log"), encoding: .utf8)
        #expect(text.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 1)
    }
}
