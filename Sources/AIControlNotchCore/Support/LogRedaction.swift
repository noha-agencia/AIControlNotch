import Foundation

/// Hides what looks like a credential before text from a script reaches the log file.
/// Best effort: the scripts are the person's own, but logs get pasted into issues.
/// Every pattern stays linear: repeats that end a pattern run over one character class,
/// alternatives start with different characters, and the rest are bounded.
public enum LogRedaction {
    static let mask = "[redacted]"

    // Quoted values skip over escapes, so `\"` does not end them.
    private static let doubleQuoted = #""(?:[^"\\\r\n]|\\.)*""#
    private static let singleQuoted = #"'(?:[^'\\\r\n]|\\.)*'"#
    /// A JSON string printed inside another string: `\"value\"`.
    private static let escapedQuoted = #"\\"(?:[^"\\\r\n]|\\[^"\r\n])*\\""#
    /// A quote that never closes hides the rest of the line.
    private static let unclosed = #"["'][^\r\n]*"#
    /// `key: value`, `"key": value`, `\"key\": value`.
    private static let separator = #"(?:\\?["'])?\s*[:=]\s*"#
    /// A name right after `/` or `\` is a file (`/etc/passwd: Permission denied`), not a setting.
    private static let notInPath = #"(?<![/\\])"#

    private static func value(unquoted: String) -> String {
        "(?:\(doubleQuoted)|\(singleQuoted)|\(escapedQuoted)|\(unclosed)|\(unquoted))"
    }

    private static let rules: [(NSRegularExpression, String)] = [
        (#"-----BEGIN[A-Z ]{0,32}PRIVATE KEY-----[\s\S]*?(?:-----END[A-Z ]{0,32}PRIVATE KEY-----|$)"#, mask),
        // Whole header values: `Authorization: Basic …`, `Cookie: a=b; c=d`.
        (#"(?i)\b((?:authorization|proxy-authorization|(?:set-)?cookie)"# + separator + ")" + value(unquoted: #"[^\r\n]+"#),
         "$1\(mask)"),
        // Passwords may hold spaces: everything up to the end of the value.
        ("(?i)" + notInPath + "((?:password|passwd|passphrase|pwd)" + separator + ")" + value(unquoted: #"[^\r\n"',;&}\]]+"#),
         "$1\(mask)"),
        // `api_key=…`, `apiKey: …`, `"access_token":"…"`, `token: Bearer …`. No word boundary,
        // so camelCase counts. Passwords are left to the rule above, so nothing is masked twice.
        ("(?i)" + notInPath + "((?:key|token|secret|credentials?|sessionid)" + separator + #"(?:(?:bearer|basic)\s+)?)"#
            + value(unquoted: #"[^\s&"',;}\]]+"#), "$1\(mask)"),
        // `--token value`, `--api-key "value"`.
        (#"(?i)(?<![A-Za-z0-9_-])(--?[a-z0-9-]{0,32}(?:key|token|secret|password|passwd|passphrase)\s+)"#
            + "(?:\(doubleQuoted)|\(singleQuoted)|[^\\s\"']+)", "$1\(mask)"),
        // `https://user:secret@host`.
        (#"(?i)\b([a-z][a-z0-9+.-]{1,16}://[^\s/:@]{1,256}:)[^\s/@]{1,256}@"#, "$1\(mask)@"),
        (#"(?i)\b(bearer\s+)[A-Za-z0-9._~+/=-]+"#, "$1\(mask)"),
        // Well-known token shapes, wherever they appear.
        (#"\bsk-[A-Za-z0-9_-]{6,}"#, mask),
        (#"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"#, mask),
        (#"\b(?:hf|gsk|npm)_[A-Za-z0-9]{20,}"#, mask),
        (#"\bxai-[A-Za-z0-9]{20,}"#, mask),
        (#"\bya29\.[A-Za-z0-9_-]{20,}"#, mask),
        (#"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#, mask),
        (#"\bxox[abposr]-[A-Za-z0-9-]{10,}"#, mask),
        (#"\bAIza[0-9A-Za-z_-]{35}"#, mask),
        // A JWT: three dot-separated parts. It must start a word, or a long run of `-eyJ`
        // would be tried from every position.
        (#"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*"#, mask),
    ].map { pattern, template in
        // The patterns are constants; failing to compile one is a programming error.
        (try! NSRegularExpression(pattern: pattern), template)
    }

    public static func redact(_ text: String) -> String {
        rules.reduce(text) { result, rule in
            let range = NSRange(result.startIndex..., in: result)
            return rule.0.stringByReplacingMatches(in: result, range: range, withTemplate: rule.1)
        }
    }
}
