import Foundation
import Testing
@testable import AIControlNotchCore

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct StatusLineTests {
    let now = Date(timeIntervalSince1970: 1_790_960_000)

    @Test func extractsRateLimitsFromStatusLineInput() throws {
        let record = try #require(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input.json"), now: now))
        #expect(record.capturedAt == now)
        #expect(record.fiveHour == .init(usedPercentage: 38.4, resetsAt: Date(timeIntervalSince1970: 1_790_974_560)))
        #expect(record.sevenDay?.usedPercentage == 58)
    }

    @Test func inputWithoutRateLimitsYieldsNil() throws {
        #expect(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input_no_limits.json"), now: now) == nil)
        #expect(StatusLineRecord.extract(fromStatusLineInput: Data("garbage".utf8), now: now) == nil)
    }

    @Test func recordRoundTripsThroughDisk() throws {
        let record = try #require(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input.json"), now: now))
        #expect(try StatusLineRecord.decode(record.encoded()) == record)
    }

    @Test func recordBecomesWindows() throws {
        let record = try #require(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input.json"), now: now))
        #expect(record.windows.map(\.kind) == [.session, .week])
        #expect(record.windows[0].durationMinutes == 300)
        #expect(record.windows[1].resetsAt == Date(timeIntervalSince1970: 1_791_244_800))
    }

    @Test func providerReadsRecordFile() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let record = try #require(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input.json"), now: now))
        try AtomicFile.write(try record.encoded(), to: dir.file("claude-statusline.json"))
        let snapshot = try await ClaudeStatusLineProvider(fileURL: dir.file("claude-statusline.json")).fetch()
        #expect(snapshot.source == .claudeStatusLine)
        #expect(snapshot.fetchedAt == now)
        #expect(snapshot.windows.count == 2)
    }

    @Test func providerWithoutFileThrowsNotFound() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        await #expect(throws: UsageError.notFound("claude-statusline.json")) {
            _ = try await ClaudeStatusLineProvider(fileURL: dir.file("claude-statusline.json")).fetch()
        }
    }

    @Test func providerWithCorruptFileThrowsInvalidFormat() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try dir.write("{}", to: "claude-statusline.json")
        await #expect(throws: UsageError.invalidFormat("statusline record is unreadable")) {
            _ = try await ClaudeStatusLineProvider(fileURL: url).fetch()
        }
    }

    @Test func providerWithRecordWithoutLimitsThrowsInvalidFormat() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let url = try dir.write(#"{"captured_at": 1790960000, "rate_limits": {}}"#, to: "claude-statusline.json")
        await #expect(throws: UsageError.invalidFormat("statusline record has no limits")) {
            _ = try await ClaudeStatusLineProvider(fileURL: url).fetch()
        }
    }
}

/// The status line file is local and rewritten by every Claude Code update, so a bad read
/// is simply tried again on the next refresh.
@Suite struct ClaudeStatusLineRefreshTests {
    let now = Date(timeIntervalSince1970: 1_790_960_000)

    private func coordinator(_ dir: TempDir, clock: MutableClock) -> RefreshCoordinator {
        RefreshCoordinator(
            sources: [FallbackProvider(primary: ClaudeStatusLineProvider(fileURL: dir.file("claude-statusline.json")))],
            store: StateStore(fileURL: dir.file("state.json")),
            now: { clock.now }
        )
    }

    private func saveRecord(in dir: TempDir, at date: Date) throws {
        let record = try #require(StatusLineRecord.extract(fromStatusLineInput: try fixture("statusline_input.json"), now: date))
        try AtomicFile.write(try record.encoded(), to: dir.file("claude-statusline.json"))
    }

    @Test func unreadableRecordIsRetriedWithoutBackoff() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock(now)
        let coordinator = coordinator(dir, clock: clock)
        _ = try dir.write("{}", to: "claude-statusline.json")
        let broken = await coordinator.refresh(manual: false)
        #expect(broken.issues[.claude] == .noData)
        let backoff = try #require(StateStore(fileURL: dir.file("state.json")).load()?.backoff["claudeStatusLine"])
        #expect(backoff.failures == 0)
        #expect(backoff.nextAllowed == nil)

        clock.advance(minutes: 3)
        try saveRecord(in: dir, at: clock.now)
        let fixed = await coordinator.refresh(manual: false)
        #expect(fixed.snapshots[.claude]?.windows.count == 2)
        #expect(fixed.issues[.claude] == nil)
    }

    @Test func missingRecordIsPickedUpOnTheNextRefresh() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock(now)
        let coordinator = coordinator(dir, clock: clock)
        let missing = await coordinator.refresh(manual: false)
        #expect(missing.issues[.claude] == .noData)

        clock.advance(minutes: 3)
        try saveRecord(in: dir, at: clock.now)
        #expect(await coordinator.refresh(manual: false).snapshots[.claude] != nil)
    }
}
