import Foundation

enum WidgetPrayerSharedConfig {
    static let appGroupIdentifier = "group.mikhailspeaks.masjidly"
    static let snapshotKey = "widgetPrayerSnapshot.v1"
    static let snapshotByMosquePrefix = "widgetPrayerSnapshot.v1.mosque."
    static let mosqueDirectoryKey = "widgetMosqueDirectory.v1"
    static let appSelectedMosqueIdKey = "appSelectedMosqueId"
    static let themeModeKey = "widgetThemeMode"
    static let fixedThemeKey = "widgetFixedTheme"
    static let prayerGradientStylesKey = "widgetPrayerGradientStyles"
}

struct WidgetMosqueSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
    let citySlug: String?
    let cityName: String?
    let countryCode: String?
    let countryName: String?
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
    let asrIqamahPreference: AsrIqamahPreference?
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
        try readSnapshot(forMosqueId: nil)
    }

    func readSnapshot(forMosqueId mosqueId: String?) throws -> WidgetPrayerSnapshot {
        guard let defaults else { throw WidgetPrayerSnapshotError.missingAppGroup }
        let keys = snapshotKeys(forMosqueId: mosqueId)
        guard let data = keys.lazy.compactMap({ defaults.data(forKey: $0) }).first else {
            throw WidgetPrayerSnapshotError.missingSnapshot
        }
        let snapshot = try JSONDecoder().decode(WidgetPrayerSnapshot.self, from: data)
        guard snapshot.schemaVersion == WidgetPrayerSnapshot.currentSchemaVersion else {
            throw WidgetPrayerSnapshotError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func writeSnapshot(_ snapshot: WidgetPrayerSnapshot, updateDefault: Bool = true) throws {
        guard let defaults else { throw WidgetPrayerSnapshotError.missingAppGroup }
        let data = try JSONEncoder().encode(snapshot)
        if updateDefault {
            defaults.set(data, forKey: WidgetPrayerSharedConfig.snapshotKey)
        }
        defaults.set(data, forKey: Self.snapshotKey(forMosqueId: snapshot.mosque.id))
    }

    func writeMosqueDirectory(_ mosques: [WidgetMosqueSnapshot]) throws {
        guard let defaults else { throw WidgetPrayerSnapshotError.missingAppGroup }
        let data = try JSONEncoder().encode(mosques)
        defaults.set(data, forKey: WidgetPrayerSharedConfig.mosqueDirectoryKey)
    }

    private func snapshotKeys(forMosqueId mosqueId: String?) -> [String] {
        guard let mosqueId, !mosqueId.isEmpty else { return [WidgetPrayerSharedConfig.snapshotKey] }
        return [Self.snapshotKey(forMosqueId: mosqueId), WidgetPrayerSharedConfig.snapshotKey]
    }

    private static func snapshotKey(forMosqueId mosqueId: String) -> String {
        WidgetPrayerSharedConfig.snapshotByMosquePrefix + mosqueId
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

        guard let next = PrayerTimesEngine.getNextPrayerAndCountdown(
            prayerTimes: day.prayers,
            iqamahTimes: day.iqamah,
            mosqueSlug: snapshot.mosque.slug,
            now: now,
            asrIqamahPreference: snapshot.asrIqamahPreference ?? .first
        ) else {
            return .stale(generatedAt: snapshot.generatedAt)
        }

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
            now: now,
            asrIqamahPreference: snapshot.asrIqamahPreference ?? .first
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
        case "Fajr": return prayers.fajr
        case "Jummah", "Dhuhr": return prayers.dhuhr
        case "Asr": return prayers.asr
        case "Maghrib": return prayers.maghrib
        case "Isha": return prayers.isha
        default: return prayers.fajr
        }
    }

    private static func iqamahTime(
        for prayerName: String,
        prayers: DailyPrayerTimes,
        iqamah: DailyIqamahTimes,
        mosqueSlug: String,
        now: Date,
        asrIqamahPreference: AsrIqamahPreference
    ) -> String {
        switch prayerName {
        case "Fajr":
            return PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: prayers.fajr, iqamahTimes: iqamah)
        case "Jummah":
            let slots = PrayerTimesEngine.splitJummahIqamahTimes(iqamah.jummah)
            guard !slots.isEmpty else { return iqamah.dhuhr }
            guard let dhuhrDate = wallClockToday(prayers.dhuhr, now: now), now >= dhuhrDate else { return slots[0] }
            for slot in slots {
                if let slotDate = wallClockToday(slot, now: now), slotDate > now { return slot }
            }
            return slots.last ?? iqamah.dhuhr
        case "Dhuhr":
            return PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: prayers.dhuhr, iqamahTimes: iqamah)
        case "Asr":
            return PrayerTimesEngine.selectAsrIqamahTime(iqamah.asr, adhanTime: prayers.asr, preference: asrIqamahPreference)
        case "Maghrib":
            return PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: prayers.maghrib, iqamahTimes: iqamah)
        case "Isha":
            return PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: mosqueSlug,
                date: now,
                ishaAdhan: prayers.isha,
                iqamahTimes: iqamah,
                maghribAdhan: prayers.maghrib
            )
        default:
            return ""
        }
    }

    private static func wallClockToday(_ time: String, now: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: cal.startOfDay(for: now))
    }

    private static func snapshotLocale(from raw: String) -> Locale {
        AppLanguage(persistedRawValue: raw).resolvedLocale()
    }

    private static func format(_ time: String, uses24HourTime: Bool, locale: Locale) -> String {
        PrayerTimesEngine.formatPrayerTimeForDisplay(time, uses24Hour: uses24HourTime, locale: locale)
    }
}
