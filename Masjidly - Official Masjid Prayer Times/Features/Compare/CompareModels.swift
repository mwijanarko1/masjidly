import Foundation

enum ComparePrayer: String, CaseIterable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha

    /// Canonical English name used for localization lookups.
    func canonicalName(isJummah: Bool) -> String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return isJummah ? "Jummah" : "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

enum CompareMode: String, Sendable {
    case masjids, byTime
}

enum CompareTimeType: String, Sendable {
    case jamaat, adhan
}

enum CompareDirection: String, Sendable {
    case after, before
}

struct CompareSlot: Equatable, Sendable {
    let raw: String
    var minutes: Int?

    init(raw: String, minutes: Int?) {
        self.raw = raw
        self.minutes = minutes
    }

    /// Builds a slot from an engine value. Returns nil for empty or "no iqamah" values.
    init?(engineValue: String) {
        let trimmed = engineValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if trimmed.isEmpty || trimmed == "-" || lowered == "no iqamah" { return nil }
        self.raw = trimmed
        if trimmed.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil {
            self.minutes = PrayerTimesEngine.timeToMinutes(trimmed)
        } else {
            self.minutes = nil
        }
    }
}

struct CompareDayTimes: Equatable, Sendable {
    let isJummah: Bool
    let iqamah: [ComparePrayer: [CompareSlot]]
    let adhan: [ComparePrayer: String]
    let homeIqamah: [ComparePrayer: CompareSlot]
}

enum CompareDayResolver {
    static func resolve(
        mosque: Mosque,
        date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        asrPreference: AsrIqamahPreference
    ) -> CompareDayTimes? {
        guard let daily = try? PrayerTimesEngine.resolvePrayerTimes(
            on: date,
            monthly: monthly,
            ramadan: ramadan,
            asrTimingPreference: asrPreference
        ),
        let iq = try? PrayerTimesEngine.resolveIqamahTimes(on: date, monthly: monthly, ramadan: ramadan) else {
            return nil
        }
        let slug = mosque.slug
        let isJummah = isFridayInSheffield(date)

        func display(_ prayer: String, adhan: String) -> String {
            PrayerTimesEngine.getDisplayIqamah(
                prayer: prayer, adhanTime: adhan, iqamahTimes: iq,
                mosqueSlug: slug, date: date, maghribAdhan: daily.maghrib
            )
        }

        let fajrValue = PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: daily.fajr, iqamahTimes: iq)
        let maghribValue = display("maghrib", adhan: daily.maghrib)
        let ishaValue = PrayerTimesEngine.resolveIshaIqamahForDisplay(
            slug: slug, date: date, ishaAdhan: daily.isha, iqamahTimes: iq, maghribAdhan: daily.maghrib
        )
        let asrValue = PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhanTime: daily.asr, preference: asrPreference)

        let jummahSlots = PrayerTimesEngine.splitJummahIqamahTimes(iq.jummah)
        let dhuhrHome: String
        let dhuhrSlots: [String]
        if isJummah {
            dhuhrSlots = jummahSlots.isEmpty ? [daily.dhuhr] : jummahSlots
            dhuhrHome = dhuhrSlots[0]
        } else {
            dhuhrHome = display("dhuhr", adhan: daily.dhuhr)
            dhuhrSlots = PrayerTimesEngine.splitIqamahTimes(dhuhrHome)
        }

        let rawSlots: [ComparePrayer: [String]] = [
            .fajr: PrayerTimesEngine.splitIqamahTimes(fajrValue),
            .dhuhr: dhuhrSlots,
            .asr: PrayerTimesEngine.getAsrIqamahSlots(iq.asr, adhanTime: daily.asr),
            .maghrib: PrayerTimesEngine.splitIqamahTimes(maghribValue),
            .isha: PrayerTimesEngine.splitIqamahTimes(ishaValue),
        ]
        let homeValues: [ComparePrayer: String] = [
            .fajr: fajrValue, .dhuhr: dhuhrHome, .asr: asrValue, .maghrib: maghribValue, .isha: ishaValue,
        ]

        var iqamah: [ComparePrayer: [CompareSlot]] = [:]
        var home: [ComparePrayer: CompareSlot] = [:]
        for prayer in ComparePrayer.allCases {
            iqamah[prayer] = (rawSlots[prayer] ?? []).compactMap { CompareSlot(engineValue: $0) }
            if let value = homeValues[prayer], let slot = CompareSlot(engineValue: value) {
                home[prayer] = slot
            }
        }

        return CompareDayTimes(
            isJummah: isJummah,
            iqamah: iqamah,
            adhan: [.fajr: daily.fajr, .dhuhr: daily.dhuhr, .asr: daily.asr, .maghrib: daily.maghrib, .isha: daily.isha],
            homeIqamah: home
        )
    }

    static func isFridayInSheffield(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.component(.weekday, from: date) == 6
    }
}

enum CompareDelta {
    static func minutes(yours: CompareSlot?, other: [CompareSlot]) -> Int? {
        guard let base = yours?.minutes, let earliest = other.compactMap(\.minutes).min() else { return nil }
        return earliest - base
    }

    static func label(_ minutes: Int) -> String {
        if minutes == 0 { return "0" }
        let sign = minutes > 0 ? "+" : "-"
        let magnitude = abs(minutes)
        if magnitude < 60 { return "\(sign)\(magnitude)" }
        let hours = magnitude / 60
        let rest = magnitude % 60
        return rest == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h" + String(format: "%02d", rest)
    }

    /// Visible form: "+15m" under an hour, otherwise the same as `label`.
    static func displayLabel(_ minutes: Int) -> String {
        abs(minutes) > 0 && abs(minutes) < 60 ? label(minutes) + "m" : label(minutes)
    }

    static func isComparable(_ a: Mosque, _ b: Mosque) -> Bool {
        if let ta = a.timezone, let tb = b.timezone, !ta.isEmpty, !tb.isEmpty {
            return ta == tb
        }
        if let ca = a.countryCode, let cb = b.countryCode, !ca.isEmpty, !cb.isEmpty {
            return ca.caseInsensitiveCompare(cb) == .orderedSame
        }
        return false
    }
}

struct CompareFindQuery: Equatable, Sendable {
    var prayer: ComparePrayer?
    var type: CompareTimeType
    var direction: CompareDirection
    var minutes: Int

    static func defaultMinutes(isToday: Bool, now: Date) -> Int {
        guard isToday else { return 720 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let parts = cal.dateComponents([.hour, .minute], from: now)
        let current = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return min(1435, (current / 5 + 1) * 5)
    }
}

struct CompareFindHit: Equatable, Identifiable, Sendable {
    let mosque: Mosque
    let prayer: ComparePrayer
    let raw: String
    let minutes: Int

    var id: String { "\(mosque.id).\(prayer.rawValue).\(raw)" }
}

struct CompareFindResult: Equatable, Sendable {
    let hits: [CompareFindHit]
    let noFixedTimeCount: Int
    /// Slots exactly at the chosen time. Only filled for "before", where they are excluded from `hits`.
    var atTimeHits: [CompareFindHit] = []
}

enum CompareFinder {
    struct Entry: Sendable {
        let mosque: Mosque
        let times: CompareDayTimes
    }

    static func search(query: CompareFindQuery, entries: [Entry]) -> CompareFindResult {
        let scope = query.prayer.map { [$0] } ?? ComparePrayer.allCases
        var hits: [CompareFindHit] = []
        var atTime: [CompareFindHit] = []
        var noFixed = 0

        for entry in entries {
            var hasNoFixed = false
            for prayer in scope {
                let candidates: [CompareSlot]
                switch query.type {
                case .jamaat:
                    let slots = entry.times.iqamah[prayer] ?? []
                    candidates = slots.filter { $0.minutes != nil }
                    if !slots.isEmpty && candidates.isEmpty { hasNoFixed = true }
                case .adhan:
                    candidates = entry.times.adhan[prayer].flatMap { CompareSlot(engineValue: $0) }.map { [$0] } ?? []
                }
                for slot in candidates {
                    guard let minutes = slot.minutes else { continue }
                    let matches = query.direction == .after ? minutes >= query.minutes : minutes < query.minutes
                    if matches {
                        hits.append(CompareFindHit(mosque: entry.mosque, prayer: prayer, raw: slot.raw, minutes: minutes))
                    } else if query.direction == .before && minutes == query.minutes {
                        atTime.append(CompareFindHit(mosque: entry.mosque, prayer: prayer, raw: slot.raw, minutes: minutes))
                    }
                }
            }
            if hasNoFixed { noFixed += 1 }
        }

        func byNameThenPrayer(_ a: CompareFindHit, _ b: CompareFindHit) -> Bool {
            let byName = a.mosque.name.localizedCaseInsensitiveCompare(b.mosque.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.prayer.rawValue < b.prayer.rawValue
        }
        hits.sort { a, b in
            if a.minutes != b.minutes {
                return query.direction == .after ? a.minutes < b.minutes : a.minutes > b.minutes
            }
            return byNameThenPrayer(a, b)
        }
        atTime.sort(by: byNameThenPrayer)
        return CompareFindResult(hits: hits, noFixedTimeCount: noFixed, atTimeHits: atTime)
    }
}
