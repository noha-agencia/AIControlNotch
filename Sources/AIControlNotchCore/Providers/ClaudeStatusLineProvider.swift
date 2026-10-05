import Foundation

/// The Claude source: the last rate limits Claude Code showed its status line, saved by
/// `aicontrolnotch-tap`. The app never reads the Claude login.
public struct ClaudeStatusLineProvider: UsageProvider {
    public let provider = ProviderID.claude
    public let source = DataSource.claudeStatusLine
    public let policy = FetchPolicy.localFile

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func fetch() async throws -> ProviderSnapshot {
        guard let data = try? Data(contentsOf: fileURL) else {
            throw UsageError.notFound(fileURL.lastPathComponent)
        }
        let record = try StatusLineRecord.decode(data)
        guard !record.windows.isEmpty else { throw UsageError.invalidFormat("statusline record has no limits") }
        return ProviderSnapshot(provider: provider, windows: record.windows, planLabel: nil, fetchedAt: record.capturedAt, source: source)
    }
}
