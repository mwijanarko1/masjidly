import Foundation
import SwiftUI

/// Persisted in-app language selection shared by Settings, formatters, widgets, and notifications.
enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case english
    case arabic
    case urdu
    case indonesian

    var id: String { rawValue }

    var resolvedLanguageCode: String {
        switch self {
        case .english: return "en"
        case .arabic: return "ar"
        case .urdu: return "ur"
        case .indonesian: return "id"
        }
    }

    var isResolvedRightToLeft: Bool {
        switch self {
        case .arabic, .urdu: return true
        case .english, .indonesian: return false
        }
    }

    var layoutDirection: LayoutDirection {
        isResolvedRightToLeft ? .rightToLeft : .leftToRight
    }

    func resolvedLocale() -> Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .arabic: return Locale(identifier: "ar")
        case .urdu: return Locale(identifier: "ur")
        case .indonesian: return Locale(identifier: "id_ID")
        }
    }

    var displayNameKey: String {
        switch self {
        case .english: return "settings.language.english"
        case .arabic: return "settings.language.arabic"
        case .urdu: return "settings.language.urdu"
        case .indonesian: return "settings.language.indonesian"
        }
    }

    init(persistedRawValue: String?) {
        switch persistedRawValue {
        case AppLanguage.english.rawValue, "en": self = .english
        case AppLanguage.arabic.rawValue, "ar": self = .arabic
        case AppLanguage.urdu.rawValue, "ur": self = .urdu
        case AppLanguage.indonesian.rawValue, "id", "id-ID", "id_ID": self = .indonesian
        default: self = .english
        }
    }
}
