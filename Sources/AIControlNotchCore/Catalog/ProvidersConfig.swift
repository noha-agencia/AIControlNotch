import Foundation

/// Why `providers.json` was rejected, in plain words with the field path.
public struct ProvidersConfigError: Error, Equatable, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

/// One model read by running a local program that prints JSON.
public struct ScriptProviderConfig: Equatable, Sendable {
    public let id: ProviderID
    public let name: String
    /// `#RRGGBB` in upper case, or `nil` for the default accent.
    public let accentHex: String?
    /// Absolute program path followed by its arguments. Never run through a shell.
    public let command: [String]
    /// Minimum seconds between two runs.
    public let interval: TimeInterval
    public let timeout: TimeInterval

    public init(id: ProviderID, name: String, accentHex: String?, command: [String], interval: TimeInterval, timeout: TimeInterval) {
        self.id = id
        self.name = name
        self.accentHex = accentHex
        self.command = command
        self.interval = interval
        self.timeout = timeout
    }
}

/// The validated contents of `providers.json`.
public struct ProvidersConfig: Equatable, Sendable {
    public static let maxPinned = 2
    public static let maxEnabled = 6

    public let pinned: [ProviderID]
    public let disabled: [ProviderID]
    public let scripts: [ScriptProviderConfig]

    public init(pinned: [ProviderID], disabled: [ProviderID], scripts: [ScriptProviderConfig]) {
        self.pinned = pinned
        self.disabled = disabled
        self.scripts = scripts
    }

    /// No file: Claude and Codex, both pinned.
    public static let `default` = ProvidersConfig(pinned: ProviderID.builtIns, disabled: [], scripts: [])

    /// Every configured model: built-ins first, then scripts in file order.
    public var allIDs: [ProviderID] { ProviderID.builtIns + scripts.map(\.id) }
    public var enabledIDs: [ProviderID] { allIDs.filter { !disabled.contains($0) } }
    public var enabledScripts: [ScriptProviderConfig] { scripts.filter { !disabled.contains($0.id) } }

    /// `home` expands a leading `~/` in script paths.
    public static func parse(_ data: Data, home: URL) throws -> ProvidersConfig {
        try ProvidersConfigParser(home: home).parse(data)
    }
}
