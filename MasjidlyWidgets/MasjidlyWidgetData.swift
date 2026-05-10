import Foundation

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

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sheffieldTimeZone
        let dayStart = calendar.startOfDay(for: now)
        let isFriday = calendar.component(.weekday, from: now) == 6
        
        func wallClockToday(_ time: String) -> Date? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: dayStart)
        }

        let jummahRaw = day.iqamah.jummah.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let jummahIqamahs = jummahRaw.isEmpty ? [day.iqamah.dhuhr] : jummahRaw
        
        struct ResolvedPrayer {
            let id: String
            let name: String
            let adhan: String
            let iqamahs: [String]
            let adhanDate: Date?
        }
        
        let prayersList: [ResolvedPrayer] = [
            ResolvedPrayer(id: "fajr", name: "Fajr", adhan: day.prayers.fajr, iqamahs: [resolveIqamah("fajr", adhan: day.prayers.fajr, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.fajr)),
            ResolvedPrayer(id: "dhuhr", name: isFriday ? "Jumu'ah" : "Dhuhr", adhan: day.prayers.dhuhr, iqamahs: isFriday ? jummahIqamahs : [resolveIqamah("dhuhr", adhan: day.prayers.dhuhr, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.dhuhr)),
            ResolvedPrayer(id: "asr", name: "Asr", adhan: day.prayers.asr, iqamahs: [resolveIqamah("asr", adhan: day.prayers.asr, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.asr)),
            ResolvedPrayer(id: "maghrib", name: "Maghrib", adhan: day.prayers.maghrib, iqamahs: [resolveIqamah("maghrib", adhan: day.prayers.maghrib, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.maghrib)),
            ResolvedPrayer(id: "isha", name: "Isha", adhan: day.prayers.isha, iqamahs: [resolveIqamah("isha", adhan: day.prayers.isha, iqamah: day.iqamah)], adhanDate: wallClockToday(day.prayers.isha))
        ]
        
        var nextPrayerIndex = 0
        for (i, p) in prayersList.enumerated() {
            if let d = p.adhanDate, d > now {
                nextPrayerIndex = i
                break
            }
            if i == prayersList.count - 1 {
                nextPrayerIndex = 0 // Tomorrow's fajr
            }
        }
        
        let next = prayersList[nextPrayerIndex]

        var targetDate = next.adhanDate
        if nextPrayerIndex == 0, let d = targetDate, d <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: d)
        }

        let rawIqamahsForNext: [String] = {
            if isFriday, next.id == "dhuhr" {
                return jummahIqamahs
            }
            return [resolveIqamah(next.id, adhan: next.adhan, iqamah: day.iqamah)]
        }()

        let displayIqamahRaw = nextDisplayIqamahRaw(
            prayerId: next.id,
            isFriday: isFriday,
            rawIqamahs: rawIqamahsForNext,
            adhan: next.adhan,
            now: now,
            wallClock: { wallClockToday($0) }
        )

        let iqamahDate = wallClockToday(displayIqamahRaw)

        let progressStartDate: Date? = {
            if nextPrayerIndex > 0, let prev = prayersList[nextPrayerIndex - 1].adhanDate {
                return prev
            }
            if nextPrayerIndex == 0, prayersList.last.map({ ($0.adhanDate ?? now) <= now }) == true {
                return prayersList.last?.adhanDate
            }
            return calendar.startOfDay(for: now)
        }()

        let (followingName, followingAdhanRaw, followingIqamahRaw): (String, String, String) = {
            if nextPrayerIndex < prayersList.count - 1 {
                let f = prayersList[nextPrayerIndex + 1]
                let iq = f.id == "dhuhr" && isFriday
                    ? nextDisplayIqamahRaw(
                        prayerId: "dhuhr",
                        isFriday: true,
                        rawIqamahs: jummahIqamahs,
                        adhan: f.adhan,
                        now: now,
                        wallClock: { wallClockToday($0) }
                    )
                    : resolveIqamah(f.id, adhan: f.adhan, iqamah: day.iqamah)
                return (f.name, f.adhan, iq)
            }
            let tomorrowString = isoDateString(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            if let morrow = snapshot.days.first(where: { $0.date == tomorrowString }) {
                let iqFajr = resolveIqamah("fajr", adhan: morrow.prayers.fajr, iqamah: morrow.iqamah)
                return ("Fajr", morrow.prayers.fajr, iqFajr)
            }
            return ("", "", "")
        }()

        let rows: [MasjidlyWidgetPrayerRow] = prayersList.enumerated().map { i, p in
            let isNext = i == nextPrayerIndex
            let isPassed = !isNext && ((p.adhanDate ?? now) <= now) && (nextPrayerIndex != 0 || i != 0)

            return MasjidlyWidgetPrayerRow(
                id: p.id,
                name: p.name,
                adhan: format(p.adhan, uses24HourTime: snapshot.uses24HourTime),
                iqamahs: p.iqamahs.map { format($0, uses24HourTime: snapshot.uses24HourTime) },
                isPassed: isPassed,
                isNext: isNext
            )
        }

        let extraJummahCount = isFriday && next.name == "Jumu'ah" ? max(0, jummahIqamahs.count - 1) : 0

        return MasjidlyWidgetState(
            kind: .content,
            mosqueName: snapshot.mosque.name,
            prayerName: next.name,
            adhanTime: format(next.adhan, uses24HourTime: snapshot.uses24HourTime),
            iqamahTime: format(displayIqamahRaw, uses24HourTime: snapshot.uses24HourTime),
            targetDate: targetDate,
            progressStartDate: progressStartDate,
            iqamahDate: iqamahDate,
            extraJummahCount: extraJummahCount,
            rows: rows,
            followingPrayerName: followingName,
            followingAdhanTime: followingAdhanRaw.isEmpty ? "" : format(followingAdhanRaw, uses24HourTime: snapshot.uses24HourTime),
            followingIqamahTime: followingIqamahRaw.isEmpty ? "" : format(followingIqamahRaw, uses24HourTime: snapshot.uses24HourTime)
        )
    }

    /// For Jumu'ah with multiple iqamahs, returns the next iqamah strictly after `now` when adhan has passed; otherwise the first slot.
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

    private static func format(_ time: String, uses24HourTime: Bool) -> String {
        guard !uses24HourTime, isParseableTime(time) else { return time }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let suffix = parts[0] >= 12 ? "pm" : "am"
        let hour = parts[0] % 12 == 0 ? 12 : parts[0] % 12
        return String(format: "%d:%02d%@", hour, parts[1], suffix)
    }
}
