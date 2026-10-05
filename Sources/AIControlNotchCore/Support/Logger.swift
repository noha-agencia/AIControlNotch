import Foundation

public enum LogLevel: String, Sendable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// Destination for operational log lines. Callers pass short facts
/// (source, error kind, duration), never tokens or response bodies.
public protocol LogSink: Sendable {
    func log(_ level: LogLevel, _ message: String)
}

/// Discards everything. Default for components created without a logger.
public struct NullLog: LogSink {
    public init() {}
    public func log(_ level: LogLevel, _ message: String) {}
}

/// Appends lines to a file and rotates it to `<name>.1` past `maxBytes`.
public final class FileLogger: LogSink, @unchecked Sendable {
    public static let defaultMaxBytes = 1_048_576

    private let fileURL: URL
    private let maxBytes: Int
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public init(fileURL: URL, maxBytes: Int = FileLogger.defaultMaxBytes, now: @escaping @Sendable () -> Date = Date.init) {
        self.fileURL = fileURL
        self.maxBytes = maxBytes
        self.now = now
    }

    static let maxMessageLength = 300

    public func log(_ level: LogLevel, _ message: String) {
        let flat = Self.sanitized(message)
        lock.withLock {
            let line = "\(formatter.string(from: now())) \(level.rawValue) \(flat)\n"
            append(Data(line.utf8))
        }
    }

    /// One line, no control characters (newlines, CR, terminal escapes), bounded length.
    static func sanitized(_ message: String) -> String {
        let scalars = message.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : $0 }
        let flat = String(String.UnicodeScalarView(scalars))
        return flat.count > maxMessageLength ? String(flat.prefix(maxMessageLength)) + "…" : flat
    }

    private func append(_ data: Data) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            rotateIfNeeded(adding: data.count)
            if !manager.fileExists(atPath: fileURL.path) {
                manager.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: FilePermissions.ownerOnly])
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Logging must never take the app down; report to stderr instead.
            FileHandle.standardError.write(Data("log write failed: \(error)\n".utf8))
        }
    }

    private func rotateIfNeeded(adding count: Int) {
        let manager = FileManager.default
        let size = (try? manager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0, size + count > maxBytes else { return }
        let rotated = fileURL.appendingPathExtension("1")
        try? manager.removeItem(at: rotated)
        try? manager.moveItem(at: fileURL, to: rotated)
    }
}
