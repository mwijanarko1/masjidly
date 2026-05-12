import Foundation

enum WidgetPrayerSharedConfig {
    static let appGroupIdentifier = "group.mikhailspeaks.masjidly"
    static let snapshotKey = "widgetPrayerSnapshot.v1"
}

struct WidgetMosqueSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
}

struct WidgetPrayerDaySnapshot: Codable, Equatable, Sendable {
    let date: String
    let prayers: DailyPrayerTimes
    let iqamah: DailyIqamahTimes
}

struct WidgetPrayerSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let mosque: WidgetMosqueSnapshot
    let days: [WidgetPrayerDaySnapshot]
    let uses24HourTime: Bool
    let appLanguageRawValue: String
}

enum WidgetPrayerStateKind: String, Codable, Equatable, Sendable {
    case content
    case missing
    case stale
}

struct WidgetPrayerState: Codable, Equatable, Sendable {
    let kind: WidgetPrayerStateKind
    let mosqueName: String
    let prayerName: String
    let adhanTime: String
    let iqamahTime: String
    let isIqamah: Bool
    let generatedAt: Date?

    static func missing() -> WidgetPrayerState {
        WidgetPrayerState(
            kind: .missing,
            mosqueName: "",
            prayerName: "Open Masjidly",
            adhanTime: "--:--",
            iqamahTime: "--:--",
            isIqamah: false,
            generatedAt: nil
        )
    }

    static func stale(generatedAt: Date?) -> WidgetPrayerState {
        WidgetPrayerState(
            kind: .stale,
            mosqueName: "",
            prayerName: "Open Masjidly to refresh",
            adhanTime: "--:--",
            iqamahTime: "--:--",
            isIqamah: false,
            generatedAt: generatedAt
        )
    }
}

enum WidgetPrayerSnapshotError: Error, Equatable {
    case missingAppGroup
    case missingSnapshot
    case unsupportedSchema(Int)
}

struct WidgetPrayerSnapshotStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: WidgetPrayerSharedConfig.appGroupIdentifier)) {
        self.defaults = defaults
    }

    func readSnapshot() throws -> WidgetPrayerSnapshot {
        guard let defaults else { throw WidgetPrayerSnapshotError.missingAppGroup }
        guard let data = defaults.data(forKey: WidgetPrayerSharedConfig.snapshotKey) else {
            throw WidgetPrayerSnapshotError.missingSnapshot
        }
        let snapshot = try JSONDecoder().decode(WidgetPrayerSnapshot.self, from: data)
        guard snapshot.schemaVersion == WidgetPrayerSnapshot.currentSchemaVersion else {
            throw WidgetPrayerSnapshotError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func writeSnapshot(_ snapshot: WidgetPrayerSnapshot) throws {
        guard let defaults else { throw WidgetPrayerSnapshotError.missingAppGroup }
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: WidgetPrayerSharedConfig.snapshotKey)
    }
}

enum WidgetPrayerResolver {
    static func resolve(snapshot: WidgetPrayerSnapshot, now: Date = Date()) throws -> WidgetPrayerState {
        guard snapshot.schemaVersion == WidgetPrayerSnapshot.currentSchemaVersion else {
            throw WidgetPrayerSnapshotError.unsupportedSchema(snapshot.schemaVersion)
        }

        let today = PrayerTimesEngine.getDateInSheffield(now)
        let todayString = PrayerTimesEngine.isoDateString(year: today.year, month: today.month, day: today.day)
        guard let day = snapshot.days.first(where: { $0.date == todayString }) else {
            return .stale(generatedAt: snapshot.generatedAt)
        }

        let next = PrayerTimesEngine.getNextPrayerAndCountdown(
            prayerTimes: day.prayers,
            iqamahTimes: day.iqamah,
            mosqueSlug: snapshot.mosque.slug,
            now: now
        )

        // Post-Isha wrap: when the next prayer is Fajr but today's Fajr wall clock has passed,
        // load tomorrow's snapshot for the adhan/iqamah display values
        let isFajrTomorrow: Bool = {
            guard next.nextName == "Fajr", !next.isIqamah else { return false }
            // Confirm today's Fajr has actually passed (differentiates post-Isha wrap from pre-Fajr)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
            let todayStart = cal.startOfDay(for: now)
            let parts = day.prayers.fajr.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2,
                  let todayFajr = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: todayStart)
            else { return false }
            return todayFajr <= now
        }()
        let morrowDay: WidgetPrayerDaySnapshot? = {
            guard isFajrTomorrow else { return nil }
            let tomorrowDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrow = PrayerTimesEngine.getDateInSheffield(tomorrowDate)
            let tomorrowString = PrayerTimesEngine.isoDateString(year: tomorrow.year, month: tomorrow.month, day: tomorrow.day)
            return snapshot.days.first(where: { $0.date == tomorrowString })
        }()

        let useDay = morrowDay ?? day

        let adhan = adhanTime(for: next.nextName, prayers: useDay.prayers)
        let iqamah = iqamahTime(
            for: next.nextName,
            prayers: useDay.prayers,
            iqamah: useDay.iqamah,
            mosqueSlug: snapshot.mosque.slug,
            now: now
        )
        let locale = snapshotLocale(from: snapshot.appLanguageRawValue)

        return WidgetPrayerState(
            kind: .content,
            mosqueName: snapshot.mosque.name,
            prayerName: next.nextName,
            adhanTime: format(adhan, uses24HourTime: snapshot.uses24HourTime, locale: locale),
            iqamahTime: format(iqamah, uses24HourTime: snapshot.uses24HourTime, locale: locale),
            isIqamah: next.isIqamah,
            generatedAt: snapshot.generatedAt
        )
    }

    private static func adhanTime(for prayerName: String, prayers: DailyPrayerTimes) -> String {
        switch prayerName {
        case "Fajr": prayers.fajr
        case "Jummah", "Dhuhr": prayers.dhuhr
        case "Asr": prayers.asr
        case "Maghrib": prayers.maghrib
        case "Isha": prayers.isha
        default: prayers.fajr
        }
    }

    private static func iqamahTime(
        for prayerName: String,
        prayers: DailyPrayerTimes,
        iqamah: DailyIqamahTimes,
        mosqueSlug: String,
        now: Date
    ) -> String {
        switch prayerName {
        case "Fajr":
            PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: prayers.fajr, iqamahTimes: iqamah)
        case "Jummah":
            iqamah.jummah
        case "Dhuhr":
            PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: prayers.dhuhr, iqamahTimes: iqamah)
        case "Asr":
            PrayerTimesEngine.getIqamahTime(prayer: "asr", adhanTime: prayers.asr, iqamahTimes: iqamah)
        case "Maghrib":
            PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: prayers.maghrib, iqamahTimes: iqamah)
        case "Isha":
            PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: mosqueSlug,
                date: now,
                ishaAdhan: prayers.isha,
                iqamahTimes: iqamah,
                maghribAdhan: prayers.maghrib
            )
        default:
            ""
        }
    }

    private static func snapshotLocale(from raw: String) -> Locale {
        Locale(identifier: "en")
    }

    private static func format(_ time: String, uses24HourTime: Bool, locale: Locale) -> String {
        PrayerTimesEngine.formatPrayerTimeForDisplay(time, uses24Hour: uses24HourTime, locale: locale)
    }
}
