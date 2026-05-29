import Foundation

/// Prayer-time resolution ported from Sheffield-Masjids `src/lib/prayer-times.ts` (subset for iOS MVP).
enum PrayerTimesEngine {
    static let sheffieldTimeZone = TimeZone(identifier: "Europe/London")!
    private static let risalahSlug = "masjid-risalah"
    private static let dstMosqueSlugs: Set<String> = ["masjid-al-huda-sheffield"]

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

    static func normalizeMosqueSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isMasjidRisalah(slug: String) -> Bool {
        normalizeMosqueSlug(slug) == risalahSlug
    }

    private static func isMuslimWelfareHouse(slug: String) -> Bool {
        normalizeMosqueSlug(slug) == normalizeMosqueSlug(MosqueDefaults.defaultSlug)
    }

    static func mosqueTimetableAlreadyIncludesDst(slug: String) -> Bool {
        dstMosqueSlugs.contains(normalizeMosqueSlug(slug))
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
            return resolveRelativeIqamah(iqamahTimes.asr, adhanTime: adhanTime)
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

    // MARK: - Embedded DST table remap (Masjid Al-Huda)

    private static func dhuhrToMinutes(_ t: PrayerTime) -> Int? {
        let parts = t.dhuhr.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    static func detectMarchSummerStartDayInTable(prayerTimes: [PrayerTime]) -> Int? {
        let sorted = prayerTimes.sorted { $0.date < $1.date }
        var bestDay: Int?
        var bestJump = 0
        for i in 1..<sorted.count {
            guard let a = dhuhrToMinutes(sorted[i - 1]), let b = dhuhrToMinutes(sorted[i]) else { continue }
            let jump = b - a
            if jump > bestJump {
                bestJump = jump
                bestDay = sorted[i].date
            }
        }
        return bestJump >= 45 ? bestDay : nil
    }

    static func detectOctoberWinterStartDayInTable(prayerTimes: [PrayerTime]) -> Int? {
        let sorted = prayerTimes.sorted { $0.date < $1.date }
        var bestDay: Int?
        var bestFall = 0
        for i in 1..<sorted.count {
            guard let a = dhuhrToMinutes(sorted[i - 1]), let b = dhuhrToMinutes(sorted[i]) else { continue }
            let fall = a - b
            if fall > bestFall {
                bestFall = fall
                bestDay = sorted[i].date
            }
        }
        return bestFall >= 45 ? bestDay : nil
    }

    static func resolveTimetableDayForUkEmbeddedDst(
        calendarDay: Int,
        transitionDayInTable: Int,
        ukTransitionDay: Int,
        maxTableDay: Int
    ) -> Int {
        let t = transitionDayInTable
        let u = ukTransitionDay
        if t == u { return calendarDay }
        let low = min(t, u)
        let high = max(t, u) - 1
        if calendarDay < low || calendarDay > high { return calendarDay }
        return min(maxTableDay, max(1, calendarDay + (t - u)))
    }

    private static func maxPrayerTableDay(prayerTimes: [PrayerTime], year: Int, month: Int) -> Int {
        let m = max(0, prayerTimes.map(\.date).max() ?? 0)
        if m > 0 { return m }
        let cal = Calendar(identifier: .gregorian)
        return cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: year, month: month))!)?.count ?? 31
    }

    private static func getLastSundayOfMonth(year: Int, month: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let lastDay = cal.date(from: DateComponents(year: year, month: month + 1, day: 0)) else { return 25 }
        let wd = cal.component(.weekday, from: lastDay)
        let last = cal.component(.day, from: lastDay)
        let sunday = 1
        let offset = (wd - sunday + 7) % 7
        return last - offset
    }

    static func getUkMarchSpringForwardDay(year: Int, dstDates: [UkDstYear]) -> Int {
        if let row = dstDates.first(where: { $0.year == year }) {
            let seg = row.startDate.split(separator: "-").map(String.init)
            if seg.count == 3, let mo = Int(seg[1]), let d = Int(seg[2]), mo == 3, (1...31).contains(d) {
                return d
            }
        }
        return getLastSundayOfMonth(year: year, month: 3)
    }

    static func resolveEmbeddedDstTimetableDayOfMonth(
        slug: String,
        month: Int,
        year: Int,
        calendarDay: Int,
        prayerTimes: [PrayerTime],
        dstDates: [UkDstYear]
    ) -> Int {
        guard mosqueTimetableAlreadyIncludesDst(slug: slug), month == 3 || month == 10 else {
            return calendarDay
        }
        let maxDay = maxPrayerTableDay(prayerTimes: prayerTimes, year: year, month: month)
        if month == 3 {
            guard let t = detectMarchSummerStartDayInTable(prayerTimes: prayerTimes) else { return calendarDay }
            let u = getUkMarchSpringForwardDay(year: year, dstDates: dstDates)
            return resolveTimetableDayForUkEmbeddedDst(
                calendarDay: calendarDay,
                transitionDayInTable: t,
                ukTransitionDay: u,
                maxTableDay: maxDay
            )
        }
        guard let t = detectOctoberWinterStartDayInTable(prayerTimes: prayerTimes) else { return calendarDay }
        var u = getLastSundayOfMonth(year: year, month: 10)
        if let row = dstDates.first(where: { $0.year == year }) {
            let seg = row.endDate.split(separator: "-").map(String.init)
            if seg.count == 3, let mo = Int(seg[1]), let d = Int(seg[2]), mo == 10, (1...31).contains(d) {
                u = d
            }
        }
        return resolveTimetableDayForUkEmbeddedDst(
            calendarDay: calendarDay,
            transitionDayInTable: t,
            ukTransitionDay: u,
            maxTableDay: maxDay
        )
    }

    static func resolveMonthlyDayDisplay(
        slug: String,
        year: Int,
        month: Int,
        calendarDay: Int,
        monthlyData: MonthPrayerData,
        dstDates: [UkDstYear]
    ) -> (adhan: PrayerTime, iqamahLookupDay: Int)? {
        let iqamahLookupDay = resolveEmbeddedDstTimetableDayOfMonth(
            slug: slug,
            month: month,
            year: year,
            calendarDay: calendarDay,
            prayerTimes: monthlyData.prayerTimes,
            dstDates: dstDates
        )
        guard let adhan = findDayData(monthlyData.prayerTimes, dayOfMonth: iqamahLookupDay) else { return nil }
        return (adhan, iqamahLookupDay)
    }

    // MARK: - Risalah March iqāmah override

    private static func buildMasjidRisalahMarchIqamahTimes(springForwardMarchDay: Int) -> [IqamahTimeRange] {
        let maghrib = "5 mins after adhan"
        let fajrLate = "20 minutes after adhan"
        let d = min(31, max(1, springForwardMarchDay))
        var rows: [IqamahTimeRange] = [
            IqamahTimeRange(dateRange: "1-10", fajr: "05:30", dhuhr: "12:45", asr: "15:30", maghrib: maghrib, isha: "19:45", jummah: nil),
            IqamahTimeRange(dateRange: "11-20", fajr: "05:15", dhuhr: "12:45", asr: "15:45", maghrib: maghrib, isha: "20:00", jummah: nil),
        ]
        if d > 21 {
            rows.append(IqamahTimeRange(dateRange: "21-\(d - 1)", fajr: fajrLate, dhuhr: "12:45", asr: "16:00", maghrib: maghrib, isha: "20:30", jummah: nil))
        }
        rows.append(IqamahTimeRange(dateRange: "\(d)-31", fajr: fajrLate, dhuhr: "13:30", asr: "17:00", maghrib: maghrib, isha: "21:30", jummah: nil))
        return rows
    }

    static func applyMasjidRisalahMarchIqamahIfNeeded(
        slug: String,
        monthNum: Int,
        year: Int,
        data: MonthPrayerData,
        dstDates: [UkDstYear]
    ) -> MonthPrayerData {
        guard normalizeMosqueSlug(slug) == risalahSlug, monthNum == 3 else { return data }
        let spring = getUkMarchSpringForwardDay(year: year, dstDates: dstDates)
        return MonthPrayerData(
            month: data.month,
            prayerTimes: data.prayerTimes,
            iqamahTimes: buildMasjidRisalahMarchIqamahTimes(springForwardMarchDay: spring),
            jummahIqamah: data.jummahIqamah
        )
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

    // MARK: - DST adjustment (iqāmah month remap)

    static func isInDSTAdjustmentPeriod(date: Date, dstDates: [UkDstYear]) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = sheffieldTimeZone
        let y = cal.component(.year, from: date)
        guard let row = dstDates.first(where: { $0.year == y }) else { return false }
        let start = parseISODate(row.startDate)
        let end = parseISODate(row.endDate)
        let checkMonth = cal.component(.month, from: date)
        let checkDay = cal.component(.day, from: date)

        if checkMonth == 10 {
            let endY = cal.component(.year, from: end)
            let endM = cal.component(.month, from: end)
            let endD = cal.component(.day, from: end)
            let isAfter = y > endY || (y == endY && checkMonth > endM) || (y == endY && checkMonth == endM && checkDay >= endD)
            return isAfter && checkMonth == 10
        }
        if checkMonth == 3 {
            let sY = cal.component(.year, from: start)
            let sM = cal.component(.month, from: start)
            let sD = cal.component(.day, from: start)
            let isAfter = y > sY || (y == sY && checkMonth > sM) || (y == sY && checkMonth == sM && checkDay >= sD)
            return isAfter && checkMonth == 3
        }
        return false
    }

    private static func parseISODate(_ s: String) -> Date {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London")!
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? Date()
    }

    static func getDSTAdjustmentIqamahDate(date: Date, dstDates: [UkDstYear]) -> (month: Int, day: Int)? {
        let (year, checkMonth, checkDay) = getDateInSheffield(date)
        let anchor = sheffieldNoonUTC(year: year, month: checkMonth, day: checkDay)
        guard isInDSTAdjustmentPeriod(date: anchor, dstDates: dstDates) else { return nil }
        guard let yearData = dstDates.first(where: { $0.year == year }) else { return nil }
        let dstStartDay = Int(yearData.startDate.suffix(2)) ?? 0
        let dstEndDay = Int(yearData.endDate.suffix(2)) ?? 0
        if checkMonth == 10 {
            let dayOffset = checkDay - dstEndDay
            if dayOffset >= 0 {
                let novemberDate = min(dayOffset + 1, 30)
                return (11, novemberDate)
            }
        }
        if checkMonth == 3 {
            let dayOffset = checkDay - dstStartDay
            if dayOffset >= 0 {
                let aprilDate = min(dayOffset + 1, 30)
                return (4, aprilDate)
            }
        }
        return nil
    }

    // MARK: - Display adhān (DST ±1h in Mar/Oct adjustment)

    private static func isInOctoberTransition(date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        return cal.component(.month, from: date) == 10 && cal.component(.day, from: date) >= 22
    }

    private static func isInMarchTransition(date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        return cal.component(.month, from: date) == 3 && cal.component(.day, from: date) >= 21
    }

    private static func subtractOneHour(_ time: String) -> String {
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return time }
        var h = p[0] - 1
        if h < 0 { h = 23 }
        return String(format: "%02d:%02d", h, p[1])
    }

    private static func addOneHour(_ time: String) -> String {
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return time }
        var h = p[0] + 1
        if h >= 24 { h = 0 }
        return String(format: "%02d:%02d", h, p[1])
    }

    private static func adjustPrayerTimeForDSTSync(_ time: String, date: Date) -> String {
        if isInOctoberTransition(date: date) { return subtractOneHour(time) }
        if isInMarchTransition(date: date) { return addOneHour(time) }
        return time
    }

    static func isInDSTAdjustmentPeriodSync(date: Date) -> Bool {
        isInOctoberTransition(date: date) || isInMarchTransition(date: date)
    }

    static func getDisplayedPrayerTimes(_ prayerTimes: DailyPrayerTimes, date: Date, mosqueSlug: String) -> DailyPrayerTimes {
        if mosqueTimetableAlreadyIncludesDst(slug: mosqueSlug) { return prayerTimes }
        guard isInDSTAdjustmentPeriodSync(date: date) else { return prayerTimes }
        return DailyPrayerTimes(
            date: prayerTimes.date,
            fajr: adjustPrayerTimeForDSTSync(prayerTimes.fajr, date: date),
            sunrise: adjustPrayerTimeForDSTSync(prayerTimes.sunrise, date: date),
            dhuhr: adjustPrayerTimeForDSTSync(prayerTimes.dhuhr, date: date),
            asr: adjustPrayerTimeForDSTSync(prayerTimes.asr, date: date),
            maghrib: adjustPrayerTimeForDSTSync(prayerTimes.maghrib, date: date),
            isha: adjustPrayerTimeForDSTSync(prayerTimes.isha, date: date)
        )
    }

    // MARK: - Resolve day (monthly vs Ramadan)

    static func resolvePrayerTimes(
        slug: String,
        on date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: [UkDstYear]
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
                asr: row.asr,
                maghrib: row.maghrib,
                isha: row.isha
            )
        }

        guard let monthly else { throw PrayerEngineError.missingMonthly }
        let adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug: slug, monthNum: m, year: y, data: monthly, dstDates: ukDst)
        guard let resolved = resolveMonthlyDayDisplay(slug: slug, year: y, month: m, calendarDay: d, monthlyData: adjustedMonthly, dstDates: ukDst) else {
            throw PrayerEngineError.missingDayRow
        }
        let adhan = resolved.adhan
        return DailyPrayerTimes(
            date: dateStr,
            fajr: adhan.fajr,
            sunrise: adhan.shurooq,
            dhuhr: adhan.dhuhr,
            asr: adhan.asr,
            maghrib: adhan.maghrib,
            isha: adhan.isha
        )
    }

    static func resolveIqamahTimes(
        slug: String,
        on date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: [UkDstYear]
    ) throws -> DailyIqamahTimes {
        let (y, m, d) = getDateInSheffield(date)

        if let r = ramadan, isDateWithinRamadanRange(date: date, ramadan: r) {
            let ramadanDay = getRamadanDay(date: date, ramadan: r)
            let iq = try getIqamahTimesForDate(dayOfMonth: ramadanDay, iqamahRanges: r.iqamahTimes)
            let j = iq.jummah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? r.jummahIqamah : iq.jummah
            return DailyIqamahTimes(fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j)
        }

        guard let monthly else { throw PrayerEngineError.missingMonthly }
        let adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug: slug, monthNum: m, year: y, data: monthly, dstDates: ukDst)
        guard let resolved = resolveMonthlyDayDisplay(slug: slug, year: y, month: m, calendarDay: d, monthlyData: adjustedMonthly, dstDates: ukDst) else {
            throw PrayerEngineError.missingDayRow
        }
        let iq = try getIqamahTimesForDate(dayOfMonth: resolved.iqamahLookupDay, iqamahRanges: adjustedMonthly.iqamahTimes)
        let j = iq.jummah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? adjustedMonthly.jummahIqamah : iq.jummah
        return DailyIqamahTimes(fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j)
    }

    /// MWHS-style iqāmah mapping in Mar/Oct DST bands (uses April/November rows).
    static func resolveIqamahTimesWithDstMapping(
        slug: String,
        on date: Date,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: [UkDstYear]
    ) throws -> DailyIqamahTimes {
        if mosqueTimetableAlreadyIncludesDst(slug: slug) {
            return try resolveIqamahTimes(slug: slug, on: date, monthly: monthly, ramadan: ramadan, ukDst: ukDst)
        }
        if let mapped = getDSTAdjustmentIqamahDate(date: date, dstDates: ukDst) {
            let (y, _, _) = getDateInSheffield(date)
            let adj = sheffieldNoonUTC(year: y, month: mapped.month, day: mapped.day)
            return try resolveIqamahTimes(slug: slug, on: adj, monthly: monthly, ramadan: ramadan, ukDst: ukDst)
        }
        return try resolveIqamahTimes(slug: slug, on: date, monthly: monthly, ramadan: ramadan, ukDst: ukDst)
    }

    // MARK: - Hero circle countdown (widget-aligned)

    /// Label semantics for the home hero countdown (matches `MasjidlyWidgetResolver` phase rules).
    static func heroCountdownPresentation(
        prayerTimes: DailyPrayerTimes,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        now: Date = Date()
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

        func wallClockNextDay(_ time: String) -> Date? {
            let p = time.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2, let morrow = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            return cal.date(bySettingHour: p[0], minute: p[1], second: 0, of: morrow)
        }

        let jummahRaw = iqamahTimes.jummah
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
                iqamahs: [getIqamahTime(prayer: "asr", adhanTime: prayerTimes.asr, iqamahTimes: iqamahTimes)],
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

        let isNextFajrTomorrow = !foundTodayEvent

        let next: ResolvedHeroPrayer = {
            if isNextFajrTomorrow {
                let fajr = prayersList[0]
                return ResolvedHeroPrayer(
                    id: "fajr",
                    name: "Fajr",
                    adhan: fajr.adhan,
                    iqamahs: fajr.iqamahs,
                    adhanDate: wallClockNextDay(fajr.adhan)
                )
            }
            return prayersList[nextPrayerIndex]
        }()

        guard let targetDate = isNextFajrTomorrow ? next.adhanDate : nextEventDate else {
            return nil
        }

        let progressStartDate: Date = {
            if nextEventIsIqamah {
                return next.adhanDate ?? dayStart
            }
            if nextPrayerIndex > 0, let prev = prayersList[nextPrayerIndex - 1].adhanDate {
                return prev
            }
            if isNextFajrTomorrow {
                return prayersList.last?.adhanDate ?? dayStart
            }
            return dayStart
        }()

        let labelKind: HeroCountdownLabelKind = {
            if nextEventIsIqamah { return .iqamahIn }
            if isNextFajrTomorrow { return .nextPrayer }
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
        now: Date = Date()
    ) -> NextPrayerCountdownResult {
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

        let jummahRaw = iqamahTimes.jummah
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
            ("Asr", prayerTimes.asr, getIqamahTime(prayer: "asr", adhanTime: prayerTimes.asr, iqamahTimes: iqamahTimes)),
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

        if let fajrT = wallClockToday(prayers[0].adhan),
           let tomorrow = cal.date(byAdding: .day, value: 1, to: dayStart),
           let nextFajr = cal.date(bySettingHour: cal.component(.hour, from: fajrT), minute: cal.component(.minute, from: fajrT), second: 0, of: tomorrow) {
            let diff = Int(nextFajr.timeIntervalSince(now))
            return NextPrayerCountdownResult(nextName: "Fajr", nextTime: prayers[0].adhan, totalSeconds: max(0, diff), isIqamah: false, isJummah: false)
        }

        return NextPrayerCountdownResult(nextName: "Fajr", nextTime: prayers[0].adhan, totalSeconds: 0, isIqamah: false, isJummah: false)
    }

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
            f.timeStyle = .short
            f.dateStyle = .none
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
