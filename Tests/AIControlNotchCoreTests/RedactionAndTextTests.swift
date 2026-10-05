import Foundation
import Testing
@testable import AIControlNotchCore

/// Second review round: credential shapes the log missed, slow patterns, and text that
/// looks empty or stacks marks in the notch.
@Suite struct RedactionShapesTests {
    @Test(arguments: [
        (#"{"access_token":"abc123"}"#, #"{"access_token":[redacted]}"#),
        (#"{'password':'x y'}"#, #"{'password':[redacted]}"#),
        ("apiKey=abc123", "apiKey=[redacted]"),
        ("accessToken: abc123", "accessToken: [redacted]"),
        ("clientSecret=abc123", "clientSecret=[redacted]"),
        ("Authorization: Basic dXNlcjpwYXNz", "Authorization: [redacted]"),
        (#""Authorization": "Bearer abc""#, #""Authorization": [redacted]"#),
        ("run --token abc123 now", "run --token [redacted] now"),
        ("pat ghp_" + String(repeating: "A1", count: 18), "pat [redacted]"),
        ("AKIAABCDEFGHIJKLMNOP leaked", "[redacted] leaked"),
        ("jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig_123", "jwt [redacted]"),
        ("password: two words", "password: [redacted]"),
        ("Cookie: a=b; c=d", "Cookie: [redacted]"),
        ("got bearer xyz from cache", "got bearer [redacted] from cache"),
        ("token expired, sign in again", "token expired, sign in again"),
        ("basic usage limit reached", "basic usage limit reached"),
        ("Authorization: Bearer " + String(repeating: "t", count: 1_500) + " tail", "Authorization: [redacted]"),
        ("access_token=" + String(repeating: "t", count: 700), "access_token=[redacted]"),
        ("token: Bearer opaque123", "token: Bearer [redacted]"),
        (#"--api-key "abc def" -v"#, "--api-key [redacted] -v"),
        ("--token 'abc' -v", "--token [redacted] -v"),
        (#"password="abc"#, "password=[redacted]"),
        (#"{"password":"abc\"def"}"#, #"{"password":[redacted]}"#),
        (#"{\"password\":\"x\"}"#, #"{\"password\":[redacted]}"#),
        (#"Cookie: s="abc"; x=1"#, "Cookie: [redacted]"),
        ("fetch https://me:s3cret@host/x failed", "fetch https://me:[redacted]@host/x failed"),
        ("hf_" + String(repeating: "a", count: 30), "[redacted]"),
        ("gsk_" + String(repeating: "a", count: 30), "[redacted]"),
        ("-----BEGIN PRIVATE KEY-----\nMIIEv\n-----END PRIVATE KEY----- done", "[redacted] done"),
        ("cat: /etc/passwd: Permission denied", "cat: /etc/passwd: Permission denied"),
        ("cat: /Users/me/.config/x/token: No such file or directory", "cat: /Users/me/.config/x/token: No such file or directory"),
    ])
    func hidesMoreCredentialShapes(input: String, expected: String) {
        #expect(LogRedaction.redact(input) == expected)
    }

    @Test(arguments: [
        String(repeating: "a-", count: 32_768),
        String(repeating: "ab_", count: 21_846),
        String(repeating: "key", count: 21_846),
        String(repeating: "--a", count: 21_846),
        String(repeating: "eyJaaaaa", count: 8_192),
        "password=" + String(repeating: "x", count: 65_000),
        String(repeating: "-eyJ", count: 16_384),
        String(repeating: "token=\"", count: 9_362),
        String(repeating: "https://a:", count: 6_554),
        String(repeating: "-----BEGIN PRIVATE KEY-----", count: 2_427),
    ])
    func longLinesStayFast(input: String) {
        let started = Date()
        _ = LogRedaction.redact(input)
        #expect(Date().timeIntervalSince(started) < 1, "64 KB of stderr must not stall a thread")
    }

    @Test func stderrIsCutBeforeItIsSearched() {
        let preview = ScriptProvider.preview(ofStderr: Data(String(repeating: "a-", count: 32_768).utf8))
        #expect(preview.count <= ScriptProvider.stderrPreview)
        #expect(ScriptProvider.preview(ofStderr: Data("  token=abc\n".utf8)) == "token=[redacted]")
    }
}

@Suite struct DisplayTextReviewTests {
    @Test(arguments: [
        "\u{3164}\u{3164}\u{3164}",   // Hangul filler: a letter that draws nothing
        "\u{200D}",                   // a joiner alone
        "\u{2800}\u{2800}",           // Braille blank
        "a\u{FFFF}",                  // noncharacter
        "a\u{0378}",                  // unassigned
        "e\u{0301}\u{0301}\u{0301}\u{0301}\u{0301}", // marks stacked on one letter
    ])
    func blankLookingOrStackedTextIsRejected(text: String) {
        #expect(DisplayText.clean(text, maxCharacters: 24) == nil)
    }

    @Test(arguments: [
        "Vie\u{0323}\u{0302}t",  // two marks, decomposed
        "👨‍👩‍👧‍👦",
        "🇧🇷",
        "1️⃣",
        "हिन्दी",
        "ที่นี่",
        "Pró 🚀",
        "日本語",
        "한국어",
    ])
    func realWritingStillPasses(text: String) {
        #expect(DisplayText.clean(text, maxCharacters: 24) == text)
    }

    @Test func blankStaysBlank() {
        #expect(DisplayText.clean("   ", maxCharacters: 24) == "")
    }

    @Test func echoIsBoundedInScalarsToo() {
        let echoed = DisplayText.echo("e" + String(repeating: "\u{0301}", count: 60_000))
        #expect(echoed.unicodeScalars.count <= DisplayText.maxScalars + 1)
    }
}
