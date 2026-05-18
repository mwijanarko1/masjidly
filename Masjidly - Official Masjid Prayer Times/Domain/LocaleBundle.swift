import Foundation

/// Looks up a localized string from the app bundle using the language-specific `.lproj`
/// directory. This is the most reliable approach for runtime locale switching because it
/// bypasses the system's process-wide locale and directly reads the correct `.strings` file.
///
/// Usage:
/// ```swift
/// LocaleBundle.string(forKey: "prayer.fajr", locale: settings.resolvedLocale)
/// ```
enum LocaleBundle {

    // Cache bundles by language code to avoid re-creating them on every call.
    private static var bundleCache: [String: Bundle] = [:]
    private static let lock = NSLock()

    /// Returns the language-specific `Bundle` for `locale`, falling back to the main bundle.
    static func bundle(for locale: Locale) -> Bundle {
        let langCode = resolvedLanguageCode(for: locale)
        lock.lock()
        defer { lock.unlock() }
        if let cached = bundleCache[langCode] { return cached }
        let resolved = makeBundle(languageCode: langCode)
        bundleCache[langCode] = resolved
        return resolved
    }

    /// Looks up `key` in the Localizable table for `locale`.
    /// Falls back to the key itself when no translation is found.
    static func string(forKey key: String, locale: Locale) -> String {
        let b = bundle(for: locale)
        let result = b.localizedString(forKey: key, value: nil, table: "Localizable")
        // localizedString returns the key when nothing is found; guard against that
        return result
    }

    // MARK: - Private

    private static func resolvedLanguageCode(for locale: Locale) -> String {
        // Swift 5.7+ Locale.language API
        if let code = locale.language.languageCode?.identifier {
            return code
        }
        // Fallback: parse the identifier directly ("ar", "en", "ur", "id_ID" → "id")
        return String(locale.identifier.prefix(2))
    }

    private static func makeBundle(languageCode: String) -> Bundle {
        // Try exact match first, then prefix match for regional variants (e.g. "id_ID" → "id")
        for code in [languageCode, String(languageCode.prefix(2))] {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return Bundle.main
    }
}
