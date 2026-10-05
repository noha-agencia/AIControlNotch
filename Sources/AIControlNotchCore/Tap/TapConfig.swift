import Foundation

/// `tap.json`: the status line command `aicontrolnotch-tap` wraps, so the user's own line keeps working.
public struct TapConfig: Codable, Equatable, Sendable {
    static let maxBytes = 64 * 1_024

    public let command: String

    public init(command: String) {
        self.command = command
    }

    public static func decode(_ data: Data) throws -> TapConfig {
        guard
            let config = try? JSONDecoder().decode(TapConfig.self, from: data),
            !config.command.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw UsageError.invalidFormat("tap config is unreadable") }
        return config
    }
}
