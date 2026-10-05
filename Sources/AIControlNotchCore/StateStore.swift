import Foundation

/// Everything the app remembers between launches.
public struct PersistedState: Codable, Equatable, Sendable {
    public let snapshots: [ProviderID: ProviderSnapshot]
    public let thresholds: ThresholdState
    /// Keyed by `DataSource.rawValue`.
    public let backoff: [String: BackoffState]

    public init(
        snapshots: [ProviderID: ProviderSnapshot] = [:],
        thresholds: ThresholdState = ThresholdState(),
        backoff: [String: BackoffState] = [:]
    ) {
        self.snapshots = snapshots
        self.thresholds = thresholds
        self.backoff = backoff
    }
}

/// Reads and atomically writes `state.json` (owner-only permissions).
public struct StateStore: Sendable {
    private let fileURL: URL
    private let log: LogSink

    public init(fileURL: URL, log: LogSink = NullLog()) {
        self.fileURL = fileURL
        self.log = log
    }

    /// `nil` when there is no saved state yet, or it cannot be read.
    public func load() -> PersistedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try Self.decoder.decode(PersistedState.self, from: data)
        } catch {
            log.log(.warning, "ignoring unreadable \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    public func save(_ state: PersistedState) throws {
        let data = try Self.encoder.encode(state)
        try AtomicFile.write(data, to: fileURL)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}

/// Atomic write that leaves the file readable only by its owner, from its first byte:
/// a private temporary file in the same folder, then a rename over the target. The files
/// are caches, so there is no fsync: readers always see a whole file, old or new.
public enum AtomicFile {
    static let privateFolder = 0o700
    /// A temporary file this old was left by a writer that was stopped mid-way.
    static let staleAfter: TimeInterval = 60

    public static func write(_ data: Data, to url: URL) throws {
        let temporary = try writeTemporary(data, beside: url)
        guard rename(temporary.path, url.path) == 0 else {
            let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            unlink(temporary.path)
            throw failure
        }
        sweepStale(beside: url)
    }

    /// A new owner-only file next to `url` holding `data`; the caller moves or removes it.
    /// `durable` syncs it to disk first, for a file the person wrote and cannot rebuild.
    static func writeTemporary(_ data: Data, beside url: URL, durable: Bool = false) throws -> URL {
        let folder = url.deletingLastPathComponent()
        try makePrivateDirectory(folder)
        let temporary = folder.appendingPathComponent("\(temporaryPrefix(url))\(UUID().uuidString).tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(FilePermissions.ownerOnly))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        do {
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            try handle.write(contentsOf: data)
            if durable { try handle.synchronize() }
            try handle.close()
            return temporary
        } catch {
            unlink(temporary.path)
            throw error
        }
    }

    /// Creates missing folders as owner-only; existing ones are left as they are.
    static func makePrivateDirectory(_ folder: URL) throws {
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: privateFolder]
        )
    }

    private static func temporaryPrefix(_ url: URL) -> String {
        ".\(url.lastPathComponent)."
    }

    /// Removes this file's temporaries that a stopped writer left; fresh ones may be in use.
    static func sweepStale(beside url: URL) {
        let folder = url.deletingLastPathComponent()
        let prefix = temporaryPrefix(url)
        let cutoff = Date().addingTimeInterval(-staleAfter)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix(prefix) && name.hasSuffix(".tmp") {
            let path = folder.appendingPathComponent(name).path
            let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
            if let modified, modified < cutoff { unlink(path) }
        }
    }
}
