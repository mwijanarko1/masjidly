import Foundation

/// Maps canonical English prayer names from `PrayerTimesEngine` to localization keys.
enum PrayerLocalization {
    private static func catalogKey(for canonicalEnglish: String) -> String {
        switch canonicalEnglish {
        case "Fajr": "prayer.fajr"
        case "Sunrise": "prayer.sunrise"
        case "Dhuhr": "prayer.dhuhr"
        case "Jummah": "prayer.jummah"
        case "Asr": "prayer.asr"
        case "Maghrib": "prayer.maghrib"
        case "Isha": "prayer.isha"
        default: "prayer.unknown"
        }
    }

    static func displayName(canonicalEnglish: String, locale: Locale) -> String {
        String(
            localized: String.LocalizationValue(stringLiteral: catalogKey(for: canonicalEnglish)),
            bundle: .main,
            locale: locale
        )
    }
}
