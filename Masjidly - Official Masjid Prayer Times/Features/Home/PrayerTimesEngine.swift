import Foundation

/// Prayer-time resolution ported from Sheffield-Masjids `src/lib/prayer-times.ts` (subset for iOS MVP).
enum PrayerTimesEngine {
    static let sheffieldTimeZone = TimeZone(identifier: "Europe/London")!
    private static let risalahSlug = "masjid-risalah"

    // MARK: - Calendar (Sheffield)

    static func getDateInSheffield(_ date: Date) -> (year: Int, month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func sheffieldNoonUTC(year: Int, month: Int, day: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static func isoDateString(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func splitIqamahTimes(_ raw: String?) -> [String] {
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

    static func splitJummahIqamahTimes(_ raw: String?) -> [String] {
        splitIqamahTimes(raw)
    }

    static func getAsrIqamahSlots(_ asrIqamah: String, adhanTime: String) -> [String] {
        if asrIqamah.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "entry time" { return [adhanTime] }
        let slots = splitIqamahTimes(asrIqamah).map { resolveRelativeIqamah($0, adhanTime: adhanTime) }
        return slots.isEmpty ? [resolveRelativeIqamah(asrIqamah, adhanTime: adhanTime)] : slots
    }

    static func selectAsrIqamahTime(_ asrIqamah: String, adhanTime: String, preference: AsrIqamahPreference = .first) -> String {
        let slots = getAsrIqamahSlots(asrIqamah, adhanTime: adhanTime)
        switch preference {
        case .first:
            return slots.first ?? ""
        case .second:
            return slots.dropFirst().first ?? slots.first ?? ""
        }
    }

    static func selectAsrAdhanTime(_ prayerTime: PrayerTime, preference: AsrIqamahPreference = .first) -> String {
        if preference == .second, let asrMithl2 = prayerTime.asrMithl2, !asrMithl2.isEmpty {
            return asrMithl2
        }
        return prayerTime.asr
    }

    static func selectAsrAdhanTime(_ prayerTime: RamadanPrayerDay, preference: AsrIqamahPreference = .first) -> String {
        if preference == .second, let asrMithl2 = prayerTime.asrMithl2, !asrMithl2.isEmpty {
            return asrMithl2
        }
        return prayerTime.asr
    }

    static func normalizeMosqueSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isMasjidRisalah(slug: String) -> Bool {
        normalizeMosqueSlug(slug) == risalahSlug
    }

    private static func isMuslimWelfareHouse(slug: String) -> Bool {
        normalizeMosqueSlug(slug) == normalizeMosqueSlug(MosqueDefaults.defaultSlug)
    }

    // MARK: - Sparse rows

    static func findDayData(_ prayerTimes: [PrayerTime], dayOfMonth: Int) -> PrayerTime? {
        var closestPrevious: PrayerTime?
        var earliest: PrayerTime?

        for day in prayerTimes {
            if earliest == nil || day.date < earliest!.date { earliest = day }
            if day.date == dayOfMonth { return day }
            if day.date <= dayOfMonth {
                if closestPrevious == nil || day.date > closestPrevious!.date {
                    closestPrevious = day
                }
            }
        }
        return closestPrevious ?? earliest
    }

    static func findRamadanDayData(_ prayerTimes: [RamadanPrayerDay], ramadanDay: Int) -> RamadanPrayerDay? {
        var closestPrevious: RamadanPrayerDay?
        var earliest: RamadanPrayerDay?

        for day in prayerTimes {
            if earliest == nil || day.ramadanDay < earliest!.ramadanDay { earliest = day }
            if day.ramadanDay == ramadanDay { return day }
            if day.ramadanDay <= ramadanDay {
                if closestPrevious == nil || day.ramadanDay > closestPrevious!.ramadanDay {
                    closestPrevious = day
                }
            }
        }
        return closestPrevious ?? earliest
    }

    // MARK: - Iqāmah ranges

    static func getIqamahTimesForDate(dayOfMonth: Int, iqamahRanges: [IqamahTimeRange]) throws -> DailyIqamahTimes {
        for range in iqamahRanges {
            let parts = range.dateRange.split(separator: "-").compactMap { Int($0) }
            guard let start = parts.first else { continue }
            let end = parts.count > 1 ? parts[1] : nil
            if end == nil {
                if dayOfMonth == start {
                    return dailyFromRange(range)
                }
            } else if let e = end, dayOfMonth >= start, dayOfMonth <= e {
                return dailyFromRange(range)
            }
        }
        throw PrayerEngineError.noIqamahRange(dayOfMonth)
    }

    private static func dailyFromRange(_ range: IqamahTimeRange) -> DailyIqamahTimes {
        DailyIqamahTimes(
            fajr: range.fajr,
            dhuhr: range.dhuhr,
            asr: range.asr,
            maghrib: range.maghrib ?? "sunset",
            isha: range.isha,
            jummah: range.jummah?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    // MARK: - Isha / summer / Risalah

    static func isSummerIshaPeriod(date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let y = cal.component(.year, from: date)
        guard let may15 = cal.date(from: DateComponents(year: y, month: 5, day: 15, hour: 12)),
              let aug15 = cal.date(from: DateComponents(year: y, month: 8, day: 15, hour: 12)) else { return false }
        return date >= may15 && date <= aug15
    }

    static func isRisalahIshaIqamahMatchesAdhanPeriod(date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let y = cal.component(.year, from: date)
        guard let may1 = cal.date(from: DateComponents(year: y, month: 5, day: 1, hour: 12)),
              let july31 = cal.date(from: DateComponents(year: y, month: 7, day: 31, hour: 12)) else { return false }
        return date >= may1 && date <= july31
    }

    static func resolveIshaIqamahForDisplay(
        slug: String,
        date: Date,
        ishaAdhan: String,
        iqamahTimes: DailyIqamahTimes,
        maghribAdhan: String
    ) -> String {
        if isMasjidRisalah(slug: slug), isRisalahIshaIqamahMatchesAdhanPeriod(date: date) {
            return ishaAdhan
        }
        if isMuslimWelfareHouse(slug: slug), isSummerIshaPeriod(date: date) {
            return "After Maghrib"
        }
        return getIqamahTime(prayer: "isha", adhanTime: ishaAdhan, iqamahTimes: iqamahTimes, maghribAdhan: maghribAdhan)
    }

    /// Centralized iqamah display resolution.
    /// For Isha, applies special mosque/season rules via `resolveIshaIqamahForDisplay`;
    /// for all other prayers, delegates to `getIqamahTime`.
    /// Use this everywhere iqamah is shown to ensure home, timetable, and widgets agree.
    static func getDisplayIqamah(
        prayer: String,
        adhanTime: String,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        date: Date,
        maghribAdhan: String
    ) -> String {
        let p = prayer.lowercased()
        if p == "isha" {
            return resolveIshaIqamahForDisplay(
                slug: mosqueSlug,
                date: date,
                ishaAdhan: adhanTime,
                iqamahTimes: iqamahTimes,
                maghribAdhan: maghribAdhan
            )
        }
        return getIqamahTime(prayer: p, adhanTime: adhanTime, iqamahTimes: iqamahTimes, maghribAdhan: maghribAdhan)
    }

    static func getIqamahTime(prayer: String, adhanTime: String, iqamahTimes: DailyIqamahTimes, maghribAdhan: String? = nil) -> String {
        let p = prayer.lowercased()
        switch p {
        case "fajr":
            let raw = iqamahTimes.fajr == "Various" ? adhanTime : iqamahTimes.fajr
            return resolveRelativeIqamah(raw, adhanTime: adhanTime)
        case "dhuhr":
            return resolveRelativeIqamah(iqamahTimes.dhuhr, adhanTime: adhanTime)
        case "asr":
            if iqamahTimes.asr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "entry time" { return adhanTime }
            return selectAsrIqamahTime(iqamahTimes.asr, adhanTime: adhanTime)
        case "maghrib":
            let raw = iqamahTimes.maghrib == "sunset" ? adhanTime : iqamahTimes.maghrib
            return resolveRelativeIqamah(raw, adhanTime: adhanTime)
        case "isha":
            if iqamahTimes.isha == "Straight after Maghrib" {
                if let m = maghribAdhan { return m }
                return adhanTime
            }
            if iqamahTimes.isha == "Entry Time" { return adhanTime }
            return resolveRelativeIqamah(iqamahTimes.isha, adhanTime: adhanTime)
        case "jummah":
            return iqamahTimes.jummah
        default:
            return "-"
        }
    }

    private static func addMinutesToTime(_ time: String, minutesToAdd: Int) -> String? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let total = (((parts[0] * 60 + parts[1] + minutesToAdd) % 1440) + 1440) % 1440
        let h = total / 60
        let m = total % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Duha begins 15 minutes after sunrise and ends 15 minutes before Dhuhr.
    static func duhaWindow(sunrise: String, dhuhr: String) -> (start: String, end: String)? {
        guard let start = addMinutesToTime(sunrise, minutesToAdd: 15),
              let end = addMinutesToTime(dhuhr, minutesToAdd: -15) else { return nil }
        return (start, end)
    }

    private static func resolveRelativeIqamah(_ iqamahValue: String, adhanTime: String) -> String {
        let value = iqamahValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = try? NSRegularExpression(pattern: #"^adhan\s*\+\s*(\d+)\s*(?:mins?|minutes?)?$"#, options: .caseInsensitive),
           let match = r.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r2 = Range(match.range(at: 1), in: value),
           let mins = Int(value[r2]) {
            return addMinutesToTime(adhanTime, minutesToAdd: mins) ?? iqamahValue
        }
        if let r = try? NSRegularExpression(pattern: #"^(\d+)\s*(?:mins?|minutes?)\s*after\s*adhan$"#, options: .caseInsensitive),
           let match = r.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let r2 = Range(match.range(at: 1), in: value),
           let mins = Int(value[r2]) {
            return addMinutesToTime(adhanTime, minutesToAdd: mins) ?? iqamahValue
        }
        return iqamahValue
    }

    // MARK: - Ramadan

    static func isDateWithinRamadanRange(date: Date, ramadan: RamadanPrayerData) -> Bool {
        let (y, m, d) = getDateInSheffield(date)
        let dateStr = isoDateString(year: y, month: m, day: d)
        return dateStr >= ramadan.gregorianStart && dateStr <= ramadan.gregorianEnd
    }

    static func getRamadanDay(date: Date, ramadan: RamadanPrayerData) -> Int {
        let (y, m, d) = getDateInSheffield(date)
        let start = sheffieldNoonUTCFromISO(ramadan.gregorianStart)
        let dateAtNoon = sheffieldNoonUTC(year: y, month: m, day: d)
        let diffMs = dateAtNoon.timeIntervalSince1970 - start.timeIntervalSince1970
        let diffDays = Int(floor(diffMs / 86400))
        return min(30, max(1, diffDays + 1))
    }

    private static func sheffieldNoonUTCFromISO(_ yyyyMMdd: String) -> Date {
        let parts = yyyyMMdd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return sheffieldNoonUTC(year: parts[0], month: parts[1], day: parts[2])
    }

    // MARK: - Resolve day (monthly vs Ramadan)

    static func resolvePrayerTimes(
        on date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        asrTimingPreference: AsrIqamahPreference = .first
    ) throws -> DailyPrayerTimes {
        let (y, m, d) = getDateInSheffield(date)
        let dateStr = isoDateString(year: y, month: m, day: d)

        if let r = ramadan, isDateWithinRamadanRange(date: date, ramadan: r) {
            let ramadanDay = getRamadanDay(date: date, ramadan: r)
            guard let row = findRamadanDayData(r.prayerTimes, ramadanDay: ramadanDay) else {
                throw PrayerEngineError.missingRamadanRow
            }
            return DailyPrayerTimes(
                date: dateStr,
                fajr: row.fajr,
                sunrise: row.shurooq,
                dhuhr: row.dhuhr,
                asr: selectAsrAdhanTime(row, preference: asrTimingPreference),
                maghrib: row.maghrib,
                isha: row.isha
            )
        }

        guard let monthly else { throw PrayerEngineError.missingMonthly }
        guard let adhan = findDayData(monthly.prayerTimes, dayOfMonth: d) else {
            throw PrayerEngineError.missingDayRow
        }
        return DailyPrayerTimes(
            date: dateStr,
            fajr: adhan.fajr,
            sunrise: adhan.shurooq,
            dhuhr: adhan.dhuhr,
            asr: selectAsrAdhanTime(adhan, preference: asrTimingPreference),
            maghrib: adhan.maghrib,
            isha: adhan.isha
        )
    }

    static func resolveIqamahTimes(
        on date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?
    ) throws -> DailyIqamahTimes {
        let (_, _, d) = getDateInSheffield(date)

        if let r = ramadan, isDateWithinRamadanRange(date: date, ramadan: r) {
            let ramadanDay = getRamadanDay(date: date, ramadan: r)
            let iq = try getIqamahTimesForDate(dayOfMonth: ramadanDay, iqamahRanges: r.iqamahTimes)
            let j = iq.jummah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? r.jummahIqamah : iq.jummah
            return DailyIqamahTimes(fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j)
        }

        guard let monthly else { throw PrayerEngineError.missingMonthly }
        guard findDayData(monthly.prayerTimes, dayOfMonth: d) != nil else {
            throw PrayerEngineError.missingDayRow
        }
        let iq = try getIqamahTimesForDate(dayOfMonth: d, iqamahRanges: monthly.iqamahTimes)
        let j = iq.jummah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? monthly.jummahIqamah : iq.jummah
        return DailyIqamahTimes(fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j)
    }

    // MARK: - Hero circle countdown (widget-aligned)

    /// Label semantics for the home hero countdown (matches `MasjidlyWidgetResolver` phase rules).
    static func heroCountdownPresentation(
        prayerTimes: DailyPrayerTimes,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        now: Date = Date(),
        asrIqamahPreference: AsrIqamahPreference = .first
    ) -> HeroCountdownPresentation? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let dayStart = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: now)
        let isFriday = weekday == 6
        let checkDate = dayStart

        func wallClockToday(_ time: String) -> Date? {
            let p = time.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2 else { return nil }
            return cal.date(bySettingHour: p[0], minute: p[1], second: 0, of: dayStart)
        }

        let jummahRaw = splitJummahIqamahTimes(iqamahTimes.jummah)
        let jummahTimes: [String] = jummahRaw.isEmpty ? [iqamahTimes.dhuhr] : jummahRaw
        let jummahAdhan = nextHeroDisplayIqamahRaw(
            prayerId: "dhuhr",
            isFriday: isFriday,
            rawIqamahs: jummahTimes,
            adhan: prayerTimes.dhuhr,
            now: now,
            wallClock: { wallClockToday($0) }
        )

        struct ResolvedHeroPrayer {
            let id: String
            let name: String
            let adhan: String
            let iqamahs: [String]
            let adhanDate: Date?
        }

        let slug = mosqueSlug

        let prayersList: [ResolvedHeroPrayer] = [
            ResolvedHeroPrayer(
                id: "fajr",
                name: "Fajr",
                adhan: prayerTimes.fajr,
                iqamahs: [getIqamahTime(prayer: "fajr", adhanTime: prayerTimes.fajr, iqamahTimes: iqamahTimes)],
                adhanDate: wallClockToday(prayerTimes.fajr)
            ),
            ResolvedHeroPrayer(
                id: "dhuhr",
                name: isFriday ? "Jummah" : "Dhuhr",
                adhan: isFriday ? jummahAdhan : prayerTimes.dhuhr,
                iqamahs: isFriday ? [] : [getIqamahTime(prayer: "dhuhr", adhanTime: prayerTimes.dhuhr, iqamahTimes: iqamahTimes)],
                adhanDate: wallClockToday(isFriday ? jummahAdhan : prayerTimes.dhuhr)
            ),
            ResolvedHeroPrayer(
                id: "asr",
                name: "Asr",
                adhan: prayerTimes.asr,
                iqamahs: [selectAsrIqamahTime(iqamahTimes.asr, adhanTime: prayerTimes.asr, preference: asrIqamahPreference)],
                adhanDate: wallClockToday(prayerTimes.asr)
            ),
            ResolvedHeroPrayer(
                id: "maghrib",
                name: "Maghrib",
                adhan: prayerTimes.maghrib,
                iqamahs: [getIqamahTime(prayer: "maghrib", adhanTime: prayerTimes.maghrib, iqamahTimes: iqamahTimes)],
                adhanDate: wallClockToday(prayerTimes.maghrib)
            ),
            ResolvedHeroPrayer(
                id: "isha",
                name: "Isha",
                adhan: prayerTimes.isha,
                iqamahs: [
                    resolveIshaIqamahForDisplay(
                        slug: slug,
                        date: checkDate,
                        ishaAdhan: prayerTimes.isha,
                        iqamahTimes: iqamahTimes,
                        maghribAdhan: prayerTimes.maghrib
                    )
                ],
                adhanDate: wallClockToday(prayerTimes.isha)
            )
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

            let candidateIqamah = nextHeroDisplayIqamahRaw(
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

        guard foundTodayEvent, let targetDate = nextEventDate else {
            return nil
        }

        let next = prayersList[nextPrayerIndex]
        let progressStartDate: Date = {
            if nextEventIsIqamah {
                return next.adhanDate ?? dayStart
            }
            if nextPrayerIndex > 0, let prev = prayersList[nextPrayerIndex - 1].adhanDate {
                return prev
            }
            return dayStart
        }()

        let labelKind: HeroCountdownLabelKind = {
            if nextEventIsIqamah { return .iqamahIn }
            if nextPrayerIndex == 0 { return .adhanIn }
            return .nextPrayer
        }()

        return HeroCountdownPresentation(
            labelKind: labelKind,
            targetDate: targetDate,
            progressStartDate: progressStartDate
        )
    }

    /// Jummah multi-slot: next iqamah strictly after `now` once adhan has passed; otherwise first slot.
    private static func nextHeroDisplayIqamahRaw(
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

    /// Hero tap countdown: leading `-`, then `H:MM:SS` if ≥ 1 hour, else `M:SS` (minutes unpadded, seconds zero-padded).
    static func formatHeroCountdownClock(totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        if s >= 3600 {
            let h = s / 3600
            let rem = s % 3600
            let m = rem / 60
            let sec = rem % 60
            return "-\(h):\(String(format: "%02d", m)):\(String(format: "%02d", sec))"
        }
        let m = s / 60
        let sec = s % 60
        return "-\(m):\(String(format: "%02d", sec))"
    }

    // MARK: - Next prayer / countdown

    static func getNextPrayerAndCountdown(
        prayerTimes: DailyPrayerTimes,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        now: Date = Date(),
        asrIqamahPreference: AsrIqamahPreference = .first,
        includeTomorrowFajr: Bool = true
    ) -> NextPrayerCountdownResult? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let dayStart = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: now)
        let isFriday = weekday == 6
        let checkDate = dayStart

        func wallClockToday(_ hhmm: String) -> Date? {
            let p = hhmm.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2 else { return nil }
            return cal.date(bySettingHour: p[0], minute: p[1], second: 0, of: dayStart)
        }

        let slug = mosqueSlug

        let jummahRaw = splitJummahIqamahTimes(iqamahTimes.jummah)
        let jummahTimes = jummahRaw.isEmpty ? [iqamahTimes.dhuhr] : jummahRaw
        let jummahAdhan = nextHeroDisplayIqamahRaw(
            prayerId: "dhuhr",
            isFriday: isFriday,
            rawIqamahs: jummahTimes,
            adhan: prayerTimes.dhuhr,
            now: now,
            wallClock: { wallClockToday($0) }
        )

        let prayers: [(name: String, adhan: String, iqamah: String)] = [
            ("Fajr", prayerTimes.fajr, getIqamahTime(prayer: "fajr", adhanTime: prayerTimes.fajr, iqamahTimes: iqamahTimes)),
            (isFriday ? "Jummah" : "Dhuhr", isFriday ? jummahAdhan : prayerTimes.dhuhr, isFriday ? "" : getIqamahTime(prayer: "dhuhr", adhanTime: prayerTimes.dhuhr, iqamahTimes: iqamahTimes)),
            (
                "Asr",
                prayerTimes.asr,
                selectAsrIqamahTime(iqamahTimes.asr, adhanTime: prayerTimes.asr, preference: asrIqamahPreference)
            ),
            ("Maghrib", prayerTimes.maghrib, getIqamahTime(prayer: "maghrib", adhanTime: prayerTimes.maghrib, iqamahTimes: iqamahTimes)),
            ("Isha", prayerTimes.isha, resolveIshaIqamahForDisplay(slug: slug, date: checkDate, ishaAdhan: prayerTimes.isha, iqamahTimes: iqamahTimes, maghribAdhan: prayerTimes.maghrib)),
        ]

        for prayer in prayers {
            let isJummah = prayer.name == "Jummah"
            if let adhanT = wallClockToday(prayer.adhan), adhanT > now {
                let diff = Int(adhanT.timeIntervalSince(now))
                return NextPrayerCountdownResult(nextName: prayer.name, nextTime: prayer.adhan, totalSeconds: diff, isIqamah: false, isJummah: isJummah)
            }
            if !isJummah, isParseableTime(prayer.iqamah), prayer.iqamah != prayer.adhan, let iqT = wallClockToday(prayer.iqamah), iqT > now {
                let diff = Int(iqT.timeIntervalSince(now))
                return NextPrayerCountdownResult(nextName: prayer.name, nextTime: prayer.iqamah, totalSeconds: diff, isIqamah: true, isJummah: false)
            }
        }

        guard includeTomorrowFajr else {
            return nil
        }

        if let fajrT = wallClockToday(prayers[0].adhan),
           let tomorrow = cal.date(byAdding: .day, value: 1, to: dayStart),
           let nextFajr = cal.date(bySettingHour: cal.component(.hour, from: fajrT), minute: cal.component(.minute, from: fajrT), second: 0, of: tomorrow) {
            let diff = Int(nextFajr.timeIntervalSince(now))
            return NextPrayerCountdownResult(nextName: "Fajr", nextTime: prayers[0].adhan, totalSeconds: max(0, diff), isIqamah: false, isJummah: false)
        }

        return nil
    }

    // MARK: - Midnight / Last Third of the Night

    /// Parse "HH:mm" to total minutes since midnight.
    static func timeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// Format total minutes since midnight to "HH:mm".
    static func minutesToTime(_ minutes: Int) -> String {
        let clamped = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// Compute Midnight and Last Third of the night.
    /// Night period: from today's Maghrib to **next day's Fajr**.
    /// Midnight = midpoint of the night; Last Third starts at 2/3 through.
    /// Both are returned as "HH:mm" in 24-hour format.
    /// If `nextDayFajr` is nil or unparseable, both values are nil.
    static func computeMidnightAndLastThird(maghrib: String, nextDayFajr: String?) -> (midnight: String?, lastThird: String?) {
        guard let nextFajr = nextDayFajr,
              isParseableTime(maghrib),
              isParseableTime(nextFajr),
              let maghribMin = timeToMinutes(maghrib),
              let fajrMin = timeToMinutes(nextFajr) else {
            return (nil, nil)
        }

        // Night duration (handles times crossing midnight)
        let nightDuration: Int
        if fajrMin >= maghribMin {
            nightDuration = fajrMin - maghribMin
        } else {
            nightDuration = (24 * 60 - maghribMin) + fajrMin
        }

        guard nightDuration > 0 else { return (nil, nil) }

        let midnight = minutesToTime(maghribMin + nightDuration / 2)
        let lastThird = minutesToTime(maghribMin + (nightDuration * 2) / 3)

        return (midnight, lastThird)
    }

    // MARK: - Time parsing helpers

    private static func isParseableTime(_ t: String) -> Bool {
        if t.isEmpty || t == "-" || t == "—" || t == "--:--" { return false }
        if t.range(of: "after maghrib|entry time|straight after", options: .regularExpression) != nil { return false }
        let m = t.trimmingCharacters(in: .whitespacesAndNewlines).range(of: #"^(\d{1,2}):(\d{2})$"#, options: .regularExpression)
        return m != nil
    }

    /// Wall-clock instant on today's Sheffield calendar date (for locale-aware time formatting only).
    private static func prayerWallClockDate(hour: Int, minute: Int, referenceNow: Date = Date()) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let ymd = getDateInSheffield(referenceNow)
        return cal.date(from: DateComponents(year: ymd.year, month: ymd.month, day: ymd.day, hour: hour, minute: minute))
    }

    /// Formats an `HH:mm` prayer clock for UI using `locale` (digits, separators, AM/PM).
    /// Non-clock strings (e.g. “sunset”) are returned unchanged.
    static func formatPrayerTimeForDisplay(_ timeString: String, uses24Hour: Bool, locale: Locale) -> String {
        guard isParseableTime(timeString) else { return timeString }
        let p = timeString.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, let date = prayerWallClockDate(hour: p[0], minute: p[1]) else { return timeString }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = sheffieldTimeZone
        if uses24Hour {
            f.setLocalizedDateFormatFromTemplate("HHmm")
        } else {
            f.dateFormat = "h:mma"
        }
        return f.string(from: date)
    }

    /// Hero clock uses separate `h:mm` + `a` strings so AM/PM sits tight; `formatPrayerTimeForDisplay` uses `DateFormatter` short style, whose NBSP between time and meridiem grows visually at large sizes.
    static func formatPrayerTimeHeroParts(_ timeString: String, uses24Hour: Bool, locale: Locale) -> (clock: String, meridiem: String?) {
        guard isParseableTime(timeString) else { return (timeString, nil) }
        let p = timeString.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, let date = prayerWallClockDate(hour: p[0], minute: p[1]) else { return (timeString, nil) }
        if uses24Hour {
            let f = DateFormatter()
            f.locale = locale
            f.timeZone = sheffieldTimeZone
            f.setLocalizedDateFormatFromTemplate("HHmm")
            return (f.string(from: date), nil)
        }
        let clockDF = DateFormatter()
        clockDF.locale = locale
        clockDF.timeZone = sheffieldTimeZone
        clockDF.dateFormat = "h:mm"
        let meridiemDF = DateFormatter()
        meridiemDF.locale = locale
        meridiemDF.timeZone = sheffieldTimeZone
        meridiemDF.dateFormat = "a"
        return (clockDF.string(from: date), meridiemDF.string(from: date))
    }

    static func formatTo12Hour(_ timeString: String) -> String {
        if !isParseableTime(timeString) { return timeString }
        let p = timeString.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return timeString }
        let ampm = p[0] >= 12 ? "pm" : "am"
        let h12 = p[0] % 12 == 0 ? 12 : p[0] % 12
        return String(format: "%d:%02d%@", h12, p[1], ampm)
    }

    /// Maps a next-prayer name to the home letter-picker index (F, S, D, A, M, I).
    /// Jummah shares Dhuhr's slot (index 2).
    static func homeLetterIndex(forNextName name: String?) -> Int? {
        guard let name else { return nil }
        switch name.lowercased() {
        case "fajr": return 0
        case "sunrise": return 1
        case "dhuhr", "jummah": return 2
        case "asr": return 3
        case "maghrib": return 4
        case "isha": return 5
        default: return nil
        }
    }

    /// Letter index to auto-select / mark as current when viewing today.
    /// `countdownResolved` means today's next-prayer check ran (iqamah available).
    /// When that check returns no next prayer, fall back to Isha.
    static func homeCurrentPrayerIndex(nextName: String?, isToday: Bool, countdownResolved: Bool) -> Int? {
        guard isToday else { return nil }
        if let index = homeLetterIndex(forNextName: nextName) { return index }
        return countdownResolved ? 5 : nil
    }
}

struct NextPrayerCountdownResult: Equatable, Sendable {
    let nextName: String
    let nextTime: String
    let totalSeconds: Int
    let isIqamah: Bool
    let isJummah: Bool

    var hours: Int { totalSeconds / 3600 }
    var minutes: Int { (totalSeconds % 3600) / 60 }
    var seconds: Int { totalSeconds % 60 }
}

enum HeroCountdownLabelKind: Equatable, Sendable {
    case adhanIn
    case iqamahIn
    case nextPrayer
}

/// Widget-aligned interval for the home hero progress ring (`MasjidlyWidgetResolver` semantics).
struct HeroCountdownPresentation: Equatable, Sendable {
    let labelKind: HeroCountdownLabelKind
    let targetDate: Date
    let progressStartDate: Date

    func remainingSeconds(at now: Date) -> Int {
        max(0, Int(floor(targetDate.timeIntervalSince(now))))
    }

    /// Elapsed fraction of `[progressStartDate, targetDate]` — matches accessory widget ring.
    func progress01(at now: Date) -> Double {
        let span = targetDate.timeIntervalSince(progressStartDate)
        guard span > 0 else { return 0 }
        let t = now.timeIntervalSince(progressStartDate) / span
        return min(1, max(0, t))
    }
}

enum PrayerEngineError: Error {
    case noIqamahRange(Int)
    case missingMonthly
    case missingDayRow
    case missingRamadanRow
}
