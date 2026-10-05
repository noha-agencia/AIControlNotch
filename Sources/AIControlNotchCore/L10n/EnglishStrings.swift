import Foundation

struct EnglishStrings: LocalizedStrings {
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    let panelTitle = "Plan limits"
    let loading = "Fetching limits…"
    let waitForReset = "Wait for the reset."
    let noDataYet = "no data yet"
    let updatedNow = "updated just now"
    let startsOnNextUse = "starts on next use"
    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    func legend(_ tone: PaceTone) -> String {
        switch tone {
        case .ok: "on track"
        case .warn: "at the pace limit"
        case .danger: "runs out before reset"
        }
    }

    func windowLabel(_ kind: WindowKind) -> String {
        switch kind {
        case .session: "5h session"
        case .week: "Week"
        case let .days(count): count == 1 ? "1 day" : "\(count) days"
        case let .minutes(count): DurationText.minutes(count)
        }
    }

    func reached(_ name: String, percent: Int, of kind: WindowKind) -> String {
        "\(name) reached \(percent)% of the \(windowNoun(kind))"
    }

    func hitLimit(_ name: String, of kind: WindowKind) -> String {
        "\(name) hit the \(limitNoun(kind)) limit"
    }

    func remaining(_ percent: Int) -> String { "\(percent)% left." }
    func resets(at absolute: String, in relative: String) -> String { "Resets \(absolute), \(relative)." }
    func updated(minutesAgo: Int) -> String { "updated \(minutesAgo) min ago" }
    func updated(hoursAgo: Int) -> String { "updated \(hoursAgo)h ago" }
    func updated(daysAgo: Int) -> String { "updated \(daysAgo) \(daysAgo == 1 ? "day" : "days") ago" }
    func resetsIn(_ relative: String) -> String { "resets \(relative)" }
    func within(_ duration: String) -> String { "in \(duration)" }
    func today(_ time: String) -> String { "today \(time)" }
    func tomorrow(_ time: String) -> String { "tomorrow \(time)" }
    func shortDate(day: Int, month: Int) -> String { "\(Self.months[(month - 1).clamped(to: 0...11)]) \(day)" }

    func noData(_ provider: ProviderDescriptor) -> String {
        switch provider.id {
        case .claude: "No data. Connect the Claude Code status line, then use Claude Code once."
        case .codex: "No data. Open Codex once to see the limits."
        default: "No data from \(provider.displayName) yet."
        }
    }

    func scriptFailed(_ name: String, reason: String) -> String { "\(name) script failed: \(reason)." }

    func scriptReason(_ failure: ScriptFailure) -> String {
        switch failure {
        case .launch: "could not start (check the path and chmod +x)"
        case .unsafeFile: "other users can change its files (run chmod go-w on them)"
        case let .exit(code): "exit code \(code)"
        case let .timedOut(seconds): "took longer than \(seconds) s"
        case let .tooMuchOutput(kilobytes): "printed more than \(kilobytes) KB"
        case let .invalidOutput(field): "invalid output (\(field))"
        }
    }

    func source(_ source: DataSource) -> String {
        switch source {
        case .claudeStatusLine: "Claude Code status line"
        case .codexAppServer: "Codex app-server"
        case .codexRollout: "Codex logs"
        case .script: "script"
        case .demo: "demo"
        }
    }

    private func windowNoun(_ kind: WindowKind) -> String {
        switch kind {
        case .session: "5h session"
        case .week: "week"
        case let .days(count): "\(count)-day window"
        case let .minutes(count): "\(DurationText.minutes(count)) window"
        }
    }

    private func limitNoun(_ kind: WindowKind) -> String {
        switch kind {
        case .session: "5h session"
        case .week: "weekly"
        case let .days(count): "\(count)-day"
        case let .minutes(count): DurationText.minutes(count)
        }
    }
}
