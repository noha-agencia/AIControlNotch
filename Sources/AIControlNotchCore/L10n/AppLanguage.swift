import Foundation

/// The languages the notch speaks, picked from the system's preferred languages.
public enum AppLanguage: String, Sendable, CaseIterable, Codable {
    case english = "en"
    case portuguese = "pt-BR"

    /// First supported language in the user's list; English when none is supported.
    public static func preferred(from languages: [String]) -> AppLanguage {
        for language in languages.map({ $0.lowercased() }) {
            if language.hasPrefix("pt") { return .portuguese }
            if language.hasPrefix("en") { return .english }
        }
        return .english
    }

    public static var current: AppLanguage {
        preferred(from: Locale.preferredLanguages)
    }

    public var strings: any LocalizedStrings {
        switch self {
        case .english: EnglishStrings()
        case .portuguese: PortugueseStrings()
        }
    }
}
