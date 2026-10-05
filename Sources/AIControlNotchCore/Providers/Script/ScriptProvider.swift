import Foundation

/// Reads a model's limits by running the person's own program: argv only,
/// never a shell; a minimal environment; the home folder; bounded time and output.
public struct ScriptProvider: UsageProvider {
    public static let outputLimit = 64 * 1_024
    static let stderrPreview = 300
    /// Only this much of stderr is searched for secrets; the preview is cut well inside it.
    static let stderrScanned = 2_048
    /// Room for the runner to stop the script before the coordinator gives up on it.
    static let deadlineGrace: TimeInterval = 2
    static let searchPath = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
    static let locale = "en_US.UTF-8"

    public let config: ScriptProviderConfig
    private let home: URL
    private let runner: any ScriptRunning
    private let log: LogSink
    private let now: @Sendable () -> Date

    public init(
        config: ScriptProviderConfig,
        home: URL,
        runner: any ScriptRunning = SystemProcessRunner(),
        log: LogSink = NullLog(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.home = home
        self.runner = runner
        self.log = log
        self.now = now
    }

    public var provider: ProviderID { config.id }
    public var source: DataSource { .script }
    public var policy: FetchPolicy {
        FetchPolicy(timeout: config.timeout + Self.deadlineGrace, minimumSpacing: config.interval)
    }

    public func fetch() async throws -> ProviderSnapshot {
        let result = try await run()
        if result.outputOverflowed { throw failed(.tooMuchOutput(kilobytes: Self.outputLimit / 1_024), stderr: result.stderr) }
        guard result.exitCode == 0 else { throw failed(.exit(result.exitCode), stderr: result.stderr) }
        do {
            return try ScriptOutputParser.parse(result.stdout, provider: config.id, now: now())
        } catch let failure as ScriptFailure {
            throw failed(failure, stderr: result.stderr)
        }
    }

    private func run() async throws -> ProcessResult {
        if let path = ScriptFileTrust.firstUnsafe(in: config.command, home: home) {
            log.log(.warning, "script \(config.id.rawValue) not run: other users can change \(path)")
            throw UsageError.script(.unsafeFile)
        }
        let options = ProcessOptions(
            environment: ["HOME": home.path, "PATH": Self.searchPath, "LANG": Self.locale],
            directory: home,
            outputLimit: Self.outputLimit
        )
        do {
            return try await runner.run(
                URL(fileURLWithPath: config.command[0]),
                arguments: Array(config.command.dropFirst()),
                timeout: config.timeout,
                options: options
            )
        } catch UsageError.timeout {
            throw failed(.timedOut(seconds: Int(config.timeout.rounded(.up))), stderr: Data())
        } catch is CancellationError {
            // The coordinator gave up on it: from the person's side, the script took too long.
            throw failed(.timedOut(seconds: Int(config.timeout.rounded(.up))), stderr: Data())
        } catch {
            throw failed(.launch, stderr: Data())
        }
    }

    /// Logs what the script said on stderr (shortened, likely secrets hidden) and wraps
    /// the reason for the coordinator.
    private func failed(_ failure: ScriptFailure, stderr: Data) -> UsageError {
        let said = Self.preview(ofStderr: stderr)
        log.log(.warning, "script \(config.id.rawValue) \(failure)" + (said.isEmpty ? "" : " stderr: \(said)"))
        return .script(failure)
    }

    /// The start of stderr for the log. Secrets are hidden before the preview is cut, so a
    /// cut never leaves half a secret unmatched; past `stderrScanned` nothing is kept anyway.
    static func preview(ofStderr stderr: Data) -> String {
        let scanned = String(decoding: stderr.prefix(stderrScanned), as: UTF8.self)
        return String(LogRedaction.redact(scanned).prefix(stderrPreview)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
