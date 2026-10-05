import Foundation

/// Everything the notch shows about a model besides its numbers.
public struct ProviderDescriptor: Equatable, Sendable {
    public static let defaultScriptAccent = "#A9B4C8"

    public let id: ProviderID
    public let displayName: String
    /// `#RRGGBB`, used for the ruler, the ring and the monogram.
    public let accentHex: String
    /// The letter drawn for the model. No third-party mark is bundled, built-ins included.
    public let monogram: String
    public let isScript: Bool

    public static let claude = ProviderDescriptor(
        id: .claude, displayName: "Claude", accentHex: "#D97757", monogram: "C", isScript: false
    )
    public static let codex = ProviderDescriptor(
        id: .codex, displayName: "Codex", accentHex: "#56C9A2", monogram: "C", isScript: false
    )

    static func builtIn(_ id: ProviderID) -> ProviderDescriptor {
        switch id {
        case .claude: .claude
        case .codex: .codex
        default: fallback(id)
        }
    }

    static func script(_ config: ScriptProviderConfig) -> ProviderDescriptor {
        ProviderDescriptor(
            id: config.id,
            displayName: config.name,
            accentHex: config.accentHex ?? defaultScriptAccent,
            monogram: initial(config.name),
            isScript: true
        )
    }

    /// A model that is no longer configured but still has data or alerts around.
    static func fallback(_ id: ProviderID) -> ProviderDescriptor {
        ProviderDescriptor(
            id: id, displayName: id.rawValue, accentHex: defaultScriptAccent,
            monogram: initial(id.rawValue), isScript: true
        )
    }

    private static func initial(_ name: String) -> String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}
