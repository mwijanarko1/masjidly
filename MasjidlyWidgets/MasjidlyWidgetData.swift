import Foundation

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


enum MasjidlyWidgetSharedConfig {
    static let appGroupIdentifier = "group.mikhailspeaks.masjidly"
    static let snapshotKey = "widgetPrayerSnapshot.v1"
    static let snapshotByMosquePrefix = "widgetPrayerSnapshot.v1.mosque."
    static let mosqueDirectoryKey = "widgetMosqueDirectory.v1"
    static let appSelectedMosqueIdKey = "appSelectedMosqueId"
    static let themeModeKey = "widgetThemeMode"
    static let fixedThemeKey = "widgetFixedTheme"
    static let prayerGradientStylesKey = "widgetPrayerGradientStyles"
    static let prayerCustomGradientColorsKey = "widgetPrayerCustomGradientColors"
}

struct MasjidlyWidgetMosqueSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
    let citySlug: String?
    let cityName: String?
    let countryCode: String?
    let countryName: String?

    var cityDisplayName: String { cityName?.nilIfBlank ?? "Sheffield" }
    var countryDisplayName: String { countryName?.nilIfBlank ?? countryCode?.nilIfBlank ?? "United Kingdom" }
    var countryOptionValue: String { countryDisplayName }
    var cityOptionValue: String { cityDisplayName }
}

struct MasjidlyWidgetDaySnapshot: Codable, Equatable, Sendable {
    let date: String
    let prayers: MasjidlyWidgetDailyPrayerTimes
    let iqamah: MasjidlyWidgetDailyIqamahTimes
}

struct MasjidlyWidgetSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let mosque: MasjidlyWidgetMosqueSnapshot
    let days: [MasjidlyWidgetDaySnapshot]
    let uses24HourTime: Bool
    let appLanguageRawValue: String
    let asrIqamahPreference: String?
}

struct MasjidlyWidgetDailyPrayerTimes: Codable, Equatable, Sendable {
    var date: String
    var fajr: String
    var sunrise: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
}

struct MasjidlyWidgetDailyIqamahTimes: Codable, Equatable, Sendable {
    var fajr: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
    var jummah: String
}

struct MasjidlyWidgetPrayerRow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let adhan: String
    let iqamahs: [String]
    let isPassed: Bool
    let isNext: Bool
}

enum MasjidlyWidgetStateKind: Equatable, Sendable {
    case content
    case missing
    case stale
}

struct MasjidlyWidgetState: Equatable, Sendable {
    let kind: MasjidlyWidgetStateKind
    let mosqueName: String
    /// Canonical prayer identifier used for icons/themes independent of display language.
    let prayerId: String
    let prayerName: String
    let adhanTime: String
    let iqamahTime: String
    /// Next adhan (or tomorrow Fajr) — primary countdown target before adhan.
    let targetDate: Date?
    /// Start of the optional progress ring interval (previous adhan or start of day).
    let progressStartDate: Date?
    /// Iqamah instant for the current focus prayer (same day wall clock).
    let iqamahDate: Date?
    let extraJummahCount: Int
    let rows: [MasjidlyWidgetPrayerRow]
    /// Prayer after the current next prayer (e.g. Maghrib when next is Asr). Omitted when unknown.
    let followingPrayerName: String
    let followingAdhanTime: String
    let followingIqamahTime: String
    /// Date for display purposes (may differ from WidgetKit entry.date for post-Isha medium/large widgets).
    let displayDate: Date

    static let placeholder = MasjidlyWidgetState(
        kind: .content,
        mosqueName: "Masjidly",
        prayerId: "dhuhr",
        prayerName: "Dhuhr",
        adhanTime: "1:10pm",
        iqamahTime: "1:30pm",
        targetDate: Date().addingTimeInterval(3600),
        progressStartDate: Date().addingTimeInterval(-1800),
        iqamahDate: Date().addingTimeInterval(3900),
        extraJummahCount: 0,
        rows: [
            MasjidlyWidgetPrayerRow(id: "fajr", name: "Fajr", adhan: "5:00am", iqamahs: ["5:20am"], isPassed: true, isNext: false),
            MasjidlyWidgetPrayerRow(id: "dhuhr", name: "Dhuhr", adhan: "1:10pm", iqamahs: ["1:30pm"], isPassed: false, isNext: true),
            MasjidlyWidgetPrayerRow(id: "asr", name: "Asr", adhan: "5:30pm", iqamahs: ["5:45pm"], isPassed: false, isNext: false),
            MasjidlyWidgetPrayerRow(id: "maghrib", name: "Maghrib", adhan: "8:45pm", iqamahs: ["8:50pm"], isPassed: false, isNext: false),
            MasjidlyWidgetPrayerRow(id: "isha", name: "Isha", adhan: "10:15pm", iqamahs: ["10:30pm"], isPassed: false, isNext: false)
        ],
        followingPrayerName: "Asr",
        followingAdhanTime: "5:30pm",
        followingIqamahTime: "5:45pm",
        displayDate: Date()
    )

    static let missing = MasjidlyWidgetState(
        kind: .missing,
        mosqueName: "Masjidly",
        prayerId: "",
        prayerName: "Open Masjidly",
        adhanTime: "--:--",
        iqamahTime: "--:--",
        targetDate: nil,
        progressStartDate: nil,
        iqamahDate: nil,
        extraJummahCount: 0,
        rows: [],
        followingPrayerName: "",
        followingAdhanTime: "",
        followingIqamahTime: "",
        displayDate: Date()
    )

    static func stale() -> MasjidlyWidgetState {
        MasjidlyWidgetState(
            kind: .stale,
            mosqueName: "Masjidly",
            prayerId: "",
            prayerName: "Open Masjidly to refresh",
            adhanTime: "--:--",
            iqamahTime: "--:--",
            targetDate: nil,
            progressStartDate: nil,
            iqamahDate: nil,
            extraJummahCount: 0,
            rows: [],
            followingPrayerName: "",
            followingAdhanTime: "",
            followingIqamahTime: "",
            displayDate: Date()
        )
    }

    var mosqueDisplayName: String {
        mosqueName.isEmpty ? "Masjidly" : mosqueName
    }

    var accessibilityLabel: String {
        "\(mosqueDisplayName), \(prayerName), adhan \(adhanTime), iqamah \(iqamahTime)"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct MasjidlyWidgetSnapshotStore {
    func readSnapshot() -> MasjidlyWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: MasjidlyWidgetSharedConfig.appGroupIdentifier) else {
            return nil
        }
        let selectedId = defaults.string(forKey: MasjidlyWidgetSharedConfig.appSelectedMosqueIdKey) ?? ""
        let keys = selectedId.isEmpty
            ? [MasjidlyWidgetSharedConfig.snapshotKey]
            : [MasjidlyWidgetSharedConfig.snapshotByMosquePrefix + selectedId, MasjidlyWidgetSharedConfig.snapshotKey]
        guard let data = keys.lazy.compactMap({ defaults.data(forKey: $0) }).first,
              let snapshot = try? JSONDecoder().decode(MasjidlyWidgetSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else {
            return nil
        }
        return snapshot
    }
}



enum MasjidlyWidgetResolver {
    private static let sheffieldTimeZone = TimeZone(identifier: "Europe/London")!

    static func resolve(snapshot: MasjidlyWidgetSnapshot, now: Date, includeTomorrowFajr: Bool = true) -> MasjidlyWidgetState {
        let todayString = isoDateString(for: now)
        guard let day = snapshot.days.first(where: { $0.date == todayString }) else {
            return .stale()
        }
        var resolvedDay = day

        let locale = snapshotLocale(from: snapshot.appLanguageRawValue)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sheffieldTimeZone
        var dayStart = calendar.startOfDay(for: now)

        func wallClockDay(_ time: String, on baseDate: Date) -> Date? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: baseDate)
        }

        func wallClockToday(_ time: String) -> Date? {
            wallClockDay(time, on: dayStart)
        }

        // ── Medium/large widgets: advance to tomorrow after Isha iqamah + 10 min ──
        if !includeTomorrowFajr {
            let ishaIqamahRaw = resolveIqamah("isha", adhan: resolvedDay.prayers.isha, iqamah: resolvedDay.iqamah, mosqueSlug: snapshot.mosque.slug, date: now, maghribAdhan: resolvedDay.prayers.maghrib)
            if let ishaCutoff = wallClockDay(ishaIqamahRaw, on: dayStart)?.addingTimeInterval(10 * 60),
               now >= ishaCutoff {
                let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
                if let tomorrowDay = snapshot.days.first(where: { $0.date == tomorrowString }) {
                    resolvedDay = tomorrowDay
                    dayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                }
            }
        }

        let resolvedIsFriday = calendar.component(.weekday, from: dayStart) == 6

        let jummahRaw = splitJummahIqamahTimes(resolvedDay.iqamah.jummah)
        let jummahTimes = jummahRaw.isEmpty ? [resolvedDay.iqamah.dhuhr] : jummahRaw
        let jummahAdhan = nextDisplayIqamahRaw(
            prayerId: "dhuhr",
            isFriday: resolvedIsFriday,
            rawIqamahs: jummahTimes,
            adhan: resolvedDay.prayers.dhuhr,
            now: now,
            wallClock: { wallClockToday($0) }
        )
        
        struct ResolvedPrayer {
            let id: String
            let name: String
            let adhan: String
            let iqamahs: [String]
            let adhanDate: Date?
        }
        
        let lang = AppLanguage(persistedRawValue: snapshot.appLanguageRawValue)
        let names = localizedPrayerNames(for: lang)
        let prayersList: [ResolvedPrayer] = [
            ResolvedPrayer(id: "fajr", name: names.fajr, adhan: resolvedDay.prayers.fajr, iqamahs: [resolveIqamah("fajr", adhan: resolvedDay.prayers.fajr, iqamah: resolvedDay.iqamah)], adhanDate: wallClockToday(resolvedDay.prayers.fajr)),
            ResolvedPrayer(id: "dhuhr", name: resolvedIsFriday ? jummahDisplayName(base: names.jummah, selectedRaw: jummahAdhan, allSlots: jummahTimes) : names.dhuhr, adhan: resolvedIsFriday ? jummahAdhan : resolvedDay.prayers.dhuhr, iqamahs: resolvedIsFriday ? jummahTimes : [resolveIqamah("dhuhr", adhan: resolvedDay.prayers.dhuhr, iqamah: resolvedDay.iqamah)], adhanDate: wallClockToday(resolvedIsFriday ? jummahAdhan : resolvedDay.prayers.dhuhr)),
            ResolvedPrayer(id: "asr", name: names.asr, adhan: resolvedDay.prayers.asr, iqamahs: [selectAsrIqamah(resolveIqamah("asr", adhan: resolvedDay.prayers.asr, iqamah: resolvedDay.iqamah), preference: snapshot.asrIqamahPreference)], adhanDate: wallClockToday(resolvedDay.prayers.asr)),
            ResolvedPrayer(id: "maghrib", name: names.maghrib, adhan: resolvedDay.prayers.maghrib, iqamahs: [resolveIqamah("maghrib", adhan: resolvedDay.prayers.maghrib, iqamah: resolvedDay.iqamah)], adhanDate: wallClockToday(resolvedDay.prayers.maghrib)),
            ResolvedPrayer(id: "isha", name: names.isha, adhan: resolvedDay.prayers.isha, iqamahs: [resolveIqamah("isha", adhan: resolvedDay.prayers.isha, iqamah: resolvedDay.iqamah, mosqueSlug: snapshot.mosque.slug, date: now, maghribAdhan: resolvedDay.prayers.maghrib)], adhanDate: wallClockToday(resolvedDay.prayers.isha))
        ]
        
        var nextPrayerIndex = 0
        var nextEventDate: Date?
        var nextEventIsIqamah = false
        var foundTodayEvent = false
        for (i, p) in prayersList.enumerated() {
            if let adhanDate = p.adhanDate, adhanDate > now {
                nextPrayerIndex = i
                nextEventDate = adhanDate
                nextEventIsIqamah = false
                foundTodayEvent = true
                break
            }

            let candidateIqamah = nextDisplayIqamahRaw(
                prayerId: p.id,
                isFriday: resolvedIsFriday,
                rawIqamahs: p.iqamahs,
                adhan: p.adhan,
                now: now,
                wallClock: { wallClockToday($0) }
            )
            if isParseableTime(candidateIqamah), candidateIqamah != p.adhan,
               let iqamahDate = wallClockToday(candidateIqamah), iqamahDate > now {
                nextPrayerIndex = i
                nextEventDate = iqamahDate
                nextEventIsIqamah = true
                foundTodayEvent = true
                break
            }
        }
        
        // Post-Isha wrap detection — all today's prayers/iqamahs have passed.
        // Small Home Screen and Lock Screen widgets keep showing tomorrow Fajr because they do not show a date.
        // Medium/Large Home Screen widgets show today's Isha instead because their date header makes tomorrow Fajr confusing.
        if !foundTodayEvent, !includeTomorrowFajr {
            nextPrayerIndex = max(0, prayersList.count - 1)
            nextEventIsIqamah = false
        }
        let isNextFajrTomorrow = !foundTodayEvent && includeTomorrowFajr

        let morrowDay: MasjidlyWidgetDaySnapshot? = {
            guard isNextFajrTomorrow else { return nil }
            let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            return snapshot.days.first(where: { $0.date == tomorrowString })
        }()

        // If all today events have passed and tomorrow's data is missing,
        // show stale instead of incorrectly falling back to today's Fajr.
        if isNextFajrTomorrow, morrowDay == nil {
            return .stale()
        }

        let next: ResolvedPrayer = {
            if isNextFajrTomorrow, let morrow = morrowDay {
                return ResolvedPrayer(
                    id: "fajr",
                    name: names.fajr,
                    adhan: morrow.prayers.fajr,
                    iqamahs: [resolveIqamah("fajr", adhan: morrow.prayers.fajr, iqamah: morrow.iqamah)],
                    adhanDate: wallClockDay(morrow.prayers.fajr, on: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
                )
            }
            return prayersList[nextPrayerIndex]
        }()

        let targetDate = isNextFajrTomorrow ? next.adhanDate : nextEventDate

        let nextWallClockBase: Date = isNextFajrTomorrow
            ? (calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            : dayStart

        let rawIqamahsForNext: [String] = {
            if resolvedIsFriday, next.id == "dhuhr" {
                return jummahTimes
            }
            return [resolveIqamah(
                next.id,
                adhan: next.adhan,
                iqamah: isNextFajrTomorrow ? (morrowDay?.iqamah ?? day.iqamah) : day.iqamah,
                mosqueSlug: snapshot.mosque.slug,
                date: nextWallClockBase,
                maghribAdhan: (isNextFajrTomorrow ? morrowDay?.prayers.maghrib : day.prayers.maghrib) ?? day.prayers.maghrib
            )]
        }()

        let displayIqamahRaw = nextDisplayIqamahRaw(
            prayerId: next.id,
            isFriday: resolvedIsFriday,
            rawIqamahs: rawIqamahsForNext,
            adhan: next.adhan,
            now: now,
            wallClock: { wallClockDay($0, on: nextWallClockBase) }
        )

        let iqamahDate = wallClockDay(displayIqamahRaw, on: nextWallClockBase)

        let progressStartDate: Date? = {
            if nextEventIsIqamah {
                return next.adhanDate
            }
            if nextPrayerIndex > 0, let prev = prayersList[nextPrayerIndex - 1].adhanDate {
                return prev
            }
            if isNextFajrTomorrow {
                return prayersList.last?.adhanDate
            }
            return calendar.startOfDay(for: now)
        }()

        let (followingName, followingAdhanRaw, followingIqamahRaw): (String, String, String) = {
            if !foundTodayEvent, !includeTomorrowFajr {
                return ("", "", "")
            }
            if nextPrayerIndex < prayersList.count - 1 {
                let nextIdx = nextPrayerIndex
                // When wrapping to tomorrow's Fajr, the "following" prayer is tomorrow's Dhuhr
                if isNextFajrTomorrow, let morrow = morrowDay {
                    let morrowStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    let fDhuhrAdhan = morrow.prayers.dhuhr
                    let fDhuhrIqamah = resolvedIsFriday ? "" : resolveIqamah("dhuhr", adhan: fDhuhrAdhan, iqamah: morrow.iqamah)
                    let fDhuhrDisplayAdhan = resolvedIsFriday
                        ? nextDisplayIqamahRaw(
                            prayerId: "dhuhr",
                            isFriday: resolvedIsFriday,
                            rawIqamahs: jummahTimes,
                            adhan: fDhuhrAdhan,
                            now: now,
                            wallClock: { wallClockDay($0, on: morrowStart) }
                        )
                        : fDhuhrAdhan
                    let fName = resolvedIsFriday ? jummahDisplayName(base: names.jummah, selectedRaw: fDhuhrDisplayAdhan, allSlots: jummahTimes) : names.dhuhr
                    return (fName, fDhuhrDisplayAdhan, fDhuhrIqamah)
                }
                let f = prayersList[nextIdx + 1]
                let iq = f.id == "dhuhr" && resolvedIsFriday ? "" : resolveIqamah(f.id, adhan: f.adhan, iqamah: resolvedDay.iqamah, mosqueSlug: snapshot.mosque.slug, date: now, maghribAdhan: resolvedDay.prayers.maghrib)
                return (f.name, f.adhan, iq)
            }
            guard includeTomorrowFajr else { return ("", "", "") }
            let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            if let morrow = snapshot.days.first(where: { $0.date == tomorrowString }) {
                let iqFajr = resolveIqamah("fajr", adhan: morrow.prayers.fajr, iqamah: morrow.iqamah)
                return (names.fajr, morrow.prayers.fajr, iqFajr)
            }
            return ("", "", "")
        }()

        let rows: [MasjidlyWidgetPrayerRow] = prayersList.enumerated().flatMap { i, p in
            let isNext = i == nextPrayerIndex
            let isPassed: Bool

            if isNextFajrTomorrow, i == 0 {
                // Fajr row shows tomorrow's times when we've wrapped
                isPassed = false
            } else {
                isPassed = !isNext && ((p.adhanDate ?? now) <= now) && (nextPrayerIndex != 0 || i != 0)
            }

            // Override row data with morrow when wrapping to tomorrow's Fajr
            let rowAdhan: String
            let rowIqamahs: [String]
            if isNextFajrTomorrow, i == 0, let morrow = morrowDay {
                rowAdhan = morrow.prayers.fajr
                rowIqamahs = [resolveIqamah("fajr", adhan: morrow.prayers.fajr, iqamah: morrow.iqamah)]
            } else {
                rowAdhan = p.adhan
                rowIqamahs = p.iqamahs
            }

            if resolvedIsFriday, p.id == "dhuhr", jummahTimes.count > 1 {
                return jummahTimes.enumerated().map { idx, slot in
                    MasjidlyWidgetPrayerRow(
                        id: "jummah_\(idx)",
                        name: "\(names.jummah) \(idx + 1)",
                        adhan: format(rowAdhan, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
                        iqamahs: [format(slot, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now)],
                        isPassed: isPassed,
                        isNext: isNext && slot == jummahAdhan
                    )
                }
            }

            return [MasjidlyWidgetPrayerRow(
                id: p.id,
                name: p.name,
                adhan: format(rowAdhan, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
                iqamahs: rowIqamahs.map { format($0, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now) },
                isPassed: isPassed,
                isNext: isNext
            )]
        }

        let extraJummahCount = 0

        return MasjidlyWidgetState(
            kind: .content,
            mosqueName: snapshot.mosque.name,
            prayerId: next.id,
            prayerName: next.name,
            adhanTime: format(next.adhan, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
            iqamahTime: format(displayIqamahRaw, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
            targetDate: targetDate,
            progressStartDate: progressStartDate,
            iqamahDate: iqamahDate,
            extraJummahCount: extraJummahCount,
            rows: rows,
            followingPrayerName: followingName,
            followingAdhanTime: followingAdhanRaw.isEmpty ? "" : format(followingAdhanRaw, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
            followingIqamahTime: followingIqamahRaw.isEmpty ? "" : format(followingIqamahRaw, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
            displayDate: dayStart
        )
    }

    private static func jummahDisplayName(base: String, selectedRaw: String, allSlots: [String]) -> String {
        guard allSlots.count > 1 else { return base }
        let selected = selectedRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = allSlots.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == selected }) {
            return "\(base) \(idx + 1)"
        }
        return base
    }

    private static func splitJummahIqamahTimes(_ raw: String?) -> [String] {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let whitespaceBetweenTimes = try? NSRegularExpression(pattern: #"(\d{1,2}:\d{2})\s+(?=\d{1,2}:\d{2})"#)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let normalized = whitespaceBetweenTimes?.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "$1,") ?? trimmed
        return normalized
            .components(separatedBy: CharacterSet(charactersIn: ",/&|\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// For multi-slot Jummah/Asr, returns the next iqamah strictly after `now` when adhan has passed; otherwise the first slot.
    private static func nextDisplayIqamahRaw(
        prayerId: String,
        isFriday: Bool,
        rawIqamahs: [String],
        adhan: String,
        now: Date,
        wallClock: (String) -> Date?
    ) -> String {
        let supportsMultipleSlots = (prayerId == "dhuhr" && isFriday) || prayerId == "asr"
        guard supportsMultipleSlots, rawIqamahs.count > 1 else {
            return rawIqamahs.first ?? ""
        }
        guard let adhanDate = wallClock(adhan) else {
            return rawIqamahs.first ?? ""
        }
        if now < adhanDate {
            return rawIqamahs.first ?? ""
        }
        for raw in rawIqamahs {
            if let d = wallClock(raw), d > now {
                return raw
            }
        }
        return rawIqamahs.last ?? ""
    }



    // MARK: - Localized Prayer Names

    private struct LocalizedNames {
        let fajr: String
        let dhuhr: String
        let asr: String
        let maghrib: String
        let isha: String
        let jummah: String
    }

    /// Returns prayer display names in the app's selected language.
    /// Because the widget extension cannot access the host app's .lproj bundles,
    /// names are resolved from a hardcoded table matching `Localizable.xcstrings`.
    private static func localizedPrayerNames(for lang: AppLanguage) -> LocalizedNames {
        switch lang {
        case .arabic:
            return LocalizedNames(fajr: "الفجر", dhuhr: "الظهر", asr: "العصر", maghrib: "المغرب", isha: "العشاء", jummah: "الجمعة")
        case .urdu:
            return LocalizedNames(fajr: "فجر", dhuhr: "ظہر", asr: "عصر", maghrib: "مغرب", isha: "عشاء", jummah: "جمعہ")
        case .indonesian:
            return LocalizedNames(fajr: "Fajr", dhuhr: "Dzuhur", asr: "Asr", maghrib: "Maghrib", isha: "Isha", jummah: "Jumat")
        case .english:
            return LocalizedNames(fajr: "Fajr", dhuhr: "Dhuhr", asr: "Asr", maghrib: "Maghrib", isha: "Isha", jummah: "Jummah")
        }
    }

    private static func resolveIqamah(
        _ prayer: String,
        adhan: String,
        iqamah: MasjidlyWidgetDailyIqamahTimes,
        mosqueSlug: String = "",
        date: Date = Date(),
        maghribAdhan: String = ""
    ) -> String {
        let raw: String
        switch prayer {
        case "fajr": raw = iqamah.fajr == "Various" ? adhan : iqamah.fajr
        case "dhuhr": raw = iqamah.dhuhr
        case "asr":
            if iqamah.asr.lowercased() == "entry time" {
                raw = adhan
            } else {
                raw = selectAsrIqamah(iqamah.asr, adhan: adhan)
            }
        case "maghrib": raw = iqamah.maghrib == "sunset" ? adhan : iqamah.maghrib
        case "isha":
            if isMasjidRisalah(mosqueSlug), isRisalahIshaIqamahMatchesAdhanPeriod(date) {
                raw = adhan
            } else if isMuslimWelfareHouse(mosqueSlug), isSummerIshaPeriod(date) {
                raw = "After Maghrib"
            } else if iqamah.isha == "Straight after Maghrib" {
                raw = maghribAdhan.isEmpty ? adhan : maghribAdhan
            } else {
                raw = iqamah.isha == "Entry Time" ? adhan : iqamah.isha
            }
        default: raw = ""
        }
        return resolveRelativeIqamah(raw, adhan: adhan)
    }

    private static func selectAsrIqamah(_ raw: String, adhan: String? = nil, preference: String? = nil) -> String {
        if raw.lowercased() == "entry time" { return adhan ?? raw }
        let slots = splitJummahIqamahTimes(raw).map { slot in
            if let adhan { return resolveRelativeIqamah(slot, adhan: adhan) }
            return slot
        }
        let resolved = slots.isEmpty ? [adhan.map { resolveRelativeIqamah(raw, adhan: $0) } ?? raw] : slots
        if preference == "second" { return resolved.dropFirst().first ?? resolved.first ?? "" }
        return resolved.first ?? ""
    }

    private static func isMasjidRisalah(_ slug: String) -> Bool {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "masjid-risalah"
    }

    private static func isMuslimWelfareHouse(_ slug: String) -> Bool {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "muslim-welfare-house"
    }

    private static func isSummerIshaPeriod(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let y = cal.component(.year, from: date)
        guard let may15 = cal.date(from: DateComponents(year: y, month: 5, day: 15, hour: 12)),
              let aug15 = cal.date(from: DateComponents(year: y, month: 8, day: 15, hour: 12)) else { return false }
        return date >= may15 && date <= aug15
    }

    private static func isRisalahIshaIqamahMatchesAdhanPeriod(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let y = cal.component(.year, from: date)
        guard let may1 = cal.date(from: DateComponents(year: y, month: 5, day: 1, hour: 12)),
              let july31 = cal.date(from: DateComponents(year: y, month: 7, day: 31, hour: 12)) else { return false }
        return date >= may1 && date <= july31
    }

    private static func resolveRelativeIqamah(_ value: String, adhan: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^adhan\s*\+\s*(\d+)\s*(?:mins?|minutes?)?$"#,
            #"^(\d+)\s*(?:mins?|minutes?)\s*after\s*adhan$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  let range = Range(match.range(at: 1), in: trimmed),
                  let minutes = Int(trimmed[range]) else { continue }
            return addMinutes(to: adhan, minutes: minutes) ?? value
        }
        return value
    }

    private static func addMinutes(to time: String, minutes: Int) -> String? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let total = (((parts[0] * 60 + parts[1] + minutes) % 1_440) + 1_440) % 1_440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private static func isoDateString(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sheffieldTimeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func isParseableTime(_ time: String) -> Bool {
        if time.isEmpty || time == "-" || time == "--:--" { return false }
        return time.range(of: #"^(\d{1,2}):(\d{2})$"#, options: .regularExpression) != nil
    }

    private static func snapshotLocale(from raw: String) -> Locale {
        AppLanguage(persistedRawValue: raw).resolvedLocale()
    }

    private static func prayerWallClockDate(hour: Int, minute: Int, reference: Date) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let parts = cal.dateComponents([.year, .month, .day], from: reference)
        return cal.date(from: DateComponents(
            year: parts.year, month: parts.month, day: parts.day,
            hour: hour, minute: minute
        ))
    }

    private static func format(_ time: String, uses24HourTime: Bool, locale: Locale, reference: Date) -> String {
        guard isParseableTime(time) else { return time }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, let date = prayerWallClockDate(hour: parts[0], minute: parts[1], reference: reference) else {
            return time
        }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = sheffieldTimeZone
        if uses24HourTime {
            f.setLocalizedDateFormatFromTemplate("HHmm")
        } else {
            f.dateFormat = "h:mma"
        }
        return f.string(from: date)
    }
}
