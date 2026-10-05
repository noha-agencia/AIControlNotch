import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct ProviderIDTests {
    @Test(arguments: ["claude", "codex", "kimi", "grok-2", "a", "0x", String(repeating: "a", count: 32)])
    func acceptsSlugs(_ slug: String) {
        #expect(ProviderID(slug)?.rawValue == slug)
    }

    @Test(arguments: ["", "Kimi", "-kimi", "kimi_2", "kimi 2", "kimi.sh", "../x", "ç", String(repeating: "a", count: 33)])
    func rejectsAnythingElse(_ slug: String) {
        #expect(ProviderID(slug) == nil)
    }

    @Test func builtInsKeepTheirOrder() {
        #expect(ProviderID.builtIns == [.claude, .codex])
        #expect(ProviderID.claude.isBuiltIn)
        #expect(ProviderID("kimi")?.isBuiltIn == false)
    }

    @Test func encodesAsAPlainString() throws {
        let data = try JSONEncoder().encode([ProviderID.claude])
        #expect(String(decoding: data, as: UTF8.self) == #"["claude"]"#)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([ProviderID].self, from: Data(#"["Bad Id"]"#.utf8)) }
    }

    /// state.json written before providers were open keeps loading.
    @Test func readsTheSavedStateFormat() throws {
        let legacy = #"{"backoff":{},"snapshots":["claude",{"fetchedAt":1790970000,"planLabel":"Max","provider":"claude","source":"claudeStatusLine","windows":[{"durationMinutes":300,"kind":{"session":{}},"resetsAt":1790977000,"usedPercent":38}]}],"thresholds":{"entries":{}}}"#
        let state = try StateStore.decoder.decode(PersistedState.self, from: Data(legacy.utf8))
        #expect(state.snapshots[.claude]?.windows.first?.usedPercent == 38)
        #expect(state.snapshots[.claude]?.windows.first?.label == nil)
        let again = try StateStore.decoder.decode(PersistedState.self, from: StateStore.encoder.encode(state))
        #expect(again == state)
    }
}

@Suite struct ProvidersConfigTests {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)

    private func parse(_ json: String) throws -> ProvidersConfig {
        try ProvidersConfig.parse(Data(json.utf8), home: home)
    }

    private func message(_ json: String) -> String? {
        do {
            _ = try parse(json)
            return nil
        } catch let error as ProvidersConfigError {
            return error.message
        } catch {
            return "unexpected \(error)"
        }
    }

    @Test func emptyObjectMeansTheBuiltIns() throws {
        #expect(try parse("{}") == .default)
        #expect(ProvidersConfig.default.pinned == [.claude, .codex])
        #expect(ProvidersConfig.default.scripts.isEmpty)
    }

    @Test func readsAScriptProvider() throws {
        let config = try parse("""
        {"pinned": ["claude", "kimi"], "disabled": ["codex"],
         "providers": [{"id": "kimi", "name": " Kimi ", "color": "#5b8cff",
                        "command": ["~/bin/kimi-usage.sh", "--json"], "intervalSeconds": 600, "timeoutSeconds": 20}]}
        """)
        #expect(config.pinned == [.claude, ProviderID("kimi")!])
        #expect(config.disabled == [.codex])
        let script = try #require(config.scripts.first)
        #expect(script.id.rawValue == "kimi")
        #expect(script.name == "Kimi")
        #expect(script.accentHex == "#5B8CFF")
        #expect(script.command == ["/Users/someone/bin/kimi-usage.sh", "--json"])
        #expect(script.interval == 600)
        #expect(script.timeout == 20)
    }

    @Test func defaultsForIntervalTimeoutAndColor() throws {
        let config = try parse(#"{"providers": [{"id": "kimi", "name": "Kimi", "command": ["/bin/kimi"]}]}"#)
        let script = try #require(config.scripts.first)
        #expect(script.interval == 300)
        #expect(script.timeout == 15)
        #expect(script.accentHex == nil)
        #expect(config.pinned == [.claude, .codex], "pinned defaults to the first two enabled")
    }

    @Test func pinnedDefaultsSkipDisabledModels() throws {
        let config = try parse(#"{"disabled": ["claude"], "providers": [{"id": "kimi", "name": "Kimi", "command": ["/bin/kimi"]}]}"#)
        #expect(config.pinned == [.codex, ProviderID("kimi")!])
    }

    @Test(arguments: [
        ("[]", "providers.json must be a JSON object"),
        ("{not json", "providers.json is not valid JSON"),
        (#"{"pinned": "claude"}"#, "pinned: expected an array"),
        (#"{"pinned": ["claude", "codex", "claude"]}"#, "pinned: at most 2 models"),
        (#"{"pinned": ["gemini"]}"#, "pinned: unknown model \"gemini\""),
        (#"{"disabled": ["claude", "codex"]}"#, "at least one model must stay enabled"),
        (#"{"providers": [{"id": "Kimi", "name": "Kimi", "command": ["/bin/k"]}]}"#, "providers[0].id: use 1-32 lowercase letters, digits or dashes"),
        (#"{"providers": [{"id": "claude", "name": "C", "command": ["/bin/k"]}]}"#, "providers[0].id: \"claude\" is built in"),
        (#"{"providers": [{"id": "k", "name": "K", "command": ["/bin/k"]}, {"id": "k", "name": "K", "command": ["/bin/k"]}]}"#, "providers[1].id: \"k\" is repeated"),
        (#"{"providers": [{"id": "k", "name": "  ", "command": ["/bin/k"]}]}"#, "providers[0].name: 1-24 characters"),
        (#"{"providers": [{"id": "k", "name": "K", "color": "blue", "command": ["/bin/k"]}]}"#, "providers[0].color: use #RRGGBB"),
        (#"{"providers": [{"id": "k", "name": "K", "command": []}]}"#, "providers[0].command: give the program and its arguments"),
        (#"{"providers": [{"id": "k", "name": "K", "command": ["kimi.sh"]}]}"#, "providers[0].command: the program needs an absolute path"),
        (#"{"providers": [{"id": "k", "name": "K", "command": ["/bin/k"], "intervalSeconds": 30}]}"#, "providers[0].intervalSeconds: 60-86400"),
        (#"{"providers": [{"id": "k", "name": "K", "command": ["/bin/k"], "timeoutSeconds": 61}]}"#, "providers[0].timeoutSeconds: 1-60"),
        (#"{"providers": [{"name": "K", "command": ["/bin/k"]}]}"#, "providers[0].id: missing"),
    ])
    func explainsWhatIsWrong(json: String, expected: String) {
        #expect(message(json) == expected)
    }

    @Test func atMostSixEnabledModels() {
        let scripts = (1...5).map { #"{"id": "m\#($0)", "name": "M\#($0)", "command": ["/bin/m"]}"# }.joined(separator: ",")
        #expect(message(#"{"providers": [\#(scripts)]}"#) == "at most 6 models can be enabled")
        #expect(message(#"{"disabled": ["codex"], "providers": [\#(scripts)]}"#) == nil)
    }
}

@Suite struct ProviderCatalogTests {
    let kimi = ProviderID("kimi")!
    let grok = ProviderID("grok")!

    private func config(pinned: [ProviderID]? = nil, disabled: [ProviderID] = []) throws -> ProvidersConfig {
        let pinnedJSON = pinned.map { #""pinned": [\#($0.map { "\"\($0.rawValue)\"" }.joined(separator: ","))],"# } ?? ""
        let disabledJSON = disabled.map { "\"\($0.rawValue)\"" }.joined(separator: ",")
        return try ProvidersConfig.parse(Data("""
        {\(pinnedJSON) "disabled": [\(disabledJSON)], "providers": [
          {"id": "grok", "name": "Grok", "command": ["/bin/grok"]},
          {"id": "kimi", "name": "Kimi", "color": "#5B8CFF", "command": ["/bin/kimi"]}]}
        """.utf8), home: URL(fileURLWithPath: "/tmp"))
    }

    @Test func builtInCatalog() {
        let catalog = ProviderCatalog.builtIn
        #expect(catalog.ids == [.claude, .codex])
        #expect(catalog.pinned == [.claude, .codex])
        #expect(catalog.descriptor(.claude) == .claude)
    }

    @Test func builtInsUseAMonogramNotATrademark() {
        #expect(ProviderDescriptor.claude.monogram == "C")
        #expect(ProviderDescriptor.codex.monogram == "C")
    }

    @Test func pinnedComeFirstThenConfigOrder() throws {
        let catalog = ProviderCatalog(config: try config(pinned: [kimi, .claude]))
        #expect(catalog.ids == [kimi, .claude, .codex, grok])
        #expect(catalog.pinned == [kimi, .claude])
    }

    @Test func disabledModelsLeave() throws {
        let catalog = ProviderCatalog(config: try config(disabled: [.codex, grok]))
        #expect(catalog.ids == [.claude, kimi])
        #expect(catalog.pinned == [.claude, kimi])
    }

    @Test func scriptDescriptorsUseAMonogram() throws {
        let catalog = ProviderCatalog(config: try config())
        let descriptor = catalog.descriptor(kimi)
        #expect(descriptor.displayName == "Kimi")
        #expect(descriptor.accentHex == "#5B8CFF")
        #expect(descriptor.monogram == "K")
        #expect(descriptor.isScript)
        #expect(catalog.descriptor(grok).accentHex == ProviderDescriptor.defaultScriptAccent)
    }

    @Test func unknownIDsStillGetADescriptor() {
        let stray = ProviderID("old-model")!
        #expect(ProviderCatalog.builtIn.descriptor(stray).displayName == "old-model")
        #expect(ProviderCatalog.builtIn.descriptor(stray).monogram == "O")
    }
}
