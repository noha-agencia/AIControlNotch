import AppKit

private func exitWithError(_ message: String) -> Never {
    FileHandle.standardError.write(Data("AIControlNotch: \(message)\n".utf8))
    exit(1)
}

let command = AppCommand.parse(CommandLine.arguments)
let strings = AppStrings()

switch command {
case let .renderStates(directory, language):
    do { try StateRenderer.render(to: directory, language: language ?? .current) } catch { exitWithError(strings.renderFailed(error)) }
    print(strings.statesSaved(directory.path))
case let .renderFrames(options):
    do {
        let result = try FrameRenderer.render(options)
        print(strings.framesSaved(result.frameCount, result.folder.path))
    } catch {
        exitWithError(strings.framesFailed(error))
    }
case let .renderIcon(directory):
    do { try IconRenderer.render(to: directory) } catch { exitWithError(strings.iconFailed(error)) }
    print(strings.iconSaved(directory.path))
case let .launchAtLogin(enabled):
    guard LaunchAtLogin.isAvailable else { exitWithError(strings.launchNeedsApp) }
    do { try LaunchAtLogin.setEnabled(enabled) } catch { exitWithError(strings.launchFailed(error)) }
    print(strings.launchState(LaunchAtLogin.isEnabled))
case let .invalid(usage):
    exitWithError(strings.usage(usage))
case let .run(demo, snapshots):
    let app = NSApplication.shared
    let delegate = AppDelegate(demo: demo, snapshots: snapshots)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
