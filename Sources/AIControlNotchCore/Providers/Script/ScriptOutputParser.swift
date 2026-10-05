import Foundation

/// Reads what a script prints (version 1). Anything out of its domain is
/// rejected with the field at fault; a number is never guessed.
enum ScriptOutputParser {
    static let version = 1
    static let maxWindows = 4
    static let durationRange = 1...525_600
    static let maxTextLength = 24
    /// Past this a number is a bug in the script, not a use level.
    static let maxPercent = 1_000.0

    static func parse(_ data: Data, provider: ProviderID, now: Date) throws -> ProviderSnapshot {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ScriptFailure.invalidOutput("JSON")
        }
        guard let version = object["version"] as? NSNumber, !JSONValue.isBoolean(version), version.intValue == Self.version,
              version.doubleValue == Double(Self.version) else {
            throw ScriptFailure.invalidOutput("version")
        }
        guard let entries = object["windows"] as? [Any], (1...maxWindows).contains(entries.count) else {
            throw ScriptFailure.invalidOutput("windows")
        }
        let windows = try entries.enumerated().reduce(into: [UsageWindow]()) { result, item in
            let path = "windows[\(item.offset)]"
            let window = try Self.window(item.element, path: path)
            // Alerts and rows are keyed by window length, so each length class appears once.
            if let earlier = result.firstIndex(where: { $0.kind == window.kind }) {
                throw ScriptFailure.invalidOutput("\(path).durationMinutes, same length as windows[\(earlier)]")
            }
            result.append(window)
        }
        return ProviderSnapshot(
            provider: provider,
            windows: windows,
            planLabel: try text(object["plan"], path: "plan"),
            fetchedAt: now,
            source: .script
        )
    }

    private static func window(_ value: Any, path: String) throws -> UsageWindow {
        guard let entry = value as? [String: Any] else { throw ScriptFailure.invalidOutput(path) }
        let minutes = try duration(entry["durationMinutes"], path: "\(path).durationMinutes")
        return UsageWindow(
            kind: WindowClassifier.kind(minutes: minutes),
            usedPercent: try usedPercent(entry["usedPercent"], path: "\(path).usedPercent"),
            durationMinutes: minutes,
            resetsAt: try resetsAt(entry["resetsAt"], path: "\(path).resetsAt"),
            label: try text(entry["label"], path: "\(path).label")
        )
    }

    private static func duration(_ value: Any?, path: String) throws -> Int {
        // `Int(exactly:)` refuses fractions and values past Int; `intValue` would wrap them.
        guard let number = value as? NSNumber, !JSONValue.isBoolean(number),
              let minutes = Int(exactly: number.doubleValue), durationRange.contains(minutes) else {
            throw ScriptFailure.invalidOutput(path)
        }
        return minutes
    }

    private static func usedPercent(_ value: Any?, path: String) throws -> Double {
        guard let number = value as? NSNumber, !JSONValue.isBoolean(number), (0...maxPercent).contains(number.doubleValue) else {
            throw ScriptFailure.invalidOutput(path)
        }
        return number.doubleValue
    }

    private static func resetsAt(_ value: Any?, path: String) throws -> Date? {
        guard let value, !(value is NSNull) else { return nil }
        guard let text = value as? String, let date = ISODate.parse(text) else { throw ScriptFailure.invalidOutput(path) }
        return date
    }

    /// Optional short visible text (`DisplayText` rules); blank means absent.
    private static func text(_ value: Any?, path: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let raw = value as? String, let text = DisplayText.clean(raw, maxCharacters: maxTextLength) else {
            throw ScriptFailure.invalidOutput(path)
        }
        return text.isEmpty ? nil : text
    }
}
