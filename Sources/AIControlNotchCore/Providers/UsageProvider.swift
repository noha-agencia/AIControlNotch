import Foundation

/// How often and how long a source may run, when it differs from the built-in defaults.
public struct FetchPolicy: Equatable, Sendable {
    /// Longest the coordinator waits for this source; only ever extends its default deadline.
    public let timeout: TimeInterval?
    /// Replaces the automatic minimum spacing between attempts (manual refreshes keep theirs).
    public let minimumSpacing: TimeInterval?
    /// False for cheap local reads, which retry on the next refresh instead of waiting out a
    /// backoff. The minimum spacing between attempts still applies.
    public let backsOff: Bool

    public init(timeout: TimeInterval?, minimumSpacing: TimeInterval?, backsOff: Bool = true) {
        self.timeout = timeout
        self.minimumSpacing = minimumSpacing
        self.backsOff = backsOff
    }

    public static let standard = FetchPolicy(timeout: nil, minimumSpacing: nil)
    /// A file on this Mac that another program rewrites: reading it again costs nothing.
    public static let localFile = FetchPolicy(timeout: nil, minimumSpacing: nil, backsOff: false)
}

/// One way of reading an AI's plan limits (API, local server, log files, a script...).
public protocol UsageProvider: Sendable {
    var provider: ProviderID { get }
    var source: DataSource { get }
    var policy: FetchPolicy { get }
    func fetch() async throws -> ProviderSnapshot
}

extension UsageProvider {
    public var policy: FetchPolicy { .standard }
}
