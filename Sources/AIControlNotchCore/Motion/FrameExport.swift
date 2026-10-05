import Foundation

/// The scenes `--render-frames` can film.
public enum FilmScene: String, CaseIterable, Sendable {
    /// Claude and Codex at rest.
    case rest
    /// Rest → open panel → rest.
    case open
    /// Claude 40%, Codex 90%, Claude 5h session limit.
    case alerts
    /// The open panel with a third model added by script.
    case models
}

/// Frame `index` of a scene played at `fps`.
public struct FrameClock: Equatable, Sendable {
    public let fps: Int
    public let duration: TimeInterval

    public init(fps: Int, duration: TimeInterval) {
        self.fps = fps
        self.duration = duration
    }

    public var frameCount: Int {
        max(1, Int((duration * Double(fps) - 1e-9).rounded(.up)))
    }

    public func time(of index: Int) -> TimeInterval {
        Double(index) / Double(fps)
    }
}

/// `--render-frames <dir> --scene <name> [--fps 30] [--scale 3] [--lang en|pt]`.
public struct FrameExportOptions: Equatable, Sendable {
    public static let flag = "--render-frames"
    public static let usage = "--render-frames <dir> --scene rest|open|alerts|models [--fps 30] [--scale 3] [--lang en|pt]"
    public static let fpsRange = 1...120
    public static let scaleRange = 1...4

    public let directory: URL
    public let scene: FilmScene
    public let fps: Int
    public let scale: Int
    /// `nil` follows the system language.
    public let language: AppLanguage?

    /// `nil` when anything is missing or out of range (the caller prints `usage`).
    public static func parse(_ args: [String]) -> FrameExportOptions? {
        guard let path = value(after: flag, in: args),
              let scene = value(after: "--scene", in: args).flatMap(FilmScene.init(rawValue:)),
              let fps = number(after: "--fps", in: args, default: 30, range: fpsRange),
              let scale = number(after: "--scale", in: args, default: 3, range: scaleRange)
        else { return nil }
        let language = args.contains("--lang") ? value(after: "--lang", in: args).flatMap(AppLanguage.flag) : nil
        if args.contains("--lang"), language == nil { return nil }
        return FrameExportOptions(
            directory: URL(fileURLWithPath: path, isDirectory: true), scene: scene, fps: fps, scale: scale, language: language
        )
    }

    private static func number(after flag: String, in args: [String], default fallback: Int, range: ClosedRange<Int>) -> Int? {
        guard args.contains(flag) else { return fallback }
        guard let number = value(after: flag, in: args).flatMap(Int.init), range.contains(number) else { return nil }
        return number
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count, !args[index + 1].hasPrefix("--") else { return nil }
        return args[index + 1]
    }
}

extension AppLanguage {
    /// `--lang en` or `--lang pt` (also `pt-BR`).
    public static func flag(_ value: String) -> AppLanguage? {
        switch value.lowercased() {
        case "en": .english
        case "pt", "pt-br": .portuguese
        default: nil
        }
    }
}
