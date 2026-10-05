import Foundation

/// Pace dot color, plus grey when the data is older than 30 minutes.
public enum DotTone: Equatable, Sendable {
    case ok
    case warn
    case danger
    case stale

    public init(_ pace: PaceTone) {
        switch pace {
        case .ok: self = .ok
        case .warn: self = .warn
        case .danger: self = .danger
        }
    }
}

/// One side of the resting notch: logo, highest percent, pace dot.
public struct RestSide: Equatable, Sendable {
    public let provider: ProviderID
    public let percentText: String
    /// `nil` when there is no data at all.
    public let dot: DotTone?

    public init(provider: ProviderID, percentText: String, dot: DotTone?) {
        self.provider = provider
        self.percentText = percentText
        self.dot = dot
    }
}

/// One limit in the open panel.
public struct OpenRow: Equatable, Sendable, Identifiable {
    public let provider: ProviderID
    public let kind: WindowKind
    public let showsProvider: Bool
    public let label: String
    public let dot: DotTone
    public let percent: Int
    /// Fill of each of the 10 segments, 0...1.
    public let segments: [Double]
    /// 90% or more turns the ruler red.
    public let isDanger: Bool
    public let reset: ResetLine

    public var id: String { ThresholdState.key(provider, kind) }
}

public struct OpenSection: Equatable, Sendable, Identifiable {
    public let provider: ProviderID
    public let planLabel: String?
    public let rows: [OpenRow]
    public let message: String?

    public var id: String { provider.rawValue }
    public var lineCount: Int { rows.count + (message == nil ? 0 : 1) }
}

/// One entry of the pace legend under the open panel.
public struct LegendItem: Equatable, Sendable, Hashable {
    public let tone: PaceTone
    public let text: String
}

public struct OpenContent: Equatable, Sendable {
    public let title: String
    public let updated: String
    public let updatedIsStale: Bool
    public let sections: [OpenSection]
    public let legend: [LegendItem]

    public var rowCount: Int { sections.reduce(0) { $0 + $1.lineCount } }
}

public struct AlertContent: Equatable, Sendable {
    public let provider: ProviderID
    public let title: String
    public let subtitle: String
    public let percent: Int
    /// The ring starts at the previous step and sweeps to `percent`.
    public let fromPercent: Int
    public let isDanger: Bool
}
