import Foundation

/// Why an AI shows a message instead of (or next to) its numbers.
public enum ProviderIssue: Equatable, Sendable {
    case noData
    /// Shown even next to cached numbers, so a broken script is never silent.
    case scriptFailed(ScriptFailure)
}

/// The two halves of a reset cell: "renova em 2h14" over "hoje 17:56".
public struct ResetLine: Equatable, Sendable {
    public let relative: String
    public let absolute: String

    public init(relative: String, absolute: String) {
        self.relative = relative
        self.absolute = absolute
    }
}

/// Every string the notch shows, in the user's language.
public struct Copy: Sendable {
    static let secondsPerMinute: TimeInterval = 60
    static let minutesPerHour = 60
    static let hoursPerDay = 24

    /// Names, apps and order of the models being shown.
    public let catalog: ProviderCatalog
    private let strings: any LocalizedStrings
    private let formatter: ResetFormatter

    public init(language: AppLanguage = .current, calendar: Calendar = .current, catalog: ProviderCatalog = .builtIn) {
        self.catalog = catalog
        self.strings = language.strings
        self.formatter = ResetFormatter(calendar: calendar, language: language)
    }

    public var panelTitle: String { strings.panelTitle }
    public var loading: String { strings.loading }

    public func legend(_ tone: PaceTone) -> String {
        strings.legend(tone)
    }

    public func windowLabel(_ window: UsageWindow) -> String {
        window.label ?? strings.windowLabel(window.kind)
    }

    public func sourceName(_ source: DataSource) -> String {
        strings.source(source)
    }

    /// "Codex chegou a 90% da semana" / "Codex atingiu o limite da semana".
    public func alertTitle(_ alert: ThresholdAlert) -> String {
        let name = catalog.descriptor(alert.provider).displayName
        if alert.isLimit { return strings.hitLimit(name, of: alert.kind) }
        return strings.reached(name, percent: alert.bucket, of: alert.kind)
    }

    /// "Restam 10%. Renova seg 18:38, em 3d 2h."
    public func alertSubtitle(_ alert: ThresholdAlert, now: Date) -> String {
        let remaining = strings.remaining(max(0, 100 - alert.bucket))
        guard let reset = alert.resetsAt else {
            return alert.isLimit ? strings.waitForReset : remaining
        }
        let renews = strings.resets(at: formatter.absolute(reset, now: now), in: formatter.relative(reset, now: now))
        return alert.isLimit ? renews : "\(remaining) \(renews)"
    }

    public func updatedAgo(_ date: Date?, now: Date) -> String {
        guard let date else { return strings.noDataYet }
        let minutes = Int(max(0, now.timeIntervalSince(date)) / Self.secondsPerMinute)
        if minutes < 1 { return strings.updatedNow }
        if minutes < Self.minutesPerHour { return strings.updated(minutesAgo: minutes) }
        let hours = minutes / Self.minutesPerHour
        if hours < Self.hoursPerDay { return strings.updated(hoursAgo: hours) }
        return strings.updated(daysAgo: hours / Self.hoursPerDay)
    }

    public func resetLine(_ window: UsageWindow, now: Date) -> ResetLine {
        guard let reset = window.resetsAt else {
            return ResetLine(relative: strings.startsOnNextUse, absolute: "")
        }
        return ResetLine(
            relative: strings.resetsIn(formatter.relative(reset, now: now)),
            absolute: formatter.absolute(reset, now: now)
        )
    }

    public func issueMessage(_ issue: ProviderIssue, provider: ProviderID) -> String {
        let descriptor = catalog.descriptor(provider)
        switch issue {
        case .noData: return strings.noData(descriptor)
        case let .scriptFailed(failure): return strings.scriptFailed(descriptor.displayName, reason: strings.scriptReason(failure))
        }
    }
}
