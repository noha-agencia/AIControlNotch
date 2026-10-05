/// The app version sent in the Codex handshake.
public enum ClientVersion {
    static let fallback = "dev"
    static let maxLength = 32

    /// Keeps a plain version (letters, digits, `.`, `+`, `-`); anything else becomes "dev",
    /// so the value is always safe inside a JSON string.
    public static func sanitized(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty, raw.count <= maxLength,
              raw.unicodeScalars.allSatisfy(isAllowed) else { return fallback }
        return raw
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) || ".+-".unicodeScalars.contains(scalar))
    }
}
