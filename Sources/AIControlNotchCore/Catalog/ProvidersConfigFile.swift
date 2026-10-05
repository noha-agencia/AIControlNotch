import Foundation

/// The configuration in use and, when the file was rejected, why.
public struct ProvidersConfigLoad: Equatable, Sendable {
    public let config: ProvidersConfig
    public let error: ProvidersConfigError?

    public init(config: ProvidersConfig, error: ProvidersConfigError?) {
        self.config = config
        self.error = error
    }
}

/// `providers.json` on disk. A missing or broken file never stops the app: it falls
/// back to Claude and Codex and reports the reason.
public struct ProvidersConfigFile: Sendable {
    static let maxBytes = 64 * 1_024
    static let template = """
    {
      "pinned": ["claude", "codex"],
      "disabled": [],
      "providers": []
    }

    """

    public let url: URL
    public let home: URL

    public init(url: URL, home: URL) {
        self.url = url
        self.home = home
    }

    /// Changes whenever the file does, permissions included; `nil` when there is none.
    public func fingerprint() -> FileFingerprint? {
        FileFingerprint(of: url)
    }

    /// `providers.json` names programs the app runs, so only a private file the person
    /// owns, in a folder others cannot change, is read.
    public func load() -> ProvidersConfigLoad {
        do {
            guard let data = try ConfigFileReader.read(url, name: "providers.json", maxBytes: Self.maxBytes) else {
                return ProvidersConfigLoad(config: .default, error: nil)
            }
            return ProvidersConfigLoad(config: try ProvidersConfig.parse(data, home: home), error: nil)
        } catch let rejected as ConfigFileRejected {
            return ProvidersConfigLoad(config: .default, error: ProvidersConfigError(rejected.reason))
        } catch let error as ProvidersConfigError {
            return ProvidersConfigLoad(config: .default, error: error)
        } catch {
            return ProvidersConfigLoad(config: .default, error: ProvidersConfigError("providers.json could not be read"))
        }
    }

    /// Writes a starting file (Claude and Codex, no scripts). Returns `false` if one exists,
    /// even one that appeared a moment ago. The file is written aside and synced, then moved
    /// into place whole only if the name is still free: never an empty `providers.json`.
    public func createTemplateIfMissing() throws -> Bool {
        let temporary = try AtomicFile.writeTemporary(Data(Self.template.utf8), beside: url, durable: true)
        guard renamex_np(temporary.path, url.path, UInt32(RENAME_EXCL)) == 0 else {
            let code = errno
            unlink(temporary.path)
            if code == EEXIST { return false }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        AtomicFile.sweepStale(beside: url)
        return true
    }
}
