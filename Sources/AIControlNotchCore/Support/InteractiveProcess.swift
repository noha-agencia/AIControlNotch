import Foundation

/// A long-lived child process spoken to line by line (JSONL over stdio).
public protocol InteractiveProcess: Sendable {
    /// Stdout split into lines. Ends when the process closes stdout.
    var lines: AsyncThrowingStream<String, Error> { get }
    func send(_ line: String) throws
    func terminate()
}

/// Starts interactive processes. Injected so the Codex provider can be tested.
public protocol InteractiveSpawning: Sendable {
    func spawn(_ executable: URL, arguments: [String]) throws -> InteractiveProcess
}

public struct SystemInteractiveSpawner: InteractiveSpawning {
    public init() {}

    public func spawn(_ executable: URL, arguments: [String]) throws -> InteractiveProcess {
        try SystemInteractiveProcess.spawn(executable, arguments: arguments)
    }
}

public final class SystemInteractiveProcess: InteractiveProcess, @unchecked Sendable {
    public let lines: AsyncThrowingStream<String, Error>

    private let process: Process
    private let input: FileHandle
    private let output: FileHandle

    private init(process: Process, input: FileHandle, output: FileHandle, lines: AsyncThrowingStream<String, Error>) {
        self.process = process
        self.input = input
        self.output = output
        self.lines = lines
    }

    public static func spawn(_ executable: URL, arguments: [String]) throws -> SystemInteractiveProcess {
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let splitter = LineSplitter(continuation: continuation)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                splitter.finish()
            } else {
                splitter.feed(data)
            }
        }

        signal(SIGPIPE, SIG_IGN)
        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            throw UsageError.notFound(executable.lastPathComponent)
        }
        return SystemInteractiveProcess(
            process: process,
            input: stdinPipe.fileHandleForWriting,
            output: stdoutPipe.fileHandleForReading,
            lines: stream
        )
    }

    public func send(_ line: String) throws {
        do {
            try input.write(contentsOf: Data((line + "\n").utf8))
        } catch {
            throw UsageError.processFailed("write failed")
        }
    }

    public func terminate() {
        try? input.close()
        if process.isRunning { process.terminate() }
    }
}

/// Turns stdout chunks into whole lines.
private final class LineSplitter: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let lock = NSLock()
    private var buffer = Data()

    init(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
    }

    func feed(_ data: Data) {
        let lines: [String] = lock.withLock {
            buffer.append(data)
            var complete: [String] = []
            while let newline = buffer.firstIndex(of: 0x0A) {
                complete.append(String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self))
                buffer = Data(buffer[buffer.index(after: newline)...])
            }
            return complete
        }
        lines.forEach { continuation.yield($0) }
    }

    func finish() {
        let rest: String? = lock.withLock {
            defer { buffer = Data() }
            return buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self)
        }
        if let rest { continuation.yield(rest) }
        continuation.finish()
    }
}
