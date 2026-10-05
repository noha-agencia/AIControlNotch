import Foundation

/// Reads `providers.json` field by field so every rejection names the field at fault.
struct ProvidersConfigParser {
    static let defaultInterval: TimeInterval = 300
    static let defaultTimeout: TimeInterval = 15
    static let intervalRange: ClosedRange<Double> = 60...86_400
    static let timeoutRange: ClosedRange<Double> = 1...60
    static let nameLength = 1...24
    static let maxArguments = 32
    static let maxArgumentLength = 1_024

    let home: URL

    func parse(_ data: Data) throws -> ProvidersConfig {
        let object = try Self.topLevel(data)
        let scripts = try scriptList(object["providers"])
        let known = ProviderID.builtIns + scripts.map(\.id)
        let disabled = try Self.ids(object["disabled"], field: "disabled", known: known)
        let enabled = known.filter { !disabled.contains($0) }
        guard !enabled.isEmpty else { throw ProvidersConfigError("at least one model must stay enabled") }
        guard enabled.count <= ProvidersConfig.maxEnabled else {
            throw ProvidersConfigError("at most \(ProvidersConfig.maxEnabled) models can be enabled")
        }
        let pinned = try Self.pinned(object["pinned"], known: known, enabled: enabled)
        return ProvidersConfig(pinned: pinned, disabled: disabled, scripts: scripts)
    }

    // MARK: - Top level

    private static func topLevel(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data) else {
            throw ProvidersConfigError("providers.json is not valid JSON")
        }
        guard let object = value as? [String: Any] else { throw ProvidersConfigError("providers.json must be a JSON object") }
        return object
    }

    private static func ids(_ value: Any?, field: String, known: [ProviderID]) throws -> [ProviderID] {
        guard let value else { return [] }
        guard let strings = value as? [String] else { throw ProvidersConfigError("\(field): expected an array") }
        return try strings.reduce(into: [ProviderID]()) { result, raw in
            guard let id = ProviderID(raw), known.contains(id) else {
                throw ProvidersConfigError("\(field): unknown model \"\(DisplayText.echo(raw))\"")
            }
            guard !result.contains(id) else { throw ProvidersConfigError("\(field): \"\(id.rawValue)\" is repeated") }
            result.append(id)
        }
    }

    /// Disabling a pinned model unpins it; with nothing left pinned, the first enabled ones are.
    private static func pinned(_ value: Any?, known: [ProviderID], enabled: [ProviderID]) throws -> [ProviderID] {
        if let strings = value as? [String], strings.count > ProvidersConfig.maxPinned {
            throw ProvidersConfigError("pinned: at most \(ProvidersConfig.maxPinned) models")
        }
        let pinned = try ids(value, field: "pinned", known: known).filter(enabled.contains)
        return pinned.isEmpty ? Array(enabled.prefix(ProvidersConfig.maxPinned)) : pinned
    }

    // MARK: - Script providers

    private func scriptList(_ value: Any?) throws -> [ScriptProviderConfig] {
        guard let value else { return [] }
        guard let entries = value as? [Any] else { throw ProvidersConfigError("providers: expected an array") }
        return try entries.enumerated().reduce(into: [ScriptProviderConfig]()) { result, item in
            let path = "providers[\(item.offset)]"
            guard let entry = item.element as? [String: Any] else { throw ProvidersConfigError("\(path): expected an object") }
            let script = try self.script(entry, path: path)
            guard !result.contains(where: { $0.id == script.id }) else {
                throw ProvidersConfigError("\(path).id: \"\(script.id.rawValue)\" is repeated")
            }
            result.append(script)
        }
    }

    private func script(_ entry: [String: Any], path: String) throws -> ScriptProviderConfig {
        ScriptProviderConfig(
            id: try Self.id(entry["id"], path: "\(path).id"),
            name: try Self.name(entry["name"], path: "\(path).name"),
            accentHex: try Self.color(entry["color"], path: "\(path).color"),
            command: try command(entry["command"], path: "\(path).command"),
            interval: try Self.number(entry["intervalSeconds"], in: Self.intervalRange, default: Self.defaultInterval, path: "\(path).intervalSeconds"),
            timeout: try Self.number(entry["timeoutSeconds"], in: Self.timeoutRange, default: Self.defaultTimeout, path: "\(path).timeoutSeconds")
        )
    }

    private static func id(_ value: Any?, path: String) throws -> ProviderID {
        guard let value else { throw ProvidersConfigError("\(path): missing") }
        guard let raw = value as? String, let id = ProviderID(raw) else {
            throw ProvidersConfigError("\(path): use 1-32 lowercase letters, digits or dashes")
        }
        guard !id.isBuiltIn else { throw ProvidersConfigError("\(path): \"\(id.rawValue)\" is built in") }
        return id
    }

    private static func name(_ value: Any?, path: String) throws -> String {
        guard let value else { throw ProvidersConfigError("\(path): missing") }
        guard let raw = value as? String, let name = DisplayText.clean(raw, maxCharacters: nameLength.upperBound),
              nameLength.contains(name.count) else {
            throw ProvidersConfigError("\(path): \(nameLength.lowerBound)-\(nameLength.upperBound) characters")
        }
        return name
    }

    private static func color(_ value: Any?, path: String) throws -> String? {
        guard let value else { return nil }
        guard let hex = value as? String, HexColor.isValid(hex) else { throw ProvidersConfigError("\(path): use #RRGGBB") }
        return hex.uppercased()
    }

    private func command(_ value: Any?, path: String) throws -> [String] {
        guard let value else { throw ProvidersConfigError("\(path): missing") }
        guard let parts = value as? [String], !parts.isEmpty, parts.count <= Self.maxArguments else {
            throw ProvidersConfigError("\(path): give the program and its arguments")
        }
        guard parts.allSatisfy({ $0.utf8.count <= Self.maxArgumentLength && !$0.contains("\0") }) else {
            throw ProvidersConfigError("\(path): arguments must be text up to \(Self.maxArgumentLength) characters")
        }
        let expanded = parts.map(expandingHome)
        guard expanded[0].hasPrefix("/") else { throw ProvidersConfigError("\(path): the program needs an absolute path") }
        return expanded
    }

    /// A leading `~/` means the home folder, in the program and in any argument.
    private func expandingHome(_ argument: String) -> String {
        guard argument.hasPrefix("~/") else { return argument }
        return home.appendingPathComponent(String(argument.dropFirst(2))).path
    }

    private static func number(_ value: Any?, in range: ClosedRange<Double>, default fallback: Double, path: String) throws -> Double {
        guard let value else { return fallback }
        guard let number = value as? NSNumber, !JSONValue.isBoolean(number), range.contains(number.doubleValue) else {
            throw ProvidersConfigError("\(path): \(Int(range.lowerBound))-\(Int(range.upperBound))")
        }
        return number.doubleValue
    }
}

/// `#RRGGBB` checks shared by the config and the theme.
public enum HexColor {
    public static func isValid(_ text: String) -> Bool {
        let digits = text.dropFirst()
        return text.hasPrefix("#") && digits.count == 6 && digits.allSatisfy(\.isHexDigit)
    }

    /// Red, green and blue in 0...1, or `nil` for anything but `#RRGGBB`.
    public static func components(_ text: String) -> (red: Double, green: Double, blue: Double)? {
        guard isValid(text), let value = UInt32(text.dropFirst(), radix: 16) else { return nil }
        let channel = { (shift: UInt32) in Double((value >> shift) & 0xFF) / 255 }
        return (channel(16), channel(8), channel(0))
    }
}

enum JSONValue {
    /// `JSONSerialization` hands back `true`/`false` as numbers; they are not numbers here.
    static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
