import AIControlNotchCore
import Foundation
import SwiftUI

/// `--render-frames`: one transparent PNG per frame of a scene (the island only, no
/// wallpaper), moved by the app's own curves, plus `scene.json` describing the frames.
@MainActor
enum FrameRenderer {
    static let frameName = "frame-%04d.png"
    static let manifestName = "scene.json"

    struct Result {
        let folder: URL
        let frameCount: Int
    }

    static func render(_ options: FrameExportOptions) throws -> Result {
        let now = DemoData.mockupNow
        let language = options.language ?? .current
        let script = FilmScript.make(options.scene, now: now, language: language)
        let model = NotchModel(
            layout: NotchLayout(notch: StateRenderer.mockupNotch),
            language: language,
            catalog: script.catalog,
            now: now,
            animated: false
        )
        model.update(snapshots: script.snapshots, issues: [:])
        let changes = SceneRunner.run(script.events, start: now)
        let open = model.openContent
        let timeline = NotchTimeline(
            layout: model.layout, openKind: .open(rows: open.rowCount, sections: open.sections.count), changes: changes
        )
        let clock = FrameClock(fps: options.fps, duration: SceneRunner.end(of: changes, events: script.events, tail: script.tail))
        let folder = options.directory.appendingPathComponent(options.scene.rawValue, isDirectory: true)
        try prepare(folder)
        for index in 0..<clock.frameCount {
            let pose = timeline.pose(at: clock.time(of: index))
            model.apply(pose.machine)
            let url = folder.appendingPathComponent(String(format: frameName, index))
            try PNGWriter.write(NotchRootView(model: model, pose: pose), to: url, scale: CGFloat(options.scale))
        }
        let manifest = SceneManifest(options: options, model: model, clock: clock, changes: changes)
        try manifest.write(to: folder.appendingPathComponent(manifestName))
        return Result(folder: folder, frameCount: clock.frameCount)
    }

    /// Creates the scene folder and clears frames from an earlier, possibly longer, run.
    private static func prepare(_ folder: URL) throws {
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in try files.contentsOfDirectory(atPath: folder.path) where isOurs(name) {
            try files.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    private static func isOurs(_ name: String) -> Bool {
        name == manifestName || name.range(of: #"^frame-\d{4,}\.png$"#, options: .regularExpression) != nil
    }
}
