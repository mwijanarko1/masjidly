import Foundation
import UserNotifications

/// Copy and sound wiring for prayer notifications (English; compact lock-screen text).
enum PrayerNotificationContent {
    /// Preferred spelling for Friday congregational prayer in user-facing English copy.
    static let jumuahName = "Jumu\u{2019}ah"

    enum CategoryID {
        static let adhan = "masjidly.category.adhan"
        static let iqamah = "masjidly.category.iqamah"
        static let reminder = "masjidly.category.reminder"
    }

    enum ActionID {
        static let viewTimes = "masjidly.action.view_times"
        static let snoozeReminder = "masjidly.action.snooze_reminder"
        static let viewMosque = "masjidly.action.view_mosque"
        static let openTimetable = "masjidly.action.open_timetable"
        static let dismiss = "masjidly.action.dismiss"
    }

    enum UserInfoKey {
        static let kind = "masjidly.kind"
        static let prayer = "masjidly.prayer"
        static let mosqueSlug = "masjidly.mosque_slug"
        static let isoDate = "masjidly.iso_date"
    }

    enum PayloadKind: String {
        case adhan
        case iqamah
        case reminderBeforeAdhan
        case reminderBeforeIqamah
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }

    static func registerCategories(locale: Locale = .current) {
        let viewTimes = UNNotificationAction(
            identifier: ActionID.viewTimes,
            title: localized("notification.action.view_times", locale: locale),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: ActionID.snoozeReminder,
            title: localized("notification.action.snooze_reminder", locale: locale),
            options: []
        )
        let viewMosque = UNNotificationAction(
            identifier: ActionID.viewMosque,
            title: localized("notification.action.view_mosque", locale: locale),
            options: [.foreground]
        )
        let openTimetable = UNNotificationAction(
            identifier: ActionID.openTimetable,
            title: localized("notification.action.open_timetable", locale: locale),
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: localized("notification.action.dismiss", locale: locale),
            options: [.destructive]
        )

        let adhan = UNNotificationCategory(
            identifier: CategoryID.adhan,
            actions: [viewTimes, snooze],
            intentIdentifiers: [],
            options: []
        )
        let iqamah = UNNotificationCategory(
            identifier: CategoryID.iqamah,
            actions: [viewMosque, openTimetable],
            intentIdentifiers: [],
            options: []
        )
        let reminder = UNNotificationCategory(
            identifier: CategoryID.reminder,
            actions: [openTimetable, dismiss],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([adhan, iqamah, reminder])
    }

    static func prayerDisplayName(prayerKey: String, isFriday: Bool, locale: Locale = Locale(identifier: "en")) -> String {
        switch prayerKey {
        case "fajr": return PrayerLocalization.displayName(canonicalEnglish: "Fajr", locale: locale)
        case "dhuhr": return PrayerLocalization.displayName(canonicalEnglish: isFriday ? "Jummah" : "Dhuhr", locale: locale)
        case "asr": return PrayerLocalization.displayName(canonicalEnglish: "Asr", locale: locale)
        case "maghrib": return PrayerLocalization.displayName(canonicalEnglish: "Maghrib", locale: locale)
        case "isha": return PrayerLocalization.displayName(canonicalEnglish: "Isha", locale: locale)
        default: return prayerKey.capitalized
        }
    }

    static func adhanCopy(prayerKey: String, isFriday: Bool, locale: Locale = Locale(identifier: "en")) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
        let titleFormat = localized("notification.copy.adhan.title", locale: locale)
        return (
            String(format: titleFormat, locale: locale, arguments: [name]),
            localized("notification.copy.adhan.body", locale: locale)
        )
    }

    static func iqamahCopy(prayerKey: String, isFriday: Bool, locale: Locale = Locale(identifier: "en")) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
        let titleFormat = localized("notification.copy.iqamah.title", locale: locale)
        let bodyFormat = localized("notification.copy.iqamah.body", locale: locale)
        return (
            String(format: titleFormat, locale: locale, arguments: [name]),
            String(format: bodyFormat, locale: locale, arguments: [name])
        )
    }

    static func beforeAdhanReminderCopy(prayerKey: String, isFriday: Bool, minutes: Int, locale: Locale = Locale(identifier: "en")) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
        let titleFormat = localized("notification.copy.before_adhan.title", locale: locale)
        let bodyFormat = localized("notification.copy.before_adhan.body", locale: locale)
        return (
            String(format: titleFormat, locale: locale, arguments: [name]),
            String(format: bodyFormat, locale: locale, arguments: [minutes])
        )
    }

    static func beforeIqamahReminderCopy(prayerKey: String, isFriday: Bool, minutes: Int, locale: Locale = Locale(identifier: "en")) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
        let titleFormat = localized("notification.copy.before_iqamah.title", locale: locale)
        let bodyFormat = localized("notification.copy.before_iqamah.body", locale: locale)
        return (
            String(format: titleFormat, locale: locale, arguments: [name]),
            String(format: bodyFormat, locale: locale, arguments: [minutes])
        )
    }

    /// Bundled adhan for **in-app playback** (not subject to the ~30s notification sound limit).
    /// Resolution order: full-length clips first, then preview/long variants, then default alert-length clips.
    /// Add **`Adhan-1-Full.caf`** (any duration) to Resources for a complete adhan; bundled `Adhan-1.caf` is ~30s.
    static func bundledAdhanPlaybackURL() -> URL? {
        let candidates = [
            "Adhan-1-Full.caf",
            "Adhan-2-Full.caf",
            "Adhan-1-Preview.caf",
            "Adhan-2-Preview.caf",
            "Adhan-1.caf",
            "Adhan-2.caf",
        ]
        for name in candidates {
            if let url = bundleURL(filename: name) { return url }
        }
        return nil
    }

    private static func bundleURL(filename: String) -> URL? {
        let ns = filename as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        guard !base.isEmpty, !ext.isEmpty else { return nil }
        return Bundle.main.url(forResource: base, withExtension: ext)
    }

    /// Local notifications use the **system default** tone; full adhan plays in-app after the user taps (see `bundledAdhanPlaybackURL()`).
    static func sound(for _: NotificationSettings, channel _: SoundChannel) -> UNNotificationSound {
        UNNotificationSound.default
    }

    enum SoundChannel {
        case adhan
        case iqamah
        case reminder
    }

    /// Sample routing payload for debug notification buttons (same keys as production prayer notifications).
    static func debugUserInfo(kind: PayloadKind, prayerKey: String, mosqueSlug: String, isoDate: String = "2099-01-01") -> [AnyHashable: Any] {
        [
            UserInfoKey.kind: kind.rawValue,
            UserInfoKey.prayer: prayerKey,
            UserInfoKey.mosqueSlug: mosqueSlug,
            UserInfoKey.isoDate: isoDate,
        ]
    }
}
