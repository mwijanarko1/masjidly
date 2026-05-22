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


private enum MasjidlyWidgetSharedConfig {
    static let appGroupIdentifier = "group.mikhailspeaks.masjidly"
    static let snapshotKey = "widgetPrayerSnapshot.v1"
}

struct MasjidlyWidgetMosqueSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
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
        followingIqamahTime: "5:45pm"
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
        followingIqamahTime: ""
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
            followingIqamahTime: ""
        )
    }

    var mosqueDisplayName: String {
        mosqueName.isEmpty ? "Masjidly" : mosqueName
    }

    var accessibilityLabel: String {
        "\(mosqueDisplayName), \(prayerName), adhan \(adhanTime), iqamah \(iqamahTime)"
    }
}

struct MasjidlyWidgetSnapshotStore {
    func readSnapshot() -> MasjidlyWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: MasjidlyWidgetSharedConfig.appGroupIdentifier),
              let data = defaults.data(forKey: MasjidlyWidgetSharedConfig.snapshotKey),
              let snapshot = try? JSONDecoder().decode(MasjidlyWidgetSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else {
            return nil
        }
        return snapshot
    }
}

enum MasjidlyWidgetResolver {
    private static let sheffieldTimeZone = TimeZone(identifier: "Europe/London")!

    static func resolve(snapshot: MasjidlyWidgetSnapshot, now: Date) -> MasjidlyWidgetState {
        let todayString = isoDateString(for: now)
        guard let day = snapshot.days.first(where: { $0.date == todayString }) else {
            return .stale()
        }

        let locale = snapshotLocale(from: snapshot.appLanguageRawValue)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sheffieldTimeZone
        let dayStart = calendar.startOfDay(for: now)
        let isFriday = calendar.component(.weekday, from: now) == 6
        
        func wallClockToday(_ time: String) -> Date? {
            wallClockDay(time, on: dayStart)
        }

        func wallClockDay(_ time: String, on baseDate: Date) -> Date? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: baseDate)
        }

        let jummahRaw = day.iqamah.jummah.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let jummahTimes = jummahRaw.isEmpty ? [day.iqamah.dhuhr] : jummahRaw
        let jummahAdhan = nextDisplayIqamahRaw(
            prayerId: "dhuhr",
            isFriday: isFriday,
            rawIqamahs: jummahTimes,
            adhan: day.prayers.dhuhr,
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
            ResolvedPrayer(id: "fajr", name: names.fajr, adhan: day.prayers.fajr, iqamahs: [resolveIqamah("fajr", adhan: day.prayers.fajr, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.fajr)),
            ResolvedPrayer(id: "dhuhr", name: isFriday ? names.jummah : names.dhuhr, adhan: isFriday ? jummahAdhan : day.prayers.dhuhr, iqamahs: isFriday ? [] : [resolveIqamah("dhuhr", adhan: day.prayers.dhuhr, iqamah: day.iqamah)], adhanDate: wallClockToday(isFriday ? jummahAdhan : day.prayers.dhuhr)),
            ResolvedPrayer(id: "asr", name: names.asr, adhan: day.prayers.asr, iqamahs: [resolveIqamah("asr", adhan: day.prayers.asr, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.asr)),
            ResolvedPrayer(id: "maghrib", name: names.maghrib, adhan: day.prayers.maghrib, iqamahs: [resolveIqamah("maghrib", adhan: day.prayers.maghrib, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.maghrib)),
            ResolvedPrayer(id: "isha", name: names.isha, adhan: day.prayers.isha, iqamahs: [resolveIqamah("isha", adhan: day.prayers.isha, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.isha))
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
                isFriday: isFriday,
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
        
        // Post-Isha wrap detection — all today's prayers/iqamahs have passed, so "next" is tomorrow's Fajr
        let isNextFajrTomorrow = !foundTodayEvent

        let morrowDay: MasjidlyWidgetDaySnapshot? = {
            guard isNextFajrTomorrow else { return nil }
            let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            return snapshot.days.first(where: { $0.date == tomorrowString })
        }()

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
            if isFriday, next.id == "dhuhr" {
                return []
            }
            return [resolveIqamah(next.id, adhan: next.adhan, iqamah: isNextFajrTomorrow ? (morrowDay?.iqamah ?? day.iqamah) : day.iqamah)]
        }()

        let displayIqamahRaw = nextDisplayIqamahRaw(
            prayerId: next.id,
            isFriday: isFriday,
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
            if nextPrayerIndex < prayersList.count - 1 {
                let nextIdx = nextPrayerIndex
                // When wrapping to tomorrow's Fajr, the "following" prayer is tomorrow's Dhuhr
                if isNextFajrTomorrow, let morrow = morrowDay {
                    let morrowStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    let fDhuhrAdhan = morrow.prayers.dhuhr
                    let fDhuhrIqamah = isFriday ? "" : resolveIqamah("dhuhr", adhan: fDhuhrAdhan, iqamah: morrow.iqamah)
                    let fDhuhrDisplayAdhan = isFriday
                        ? nextDisplayIqamahRaw(
                            prayerId: "dhuhr",
                            isFriday: true,
                            rawIqamahs: jummahTimes,
                            adhan: fDhuhrAdhan,
                            now: now,
                            wallClock: { wallClockDay($0, on: morrowStart) }
                        )
                        : fDhuhrAdhan
                    return (isFriday ? names.jummah : names.dhuhr, fDhuhrDisplayAdhan, fDhuhrIqamah)
                }
                let f = prayersList[nextIdx + 1]
                let iq = f.id == "dhuhr" && isFriday ? "" : resolveIqamah(f.id, adhan: f.adhan, iqamah: day.iqamah)
                return (f.name, f.adhan, iq)
            }
            let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            if let morrow = snapshot.days.first(where: { $0.date == tomorrowString }) {
                let iqFajr = resolveIqamah("fajr", adhan: morrow.prayers.fajr, iqamah: morrow.iqamah)
                return (names.fajr, morrow.prayers.fajr, iqFajr)
            }
            return ("", "", "")
        }()

        let rows: [MasjidlyWidgetPrayerRow] = prayersList.enumerated().map { i, p in
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

            return MasjidlyWidgetPrayerRow(
                id: p.id,
                name: p.name,
                adhan: format(rowAdhan, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now),
                iqamahs: rowIqamahs.map { format($0, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now) },
                isPassed: isPassed,
                isNext: isNext
            )
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
            followingIqamahTime: followingIqamahRaw.isEmpty ? "" : format(followingIqamahRaw, uses24HourTime: snapshot.uses24HourTime, locale: locale, reference: now)
        )
    }

    /// For Jummah with multiple iqamahs, returns the next iqamah strictly after `now` when adhan has passed; otherwise the first slot.
    private static func nextDisplayIqamahRaw(
        prayerId: String,
        isFriday: Bool,
        rawIqamahs: [String],
        adhan: String,
        now: Date,
        wallClock: (String) -> Date?
    ) -> String {
        guard prayerId == "dhuhr", isFriday, rawIqamahs.count > 1 else {
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

    private static func resolveIqamah(_ prayer: String, adhan: String, iqamah: MasjidlyWidgetDailyIqamahTimes) -> String {
        let raw: String
        switch prayer {
        case "fajr": raw = iqamah.fajr == "Various" ? adhan : iqamah.fajr
        case "dhuhr": raw = iqamah.dhuhr
        case "asr": raw = iqamah.asr.lowercased() == "entry time" ? adhan : iqamah.asr
        case "maghrib": raw = iqamah.maghrib == "sunset" ? adhan : iqamah.maghrib
        case "isha": raw = iqamah.isha == "Entry Time" ? adhan : iqamah.isha
        default: raw = ""
        }
        return resolveRelativeIqamah(raw, adhan: adhan)
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
            f.timeStyle = .short
            f.dateStyle = .none
        }
        return f.string(from: date)
    }
}
