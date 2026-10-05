import AIControlNotchCore
import Foundation

/// Menu and command line texts. The notch itself speaks through `Copy`.
struct AppStrings {
    let language: AppLanguage

    init(language: AppLanguage = .current) {
        self.language = language
    }

    private var english: Bool { language == .english }

    var refreshNow: String { english ? "Refresh now" : "Atualizar agora" }
    var openAtLogin: String { english ? "Open at login" : "Abrir ao iniciar" }
    var quit: String { english ? "Quit AIControlNotch" : "Sair do AIControlNotch" }
    func noData(_ name: String) -> String { english ? "\(name): no data" : "\(name): sem dados" }
    var configureModels: String { english ? "Configure models…" : "Configurar modelos…" }
    var reloadModels: String { english ? "Reload models" : "Recarregar modelos" }
    func configIgnored(_ reason: String) -> String {
        english ? "providers.json ignored: \(reason)" : "providers.json ignorado: \(reason)"
    }

    func statesSaved(_ path: String) -> String { english ? "States saved to \(path)" : "Estados salvos em \(path)" }
    func framesSaved(_ count: Int, _ path: String) -> String {
        english ? "\(count) frames saved to \(path)" : "\(count) quadros salvos em \(path)"
    }
    func framesFailed(_ error: Error) -> String { english ? "could not render the frames: \(error)" : "falha ao gerar os quadros: \(error)" }
    func iconSaved(_ path: String) -> String { english ? "Icon saved to \(path)" : "Ícone salvo em \(path)" }
    func renderFailed(_ error: Error) -> String { english ? "could not render the states: \(error)" : "falha ao gerar os estados: \(error)" }
    func iconFailed(_ error: Error) -> String { english ? "could not render the icon: \(error)" : "falha ao gerar o ícone: \(error)" }
    var launchNeedsApp: String {
        english ? "open at login only works from AIControlNotch.app" : "abrir ao iniciar só funciona a partir do AIControlNotch.app"
    }
    func launchFailed(_ error: Error) -> String {
        english ? "could not set open at login: \(error)" : "falha ao configurar a abertura no login: \(error)"
    }
    func launchState(_ enabled: Bool) -> String {
        switch (english, enabled) {
        case (true, true): "Open at login: on"
        case (true, false): "Open at login: off"
        case (false, true): "Abrir ao iniciar: ligado"
        case (false, false): "Abrir ao iniciar: desligado"
        }
    }
    func usage(_ text: String) -> String { english ? "usage: AIControlNotch \(text)" : "uso: AIControlNotch \(text)" }
}
