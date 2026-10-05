import Foundation

/// A 10% step crossed by one window, shown as an alert in the notch.
public struct ThresholdAlert: Codable, Equatable, Sendable {
    public let provider: ProviderID
    public let kind: WindowKind
    /// 10, 20, ... 100.
    public let bucket: Int
    public let resetsAt: Date?

    public init(provider: ProviderID, kind: WindowKind, bucket: Int, resetsAt: Date?) {
        self.provider = provider
        self.kind = kind
        self.bucket = bucket
        self.resetsAt = resetsAt
    }

    public var key: String { ThresholdState.key(provider, kind) }
    public var isLimit: Bool { bucket >= 100 }
}
