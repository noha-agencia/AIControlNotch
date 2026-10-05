import Foundation

/// What the status line prints and its exit code.
public struct TapOutput: Equatable, Sendable {
    public let stdout: Data
    public let exitCode: Int32

    public static let silent = TapOutput(stdout: Data(), exitCode: 0)
}

/// Saves the `rate_limits` Claude Code hands its status line, then runs the
/// user's original command with the same stdin. It never breaks the status line.
public struct StatusLineTap: Sendable {
    static let shell = URL(fileURLWithPath: "/bin/sh")
    public static let commandTimeout: TimeInterval = 10

    private let paths: Paths
    private let runner: ProcessRunning
    private let now: @Sendable () -> Date

    public init(paths: Paths, runner: ProcessRunning = SystemProcessRunner(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.paths = paths
        self.runner = runner
        self.now = now
    }

    public func run(input: Data) async -> TapOutput {
        record(input)
        let config: TapConfig
        do {
            guard let loaded = try loadConfig() else { return .silent }
            config = loaded
        } catch {
            // The line says why instead of going blank: the fix is a chmod the person must run.
            return TapOutput(stdout: Data("AIControlNotch: tap.json ignored: \(error.reason)\n".utf8), exitCode: 0)
        }
        guard let result = try? await runner.run(
            Self.shell,
            arguments: ["-c", config.command],
            stdin: input,
            timeout: Self.commandTimeout
        ) else { return .silent }
        return TapOutput(stdout: result.stdout, exitCode: result.exitCode)
    }

    private func record(_ input: Data) {
        guard
            let record = StatusLineRecord.extract(fromStatusLineInput: input, now: now()),
            let data = try? record.encoded()
        else { return }
        try? AtomicFile.write(data, to: paths.statusLineFile)
    }

    /// `tap.json` holds a shell command, so it gets the same checks as `providers.json`.
    /// A broken file is ignored quietly, as before.
    private func loadConfig() throws(ConfigFileRejected) -> TapConfig? {
        let data: Data?
        do {
            data = try ConfigFileReader.read(paths.tapConfigFile, name: "tap.json", maxBytes: TapConfig.maxBytes)
        } catch let rejected as ConfigFileRejected {
            throw rejected
        } catch {
            return nil
        }
        return data.flatMap { try? TapConfig.decode($0) }
    }
}
