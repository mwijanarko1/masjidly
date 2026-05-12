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

    static func registerCategories() {
        let viewTimes = UNNotificationAction(
            identifier: ActionID.viewTimes,
            title: "View times",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: ActionID.snoozeReminder,
            title: "Snooze reminder",
            options: []
        )
        let viewMosque = UNNotificationAction(
            identifier: ActionID.viewMosque,
            title: "View mosque",
            options: [.foreground]
        )
        let openTimetable = UNNotificationAction(
            identifier: ActionID.openTimetable,
            title: "Open timetable",
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: "Dismiss",
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

    static func prayerDisplayName(prayerKey: String, isFriday: Bool) -> String {
        switch prayerKey {
        case "fajr": return "Fajr"
        case "dhuhr": return isFriday ? jumuahName : "Dhuhr"
        case "asr": return "Asr"
        case "maghrib": return "Maghrib"
        case "isha": return "Isha"
        default: return prayerKey.capitalized
        }
    }

    static func adhanCopy(prayerKey: String, isFriday: Bool) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday)
        return ("\(name) Adhan", "Tap to hear adhan.")
    }

    static func iqamahCopy(prayerKey: String, isFriday: Bool) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday)
        return ("\(name) Iqamah", "Iqamah for \(name) is now.")
    }

    static func beforeAdhanReminderCopy(prayerKey: String, isFriday: Bool, minutes: Int) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday)
        return ("\(name) soon", "Adhan in \(minutes) min.")
    }

    static func beforeIqamahReminderCopy(prayerKey: String, isFriday: Bool, minutes: Int) -> (title: String, body: String) {
        let name = prayerDisplayName(prayerKey: prayerKey, isFriday: isFriday)
        return ("\(name) Iqamah soon", "Iqamah in \(minutes) min.")
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
