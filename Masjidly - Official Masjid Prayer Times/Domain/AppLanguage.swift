import Foundation

/// In-app language override (persisted). System uses the device language when it is en, ar, or ur; otherwise English.
enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case english
    case arabic
    case urdu

    /// String Catalog key for the settings picker row label.
    var catalogOptionKey: String {
        switch self {
        case .system: "app_language.system"
        case .english: "app_language.english"
        case .arabic: "app_language.arabic"
        case .urdu: "app_language.urdu"
        }
    }

    private static let supportedLanguageCodes: Set<String> = ["en", "ar", "ur"]
    private static let rightToLeftLanguageCodes: Set<String> = ["ar", "ur"]

    var resolvedLanguageCode: String {
        switch self {
        case .english:
            return "en"
        case .arabic:
            return "ar"
        case .urdu:
            return "ur"
        case .system:
            let code = Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
            return Self.supportedLanguageCodes.contains(code) ? code : "en"
        }
    }

    var isResolvedRightToLeft: Bool {
        Self.rightToLeftLanguageCodes.contains(resolvedLanguageCode)
    }

    /// Locale applied to SwiftUI and notification copy.
    func resolvedLocale() -> Locale {
        switch self {
        case .english:
            return Locale(identifier: "en")
        case .arabic:
            return Locale(identifier: "ar")
        case .urdu:
            return Locale(identifier: "ur")
        case .system:
            let code = Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
            if Self.supportedLanguageCodes.contains(code) {
                return Locale.autoupdatingCurrent
            }
            return Locale(identifier: "en")
        }
    }
}
