import Testing
@testable import AIControlNotchCore

@Suite struct ClientVersionTests {
    @Test(arguments: ["0.1.0", "1.2.3-beta.1", "2.0+build.7"])
    func keepsAPlainVersion(_ raw: String) {
        #expect(ClientVersion.sanitized(raw) == raw)
    }

    @Test(arguments: [nil, "", "1.0\r\nX-Evil: 1", "1.0 beta", "1.0\"", "1.0\\", "versão", String(repeating: "9", count: 33)])
    func fallsBackToDevForAnythingElse(_ raw: String?) {
        #expect(ClientVersion.sanitized(raw) == "dev", "the version goes into the Codex handshake JSON")
    }
}
