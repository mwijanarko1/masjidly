import Foundation

/// In-app language is English-only (Arabic/Urdu removed). System/arabic/urdu kept only for decoding legacy persisted values.
enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case english

    var resolvedLanguageCode: String { "en" }

    var isResolvedRightToLeft: Bool { false }

    func resolvedLocale() -> Locale { Locale(identifier: "en") }
}
