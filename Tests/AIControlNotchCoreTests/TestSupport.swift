import Foundation
@testable import AIControlNotchCore

/// Fixed clock and calendar so date-dependent tests do not depend on the machine.
enum TestClock {
    static let timeZone = TimeZone(identifier: "America/Sao_Paulo")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    /// Fri 2026-10-02 15:42 local, the "now" used by the mockup.
    static let now = date(2026, 10, 2, 15, 42)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

extension UsageWindow {
    static func make(
        _ kind: WindowKind = .week,
        used: Double,
        minutes: Int = 10_080,
        resetsAt: Date? = nil
    ) -> UsageWindow {
        UsageWindow(kind: kind, usedPercent: used, durationMinutes: minutes, resetsAt: resetsAt)
    }
}

extension ProviderSnapshot {
    static func make(
        _ provider: ProviderID = .codex,
        windows: [UsageWindow],
        fetchedAt: Date = TestClock.now,
        source: DataSource = .codexAppServer
    ) -> ProviderSnapshot {
        ProviderSnapshot(provider: provider, windows: windows, planLabel: nil, fetchedAt: fetchedAt, source: source)
    }
}

/// A fresh temporary directory, removed by the caller with `cleanup()`.
struct TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aicontrolnotch-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }

    func write(_ text: String, to name: String) throws -> URL {
        let target = file(name)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: target)
        return target
    }

    func cleanup() { try? FileManager.default.removeItem(at: url) }
}

/// Collects log lines in memory.
final class MemoryLog: LogSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] { lock.withLock { storage } }

    func log(_ level: LogLevel, _ message: String) {
        lock.withLock { storage.append("\(level.rawValue) \(message)") }
    }
}

/// A clock tests can move forward.
final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = TestClock.now) { current = start }

    var now: Date { lock.withLock { current } }

    func advance(minutes: Double) {
        lock.withLock { current = current.addingTimeInterval(minutes * 60) }
    }
}
