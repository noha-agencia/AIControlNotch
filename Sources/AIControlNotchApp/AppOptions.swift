import AIControlNotchCore
import Foundation

/// Command line: normal run, `--demo [--snapshots <dir>]`, `--render-states <dir> [--lang en|pt]`,
/// `--render-frames …` (see `FrameExportOptions`), `--render-icon <dir>`, `--launch-at-login on|off`.
enum AppCommand: Equatable {
    case run(demo: Bool, snapshots: URL?)
    case renderStates(URL, AppLanguage?)
    case renderFrames(FrameExportOptions)
    case renderIcon(URL)
    case launchAtLogin(Bool)
    case invalid(String)

    static let launchAtLoginFlag = "--launch-at-login"
    static let launchAtLoginUsage = "--launch-at-login on|off"
    static let renderStatesUsage = "--render-states <dir> [--lang en|pt]"

    static func parse(_ arguments: [String]) -> AppCommand {
        let args = Array(arguments.dropFirst())
        if args.contains(FrameExportOptions.flag) {
            return FrameExportOptions.parse(args).map(AppCommand.renderFrames) ?? .invalid(FrameExportOptions.usage)
        }
        if let directory = value(after: "--render-states", in: args) { return renderStates(directory, args: args) }
        if let directory = value(after: "--render-icon", in: args) { return directory.map(AppCommand.renderIcon) ?? .invalid("--render-icon <dir>") }
        if let index = args.firstIndex(of: launchAtLoginFlag) { return launchAtLogin(args.dropFirst(index + 1).first) }
        let snapshots = value(after: "--snapshots", in: args) ?? nil
        return .run(demo: args.contains("--demo"), snapshots: snapshots)
    }

    private static func renderStates(_ directory: URL?, args: [String]) -> AppCommand {
        guard let directory else { return .invalid(renderStatesUsage) }
        guard let index = args.firstIndex(of: "--lang") else { return .renderStates(directory, nil) }
        let value = args.dropFirst(index + 1).first
        guard let language = value.flatMap(AppLanguage.flag) else { return .invalid(renderStatesUsage) }
        return .renderStates(directory, language)
    }

    private static func launchAtLogin(_ value: String?) -> AppCommand {
        switch value {
        case "on": .launchAtLogin(true)
        case "off": .launchAtLogin(false)
        default: .invalid(launchAtLoginUsage)
        }
    }

    /// `nil` when the flag is absent; `.some(nil)` when it has no value.
    private static func value(after flag: String, in args: [String]) -> URL?? {
        guard let index = args.firstIndex(of: flag) else { return nil }
        let next = args.index(after: index)
        guard next < args.endIndex, !args[next].hasPrefix("--") else { return .some(nil) }
        return .some(URL(fileURLWithPath: args[next], isDirectory: true))
    }
}
