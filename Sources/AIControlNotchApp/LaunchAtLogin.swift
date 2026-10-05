import Foundation
import ServiceManagement

/// "Abrir ao iniciar": SMAppService first; ad-hoc signed builds may be refused,
/// so a per-user LaunchAgent is the fallback.
enum LaunchAtLogin {
    static let label = "com.noha.aicontrolnotch"

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: agentURL.path)
    }

    /// Only a bundled app can register itself.
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            try setAgent(enabled)
            return
        }
        // SMAppService handled it: drop any fallback agent so the app never launches twice.
        if FileManager.default.fileExists(atPath: agentURL.path) { try setAgent(false) }
    }

    private static func setAgent(_ enabled: Bool) throws {
        guard enabled else {
            try? FileManager.default.removeItem(at: agentURL)
            return
        }
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = ["Label": label, "ProgramArguments": [executable], "RunAtLoad": true]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: agentURL, options: .atomic)
    }
}
