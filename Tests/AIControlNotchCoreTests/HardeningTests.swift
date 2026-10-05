import Foundation
import Testing
@testable import AIControlNotchCore

/// Fixes from the code review: hangs, misleading errors, log hygiene and numeric edges.
@Suite struct ProcessRunnerHardeningTests {
    let runner = SystemProcessRunner()
    let shell = URL(fileURLWithPath: "/bin/sh")
    static let largeInput = Data(repeating: 0x61, count: 1 << 20)

    @Test func childIgnoringALargeStdinStillTimesOut() async {
        let started = Date()
        await #expect(throws: UsageError.timeout) {
            _ = try await runner.run(shell, arguments: ["-c", "sleep 5"], stdin: Self.largeInput, timeout: 1)
        }
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test func backgroundedGrandchildDoesNotHoldTheResult() async throws {
        let started = Date()
        let result = try await runner.run(shell, arguments: ["-c", "echo hi; sleep 5 &"], stdin: nil, timeout: 10)
        #expect(String(decoding: result.stdout, as: UTF8.self) == "hi\n")
        #expect(Date().timeIntervalSince(started) < 3)
    }
}

@Suite struct LogHygieneTests {
    @Test func controlCharactersAreFlattenedAndLongMessagesCapped() throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let logger = FileLogger(fileURL: dir.file("app.log"), now: { TestClock.now })
        logger.log(.warning, "a\rb\u{1B}[2Jc\td" + String(repeating: "x", count: 5_000))
        let text = try String(contentsOf: dir.file("app.log"), encoding: .utf8)
        #expect(!text.contains("\r"))
        #expect(!text.contains("\u{1B}"))
        #expect(!text.contains("\t"))
        #expect(text.count < FileLogger.maxMessageLength + 60)
    }

    @Test func codexServerTextNeverReachesTheError() throws {
        let line = Data(#"{"id":2,"error":{"code":-32600,"message":"upstream 401 body: Bearer abc"}}"#.utf8)
        do {
            _ = try CodexRateLimitParser.parseAppServerResponse(line)
            Issue.record("expected an error")
        } catch let error as UsageError {
            #expect(!error.logDescription.contains("Bearer"))
            #expect(error.logDescription.contains("-32600"))
        }
    }
}

@Suite struct NumericEdgeTests {
    @Test func bucketClampsOutOfRangeValues() {
        #expect(ThresholdTracker.bucket(for: 1e300) == 100)
        #expect(ThresholdTracker.bucket(for: -5) == 0)
        #expect(ThresholdTracker.bucket(for: .nan) == 0)
        #expect(ThresholdTracker.bucket(for: .infinity) == 100)
    }

    @Test func hugeRetryAfterIsCapped() {
        let state = PollScheduler().recordFailure(BackoffState(), now: TestClock.now, retryAfter: 1e9)
        #expect(state.nextAllowed == TestClock.now.addingTimeInterval(PollScheduler.maximumRetryAfter))
    }
}

@Suite struct JoinedRefreshTests {
    @Test func onlyTheCallerThatStartedARefreshGetsItsAlerts() async throws {
        let dir = try TempDir()
        defer { dir.cleanup() }
        let clock = MutableClock()
        let reset = TestClock.date(2026, 10, 5, 18, 38)
        let snapshot = { (used: Double) in
            ProviderSnapshot.make(.codex, windows: [.make(.week, used: used, resetsAt: reset)], fetchedAt: clock.now, source: .codexAppServer)
        }
        let primary = StubProvider(.codexAppServer, .success(snapshot(38)))
        let coordinator = RefreshCoordinator(
            sources: [FallbackProvider(primary: primary, fallback: StubProvider(.codexRollout, .failure(.notFound("logs"))))],
            store: StateStore(fileURL: dir.file("state.json")),
            now: { clock.now }
        )
        _ = await coordinator.refresh(manual: false)
        clock.advance(minutes: 5)
        primary.outcome = .success(snapshot(41))
        async let first = coordinator.refresh(manual: true)
        async let second = coordinator.refresh(manual: true)
        let results = await [first, second]
        #expect(results.flatMap(\.alerts).map(\.bucket) == [40])
    }
}
