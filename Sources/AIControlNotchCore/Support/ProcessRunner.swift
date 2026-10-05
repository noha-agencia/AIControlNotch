import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data
    /// stdout passed `ProcessOptions.outputLimit`, so the process was stopped.
    public let outputOverflowed: Bool

    public init(exitCode: Int32, stdout: Data, stderr: Data, outputOverflowed: Bool = false) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.outputOverflowed = outputOverflowed
    }
}

/// Where and with what a process runs. `nil` fields inherit from the app.
public struct ProcessOptions: Sendable {
    public let environment: [String: String]?
    public let directory: URL?
    /// Bytes of stdout (and of stderr) kept; going past it on stdout stops the process.
    public let outputLimit: Int?

    public init(environment: [String: String]?, directory: URL?, outputLimit: Int?) {
        self.environment = environment
        self.directory = directory
        self.outputLimit = outputLimit
    }

    public static let inherit = ProcessOptions(environment: nil, directory: nil, outputLimit: nil)
}

/// Runs a command to completion. Injected so providers can be tested with fakes.
public protocol ProcessRunning: Sendable {
    func run(_ executable: URL, arguments: [String], stdin: Data?, timeout: TimeInterval) async throws -> ProcessResult
}

/// Runs a user's program with a controlled environment, folder and output size.
public protocol ScriptRunning: Sendable {
    func run(_ executable: URL, arguments: [String], timeout: TimeInterval, options: ProcessOptions) async throws -> ProcessResult
}

public struct SystemProcessRunner: ProcessRunning, ScriptRunning {
    /// After the child exits, how long to wait for its pipes to close. A grandchild
    /// left running in the background can hold them open indefinitely.
    static let outputGrace: TimeInterval = 0.5

    public init() {}

    public func run(_ executable: URL, arguments: [String], stdin: Data?, timeout: TimeInterval) async throws -> ProcessResult {
        try await run(executable, arguments: arguments, stdin: stdin, timeout: timeout, options: .inherit)
    }

    public func run(_ executable: URL, arguments: [String], timeout: TimeInterval, options: ProcessOptions) async throws -> ProcessResult {
        try await run(executable, arguments: arguments, stdin: nil, timeout: timeout, options: options)
    }

    private func run(
        _ executable: URL, arguments: [String], stdin: Data?, timeout: TimeInterval, options: ProcessOptions
    ) async throws -> ProcessResult {
        let job = ProcessJob(executable: executable, arguments: arguments, options: options)
        defer { job.stopCollecting() }
        try job.start(stdin: stdin)
        // Cancelled callers (a coordinator deadline) must not leave the program running,
        // nor wait for it: the group below only returns once the child has exited.
        let exitCode = try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Int32.self) { group in
                group.addTask { await job.waitForExit() }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    job.kill()
                    throw UsageError.timeout
                }
                defer { group.cancelAll() }
                return try await group.next() ?? -1
            }
        } onCancel: {
            job.kill()
        }
        try Task.checkCancellation()
        await job.waitForOutput(grace: Self.outputGrace)
        return job.result(exitCode: exitCode)
    }
}

/// One child process with its output collected off the main thread.
private final class ProcessJob: @unchecked Sendable {
    private static let streamCount = 2

    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lock = NSLock()
    private let outputLimit: Int?
    private var stdout = Data()
    private var stderr = Data()
    private var overflowed = false
    private var closedStreams: Set<ObjectIdentifier> = []
    private var exitCode: Int32?
    private var exitWaiter: CheckedContinuation<Int32, Never>?
    private var outputWaiter: CheckedContinuation<Void, Never>?

    init(executable: URL, arguments: [String], options: ProcessOptions) {
        outputLimit = options.outputLimit
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if let environment = options.environment { process.environment = environment }
        if let directory = options.directory { process.currentDirectoryURL = directory }
    }

    func start(stdin: Data?) throws {
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        collect(stdoutPipe) { job, data in job.appendOutput(data) }
        collect(stderrPipe) { job, data in job.appendError(data) }
        process.terminationHandler = { [weak self] finished in self?.finish(finished.terminationStatus) }
        signal(SIGPIPE, SIG_IGN)
        do {
            try process.run()
        } catch {
            throw UsageError.notFound(process.executableURL?.lastPathComponent ?? "process")
        }
        feed(stdin, to: inputPipe.fileHandleForWriting)
    }

    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let exitCode {
                lock.unlock()
                continuation.resume(returning: exitCode)
            } else {
                exitWaiter = continuation
                lock.unlock()
            }
        }
    }

    /// Returns once both pipes reach end of file, or after `grace` seconds.
    func waitForOutput(grace: TimeInterval) async {
        await withCheckedContinuation { continuation in
            let done = lock.withLock {
                guard closedStreams.count < Self.streamCount else { return true }
                outputWaiter = continuation
                return false
            }
            if done {
                continuation.resume()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + grace) { [weak self] in self?.releaseOutputWaiter() }
        }
    }

    /// Foundation starts each child as the leader of its own process group; signalling the
    /// group also stops what the program left running in the background. A child that has
    /// already exited is left alone, and so is anything it left behind: its pid may belong
    /// to another program by now. Only a pid that still leads its group, or still shares
    /// ours, is signalled.
    func kill() {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        let group = getpgid(pid)
        if group == pid {
            Darwin.kill(-pid, SIGKILL)
        } else if group == getpgrp() {
            Darwin.kill(pid, SIGKILL)
        }
    }

    func result(exitCode: Int32) -> ProcessResult {
        lock.withLock { ProcessResult(exitCode: exitCode, stdout: stdout, stderr: stderr, outputOverflowed: overflowed) }
    }

    /// Called with the lock held. Keeps one byte past the limit to know it was crossed.
    private func appendOutput(_ data: Data) {
        guard let outputLimit else { return stdout.append(data) }
        stdout.append(data.prefix(max(0, outputLimit + 1 - stdout.count)))
        guard stdout.count > outputLimit, !overflowed else { return }
        overflowed = true
        kill()
    }

    /// Called with the lock held. Extra stderr is dropped, never a reason to stop.
    private func appendError(_ data: Data) {
        guard let outputLimit else { return stderr.append(data) }
        stderr.append(data.prefix(max(0, outputLimit - stderr.count)))
    }

    func stopCollecting() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        releaseOutputWaiter()
    }

    /// Writes stdin off the caller's thread: a child that never reads would otherwise
    /// block the write, and with it the timeout, once the pipe buffer fills.
    private func feed(_ input: Data?, to writer: FileHandle) {
        guard let input else {
            try? writer.close()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            try? writer.write(contentsOf: input)
            try? writer.close()
        }
    }

    private func collect(_ pipe: Pipe, into append: @escaping @Sendable (ProcessJob, Data) -> Void) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self, lock] handle in
            let data = handle.availableData
            guard let self else { return }
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                self.streamClosed(handle)
                return
            }
            lock.withLock { append(self, data) }
        }
    }

    /// Idempotent per pipe: a repeated end-of-file callback cannot count twice.
    private func streamClosed(_ handle: FileHandle) {
        let allClosed = lock.withLock {
            closedStreams.insert(ObjectIdentifier(handle))
            return closedStreams.count == Self.streamCount
        }
        if allClosed { releaseOutputWaiter() }
    }

    private func releaseOutputWaiter() {
        let pending: CheckedContinuation<Void, Never>? = lock.withLock {
            defer { outputWaiter = nil }
            return outputWaiter
        }
        pending?.resume()
    }

    private func finish(_ status: Int32) {
        lock.lock()
        exitCode = status
        let pending = exitWaiter
        exitWaiter = nil
        lock.unlock()
        pending?.resume(returning: status)
    }
}
