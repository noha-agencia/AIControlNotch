import AIControlNotchCore
import Foundation

/// `scene.json`: how many frames, their pixel size, and where the hardware notch sits
/// in them, so an editor can place the frames over a screen recording.
struct SceneManifest: Encodable {
    struct Size: Encodable {
        let width: Int
        let height: Int
    }

    struct Rect: Encodable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    struct Change: Encodable {
        let time: Double
        let frame: Int
        let mode: String
    }

    let scene: String
    let language: String
    let fps: Int
    let scale: Int
    let frameCount: Int
    let durationSeconds: Double
    let frames: String
    let frameSize: Size
    /// The camera notch inside each frame, in pixels; the island grows down and sideways from it.
    let notch: Rect
    let modeChanges: [Change]

    @MainActor
    init(options: FrameExportOptions, model: NotchModel, clock: FrameClock, changes: [ModeChange]) {
        let scale = CGFloat(options.scale)
        let canvas = model.canvas
        let notch = model.layout.notch
        self.scene = options.scene.rawValue
        self.language = model.language.rawValue
        self.fps = options.fps
        self.scale = options.scale
        self.frameCount = clock.frameCount
        self.durationSeconds = Double(clock.frameCount) / Double(options.fps)
        self.frames = FrameRenderer.frameName
        self.frameSize = Size(width: Self.pixels(canvas.width, scale), height: Self.pixels(canvas.height, scale))
        self.notch = Rect(
            x: Self.pixels((canvas.width - notch.width) / 2, scale),
            y: 0,
            width: Self.pixels(notch.width, scale),
            height: Self.pixels(notch.height, scale)
        )
        self.modeChanges = changes.map { change in
            Change(
                time: change.time,
                frame: Int((change.time * Double(options.fps)).rounded(.up)),
                mode: Self.name(change.machine.mode)
            )
        }
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    private static func pixels(_ points: CGFloat, _ scale: CGFloat) -> Int {
        Int((points * scale).rounded())
    }

    private static func name(_ mode: NotchMode) -> String {
        switch mode {
        case .rest: "rest"
        case .open: "open"
        case let .alert(alert): "alert \(alert.provider.rawValue) \(alert.kind.key) \(alert.bucket)"
        }
    }
}
