import AIControlNotchCore
import SwiftUI

/// `--render-states <dir>`: one PNG per notch state over the mockup's wallpaper,
/// for checking the build against the approved mockup.
@MainActor
enum StateRenderer {
    static let mockupNotch = CGSize(width: 190, height: 32)

    static func render(to directory: URL, language: AppLanguage = .current) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = DemoData.mockupNow
        let alerts = DemoData.alerts(now: now)
        let states: [(String, NotchMachine)] = [
            ("rest", NotchMachine()),
            ("open", NotchMachine().hover(true, now: now)),
            ("alert-claude-40", NotchMachine().enqueue([alerts[0]], now: now)),
            ("alert-codex-90", NotchMachine().enqueue([alerts[1]], now: now)),
            ("alert-codex-100", NotchMachine().enqueue([alerts[2]], now: now)),
        ]
        for (name, machine) in states {
            let model = NotchModel(layout: NotchLayout(notch: mockupNotch), language: language, now: now, animated: false)
            model.update(snapshots: DemoData.snapshots(now: now), issues: [:])
            model.apply(machine)
            try PNGWriter.write(Wallpaper { NotchRootView(model: model) }, to: directory.appendingPathComponent("\(name).png"), scale: 2)
        }
        try renderIssues(to: directory, now: now, language: language)
        try renderThreeModels(to: directory, now: now, language: language)
    }

    /// The open panel with a third model added by script (monogram logo, its own color).
    private static func renderThreeModels(to directory: URL, now: Date, language: AppLanguage) throws {
        let model = NotchModel(
            layout: NotchLayout(notch: mockupNotch), language: language, catalog: DemoData.threeModels, now: now, animated: false
        )
        var snapshots = DemoData.snapshots(now: now)
        snapshots[DemoData.orbit] = DemoData.orbitSnapshot(now: now, language: language)
        model.update(snapshots: snapshots, issues: [:])
        model.apply(NotchMachine().hover(true, now: now))
        try PNGWriter.write(Wallpaper { NotchRootView(model: model) }, to: directory.appendingPathComponent("open-three-models.png"), scale: 2)
    }

    /// The open panel when Codex has no data.
    private static func renderIssues(to directory: URL, now: Date, language: AppLanguage) throws {
        let model = NotchModel(layout: NotchLayout(notch: mockupNotch), language: language, now: now, animated: false)
        let snapshots = DemoData.snapshots(now: now).filter { $0.key == .claude }
        model.update(snapshots: snapshots, issues: [.codex: .noData])
        model.apply(NotchMachine().hover(true, now: now))
        try PNGWriter.write(Wallpaper { NotchRootView(model: model) }, to: directory.appendingPathComponent("open-issues.png"), scale: 2)
    }
}

/// The mockup's sky gradient, so the black island reads as it would on a desktop.
private struct Wallpaper<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content.background(
            LinearGradient(
                colors: [
                    Color(red: 0.173, green: 0.302, blue: 0.492),
                    Color(red: 0.406, green: 0.595, blue: 0.754),
                    Color(red: 0.870, green: 0.745, blue: 0.605),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
