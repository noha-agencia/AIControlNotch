import Foundation

/// Fallback Codex source: the rate limits Codex writes into its session logs.
public struct CodexRolloutProvider: UsageProvider {
    static let maxFiles = 20
    static let needle = Data(#""token_count""#.utf8)
    static let newline: UInt8 = 0x0A

    public let provider = ProviderID.codex
    public let source = DataSource.codexRollout

    private let codexHome: URL

    public init(codexHome: URL) {
        self.codexHome = codexHome
    }

    public func fetch() async throws -> ProviderSnapshot {
        let files = newestRolloutFiles()
        guard !files.isEmpty else { throw UsageError.notFound("codex logs") }
        for file in files {
            guard let limits = Self.lastLimits(in: file.url) else { continue }
            return ProviderSnapshot(
                provider: provider,
                windows: limits.windows,
                planLabel: limits.planLabel,
                fetchedAt: limits.timestamp ?? file.modified,
                source: source
            )
        }
        throw UsageError.notFound("codex rate limits in logs")
    }

    private func newestRolloutFiles() -> [(url: URL, modified: Date)] {
        let roots = ["sessions", "archived_sessions"].map { codexHome.appendingPathComponent($0, isDirectory: true) }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let files = roots.flatMap { root -> [(url: URL, modified: Date)] in
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [] }
            return walker.compactMap { item in
                guard
                    let url = item as? URL,
                    url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl",
                    let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true
                else { return nil }
                return (url, values.contentModificationDate ?? .distantPast)
            }
        }
        return Array(files.sorted { $0.modified > $1.modified }.prefix(Self.maxFiles))
    }

    /// Walks backwards through `"token_count"` occurrences, so large logs are not parsed in full.
    static func lastLimits(in file: URL) -> CodexLimits? {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return nil }
        var searchEnd = data.endIndex
        while let hit = data.range(of: needle, options: .backwards, in: data.startIndex..<searchEnd) {
            let lineStart = data[..<hit.lowerBound].lastIndex(of: newline).map { $0 + 1 } ?? data.startIndex
            let lineEnd = data[hit.upperBound...].firstIndex(of: newline) ?? data.endIndex
            if let limits = CodexRateLimitParser.parseRolloutLine(Data(data[lineStart..<lineEnd])) {
                return limits
            }
            searchEnd = lineStart
        }
        return nil
    }
}
