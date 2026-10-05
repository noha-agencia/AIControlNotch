import Foundation

/// The AI whose plan limits are tracked: a built-in one (Claude, Codex) or a script's slug.
/// Saved as a plain string, so state written by earlier versions keeps loading.
public struct ProviderID: Hashable, Sendable, Codable, CustomStringConvertible {
    static let maxLength = 32

    public let rawValue: String

    /// `nil` unless `rawValue` is 1-32 lowercase letters, digits or dashes, starting with a letter or digit.
    public init?(_ rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    private init(trusted rawValue: String) {
        self.rawValue = rawValue
    }

    public static let claude = ProviderID(trusted: "claude")
    public static let codex = ProviderID(trusted: "codex")
    public static let builtIns: [ProviderID] = [.claude, .codex]

    public var isBuiltIn: Bool { Self.builtIns.contains(self) }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let id = ProviderID(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "invalid provider id")
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func isValid(_ raw: String) -> Bool {
        let scalars = Array(raw.unicodeScalars)
        guard (1...maxLength).contains(scalars.count), let first = scalars.first, isLowerAlphanumeric(first) else {
            return false
        }
        return scalars.allSatisfy { isLowerAlphanumeric($0) || $0 == "-" }
    }

    private static func isLowerAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
    }
}
