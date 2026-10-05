import Foundation

/// Mode for files that hold usage data or logs: readable by the user only.
public enum FilePermissions {
    public static let ownerOnly: Int = 0o600
}

/// Every file location the app uses, rooted at an injectable home directory.
public struct Paths: Sendable {
    public let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    /// Roots at `$HOME` when it is an absolute path, like the shells that launch the tap.
    public static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> Paths {
        guard let home = environment["HOME"], home.hasPrefix("/") else { return Paths() }
        return Paths(home: URL(fileURLWithPath: home, isDirectory: true))
    }

    public var supportDirectory: URL {
        home.appendingPathComponent("Library/Application Support/AIControlNotch", isDirectory: true)
    }

    public var stateFile: URL { supportDirectory.appendingPathComponent("state.json") }
    public var statusLineFile: URL { supportDirectory.appendingPathComponent("claude-statusline.json") }
    public var tapConfigFile: URL { supportDirectory.appendingPathComponent("tap.json") }
    public var providersFile: URL { supportDirectory.appendingPathComponent("providers.json") }
    public var binDirectory: URL { supportDirectory.appendingPathComponent("bin", isDirectory: true) }
    public var logFile: URL { home.appendingPathComponent("Library/Logs/AIControlNotch/aicontrolnotch.log") }
    public var codexHome: URL { home.appendingPathComponent(".codex", isDirectory: true) }
}
