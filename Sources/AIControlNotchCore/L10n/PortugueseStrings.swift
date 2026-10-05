import Foundation

struct PortugueseStrings: LocalizedStrings {
    let panelTitle = "Limites do plano"
    let loading = "Buscando os limites…"
    let waitForReset = "Aguarde a renovação."
    let noDataYet = "sem dados ainda"
    let updatedNow = "atualizado agora"
    let startsOnNextUse = "inicia no próximo uso"
    let weekdays = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

    func legend(_ tone: PaceTone) -> String {
        switch tone {
        case .ok: "folga"
        case .warn: "no limite do ritmo"
        case .danger: "acaba antes de renovar"
        }
    }

    func windowLabel(_ kind: WindowKind) -> String {
        switch kind {
        case .session: "Sessão 5h"
        case .week: "Semana"
        case let .days(count): count == 1 ? "1 dia" : "\(count) dias"
        case let .minutes(count): DurationText.minutes(count)
        }
    }

    func reached(_ name: String, percent: Int, of kind: WindowKind) -> String {
        "\(name) chegou a \(percent)% \(noun(kind))"
    }

    func hitLimit(_ name: String, of kind: WindowKind) -> String {
        "\(name) atingiu o limite \(noun(kind))"
    }

    func remaining(_ percent: Int) -> String { "Restam \(percent)%." }
    func resets(at absolute: String, in relative: String) -> String { "Renova \(absolute), \(relative)." }
    func updated(minutesAgo: Int) -> String { "atualizado há \(minutesAgo) min" }
    func updated(hoursAgo: Int) -> String { "atualizado há \(hoursAgo)h" }
    func updated(daysAgo: Int) -> String { "atualizado há \(daysAgo) \(daysAgo == 1 ? "dia" : "dias")" }
    func resetsIn(_ relative: String) -> String { "renova \(relative)" }
    func within(_ duration: String) -> String { "em \(duration)" }
    func today(_ time: String) -> String { "hoje \(time)" }
    func tomorrow(_ time: String) -> String { "amanhã \(time)" }
    func shortDate(day: Int, month: Int) -> String { "\(Self.pad(day))/\(Self.pad(month))" }

    func noData(_ provider: ProviderDescriptor) -> String {
        switch provider.id {
        case .claude: "Sem dados. Conecte a barra de status do Claude Code e use-o uma vez."
        case .codex: "Sem dados. Abra o Codex uma vez para ver os limites."
        default: "Sem dados do \(provider.displayName) ainda."
        }
    }

    func scriptFailed(_ name: String, reason: String) -> String { "Script do \(name) falhou: \(reason)." }

    func scriptReason(_ failure: ScriptFailure) -> String {
        switch failure {
        case .launch: "não iniciou (confira o caminho e o chmod +x)"
        case .unsafeFile: "outros usuários podem alterar os arquivos dele (rode chmod go-w neles)"
        case let .exit(code): "código de saída \(code)"
        case let .timedOut(seconds): "passou de \(seconds) s"
        case let .tooMuchOutput(kilobytes): "imprimiu mais de \(kilobytes) KB"
        case let .invalidOutput(field): "saída inválida (\(field))"
        }
    }

    func source(_ source: DataSource) -> String {
        switch source {
        case .claudeStatusLine: "barra de status do Claude Code"
        case .codexAppServer: "servidor do Codex"
        case .codexRollout: "logs do Codex"
        case .script: "script"
        case .demo: "demonstração"
        }
    }

    /// Completes "chegou a 90% ___" and "atingiu o limite ___".
    private func noun(_ kind: WindowKind) -> String {
        switch kind {
        case .session: "da sessão de 5h"
        case .week: "da semana"
        case let .days(count): count == 1 ? "da janela de 1 dia" : "da janela de \(count) dias"
        case let .minutes(count): "da janela de \(DurationText.minutes(count))"
        }
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
