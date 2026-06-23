package com.mikhailspeaks.masjidly.domain

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.floor

/**
 * Prayer-time resolution ported from Sheffield-Masjids `src/lib/prayer-times.ts` (subset for native Android).
 * Source of truth: iOS [PrayerTimesEngine.swift].
 */
object PrayerTimesEngine {
    val sheffieldTimeZone: ZoneId = ZoneId.of("Europe/London")

    private const val RISALAH_SLUG = "masjid-risalah"
    private val dstMosqueSlugs: Set<String> = setOf("masjid-al-huda-sheffield")

    private val whitespaceBetweenTimesRegex =
        Regex("""(\d{1,2}:\d{2})\s+(?=\d{1,2}:\d{2})""")
    private val adhanPlusMinutesRegex =
        Regex("""^adhan\s*\+\s*(\d+)\s*(?:mins?|minutes?)?$""", RegexOption.IGNORE_CASE)
    private val minutesAfterAdhanRegex =
        Regex("""^(\d+)\s*(?:mins?|minutes?)\s*after\s*adhan$""", RegexOption.IGNORE_CASE)
    private val parseableTimeRegex = Regex("""^(\d{1,2}):(\d{2})$""")
    private val nonParseablePhraseRegex =
        Regex("""after maghrib|entry time|straight after""", RegexOption.IGNORE_CASE)

    // MARK: - Calendar (Sheffield)

    data class SheffieldYmd(val year: Int, val month: Int, val day: Int)

    fun getDateInSheffield(date: Instant): SheffieldYmd {
        val zdt = date.atZone(sheffieldTimeZone)
        return SheffieldYmd(zdt.year, zdt.monthValue, zdt.dayOfMonth)
    }

    fun sheffieldNoonUTC(year: Int, month: Int, day: Int): Instant =
        LocalDate.of(year, month, day)
            .atTime(12, 0)
            .toInstant(ZoneOffset.UTC)

    fun isoDateString(year: Int, month: Int, day: Int): String =
        String.format(Locale.ROOT, "%04d-%02d-%02d", year, month, day)

    fun splitIqamahTimes(raw: String?): List<String> {
        val trimmed = (raw ?: "").trim()
        if (trimmed.isEmpty()) return emptyList()
        val normalized = whitespaceBetweenTimesRegex.replace(trimmed, "$1,")
        return normalized
            .split(Regex("""[,/&|\n]"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    fun splitJummahIqamahTimes(raw: String?): List<String> = splitIqamahTimes(raw)

    fun getAsrIqamahSlots(asrIqamah: String, adhanTime: String): List<String> {
        if (asrIqamah.trim().lowercase() == "entry time") return listOf(adhanTime)
        val slots = splitIqamahTimes(asrIqamah).map { resolveRelativeIqamah(it, adhanTime) }
        return if (slots.isEmpty()) {
            listOf(resolveRelativeIqamah(asrIqamah, adhanTime))
        } else {
            slots
        }
    }

    fun selectAsrIqamahTime(
        asrIqamah: String,
        adhanTime: String,
        preference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ): String {
        val slots = getAsrIqamahSlots(asrIqamah, adhanTime)
        return when (preference) {
            AsrIqamahPreference.FIRST -> slots.firstOrNull().orEmpty()
            AsrIqamahPreference.SECOND -> slots.drop(1).firstOrNull() ?: slots.firstOrNull().orEmpty()
        }
    }

    fun selectAsrAdhanTime(
        prayerTime: PrayerTime,
        preference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ): String {
        if (preference == AsrIqamahPreference.SECOND) {
            val asrMithl2 = prayerTime.asrMithl2
            if (!asrMithl2.isNullOrEmpty()) return asrMithl2
        }
        return prayerTime.asr
    }

    fun selectAsrAdhanTime(
        prayerTime: RamadanPrayerDay,
        preference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ): String {
        if (preference == AsrIqamahPreference.SECOND) {
            val asrMithl2 = prayerTime.asrMithl2
            if (!asrMithl2.isNullOrEmpty()) return asrMithl2
        }
        return prayerTime.asr
    }

    fun normalizeMosqueSlug(slug: String): String = slug.trim().lowercase()

    fun isMasjidRisalah(slug: String): Boolean =
        normalizeMosqueSlug(slug) == RISALAH_SLUG

    private fun isMuslimWelfareHouse(slug: String): Boolean =
        normalizeMosqueSlug(slug) == normalizeMosqueSlug(MosqueDefaults.DEFAULT_MOSQUE_SLUG)

    fun mosqueTimetableAlreadyIncludesDst(slug: String): Boolean =
        dstMosqueSlugs.contains(normalizeMosqueSlug(slug))

    // MARK: - Sparse rows

    fun findDayData(prayerTimes: List<PrayerTime>, dayOfMonth: Int): PrayerTime? {
        var closestPrevious: PrayerTime? = null
        var earliest: PrayerTime? = null

        for (day in prayerTimes) {
            if (earliest == null || day.date < earliest!!.date) earliest = day
            if (day.date == dayOfMonth) return day
            if (day.date <= dayOfMonth) {
                if (closestPrevious == null || day.date > closestPrevious!!.date) {
                    closestPrevious = day
                }
            }
        }
        return closestPrevious ?: earliest
    }

    fun findRamadanDayData(prayerTimes: List<RamadanPrayerDay>, ramadanDay: Int): RamadanPrayerDay? {
        var closestPrevious: RamadanPrayerDay? = null
        var earliest: RamadanPrayerDay? = null

        for (day in prayerTimes) {
            if (earliest == null || day.ramadanDay < earliest!!.ramadanDay) earliest = day
            if (day.ramadanDay == ramadanDay) return day
            if (day.ramadanDay <= ramadanDay) {
                if (closestPrevious == null || day.ramadanDay > closestPrevious!!.ramadanDay) {
                    closestPrevious = day
                }
            }
        }
        return closestPrevious ?: earliest
    }

    // MARK: - Iqāmah ranges

    fun getIqamahTimesForDate(dayOfMonth: Int, iqamahRanges: List<IqamahTimeRange>): DailyIqamahTimes {
        for (range in iqamahRanges) {
            val parts = range.dateRange.split("-").mapNotNull { it.trim().toIntOrNull() }
            val start = parts.firstOrNull() ?: continue
            val end = parts.getOrNull(1)
            if (end == null) {
                if (dayOfMonth == start) return dailyFromRange(range)
            } else if (dayOfMonth in start..end) {
                return dailyFromRange(range)
            }
        }
        throw PrayerEngineError.NoIqamahRange(dayOfMonth)
    }

    private fun dailyFromRange(range: IqamahTimeRange): DailyIqamahTimes =
        DailyIqamahTimes(
            fajr = range.fajr,
            dhuhr = range.dhuhr,
            asr = range.asr,
            maghrib = range.maghrib ?: "sunset",
            isha = range.isha,
            jummah = range.jummah?.trim().orEmpty(),
        )

    // MARK: - Isha / summer / Risalah

    fun isSummerIshaPeriod(date: Instant): Boolean {
        val zdt = date.atZone(sheffieldTimeZone)
        val y = zdt.year
        val may15 = LocalDate.of(y, 5, 15).atTime(12, 0).atZone(sheffieldTimeZone)
        val aug15 = LocalDate.of(y, 8, 15).atTime(12, 0).atZone(sheffieldTimeZone)
        return !zdt.isBefore(may15) && !zdt.isAfter(aug15)
    }

    fun isRisalahIshaIqamahMatchesAdhanPeriod(date: Instant): Boolean {
        val zdt = date.atZone(sheffieldTimeZone)
        val y = zdt.year
        val may1 = LocalDate.of(y, 5, 1).atTime(12, 0).atZone(sheffieldTimeZone)
        val july31 = LocalDate.of(y, 7, 31).atTime(12, 0).atZone(sheffieldTimeZone)
        return !zdt.isBefore(may1) && !zdt.isAfter(july31)
    }

    fun resolveIshaIqamahForDisplay(
        slug: String,
        date: Instant,
        ishaAdhan: String,
        iqamahTimes: DailyIqamahTimes,
        maghribAdhan: String,
    ): String {
        if (isMasjidRisalah(slug) && isRisalahIshaIqamahMatchesAdhanPeriod(date)) {
            return ishaAdhan
        }
        if (isMuslimWelfareHouse(slug) && isSummerIshaPeriod(date)) {
            return "After Maghrib"
        }
        return getIqamahTime("isha", ishaAdhan, iqamahTimes, maghribAdhan)
    }

    /**
     * Centralized iqamah display resolution.
     * For Isha, applies special mosque/season rules via [resolveIshaIqamahForDisplay];
     * for all other prayers, delegates to [getIqamahTime].
     */
    fun getDisplayIqamah(
        prayer: String,
        adhanTime: String,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        date: Instant,
        maghribAdhan: String,
    ): String {
        val p = prayer.lowercase()
        return if (p == "isha") {
            resolveIshaIqamahForDisplay(
                slug = mosqueSlug,
                date = date,
                ishaAdhan = adhanTime,
                iqamahTimes = iqamahTimes,
                maghribAdhan = maghribAdhan,
            )
        } else {
            getIqamahTime(p, adhanTime, iqamahTimes, maghribAdhan)
        }
    }

    fun getIqamahTime(
        prayer: String,
        adhanTime: String,
        iqamahTimes: DailyIqamahTimes,
        maghribAdhan: String? = null,
    ): String {
        return when (prayer.lowercase()) {
            "fajr" -> {
                val raw = if (iqamahTimes.fajr == "Various") adhanTime else iqamahTimes.fajr
                resolveRelativeIqamah(raw, adhanTime)
            }
            "dhuhr" -> resolveRelativeIqamah(iqamahTimes.dhuhr, adhanTime)
            "asr" -> {
                if (iqamahTimes.asr.trim().lowercase() == "entry time") return adhanTime
                selectAsrIqamahTime(iqamahTimes.asr, adhanTime)
            }
            "maghrib" -> {
                val raw = if (iqamahTimes.maghrib == "sunset") adhanTime else iqamahTimes.maghrib
                resolveRelativeIqamah(raw, adhanTime)
            }
            "isha" -> when {
                iqamahTimes.isha == "Straight after Maghrib" -> maghribAdhan ?: adhanTime
                iqamahTimes.isha == "Entry Time" -> adhanTime
                else -> resolveRelativeIqamah(iqamahTimes.isha, adhanTime)
            }
            "jummah" -> iqamahTimes.jummah
            else -> "-"
        }
    }

    private fun addMinutesToTime(time: String, minutesToAdd: Int): String? {
        val parts = time.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (parts.size != 2) return null
        val total = (((parts[0] * 60 + parts[1] + minutesToAdd) % 1440) + 1440) % 1440
        return String.format(Locale.ROOT, "%02d:%02d", total / 60, total % 60)
    }

    fun resolveRelativeIqamah(iqamahValue: String, adhanTime: String): String {
        val value = iqamahValue.trim()
        adhanPlusMinutesRegex.matchEntire(value)?.groupValues?.getOrNull(1)?.toIntOrNull()?.let { mins ->
            return addMinutesToTime(adhanTime, mins) ?: iqamahValue
        }
        minutesAfterAdhanRegex.matchEntire(value)?.groupValues?.getOrNull(1)?.toIntOrNull()?.let { mins ->
            return addMinutesToTime(adhanTime, mins) ?: iqamahValue
        }
        return iqamahValue
    }

    // MARK: - Embedded DST table remap (Masjid Al-Huda)

    private fun dhuhrToMinutes(t: PrayerTime): Int? {
        val parts = t.dhuhr.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (parts.size != 2) return null
        return parts[0] * 60 + parts[1]
    }

    fun detectMarchSummerStartDayInTable(prayerTimes: List<PrayerTime>): Int? {
        val sorted = prayerTimes.sortedBy { it.date }
        var bestDay: Int? = null
        var bestJump = 0
        for (i in 1 until sorted.size) {
            val a = dhuhrToMinutes(sorted[i - 1]) ?: continue
            val b = dhuhrToMinutes(sorted[i]) ?: continue
            val jump = b - a
            if (jump > bestJump) {
                bestJump = jump
                bestDay = sorted[i].date
            }
        }
        return if (bestJump >= 45) bestDay else null
    }

    fun detectOctoberWinterStartDayInTable(prayerTimes: List<PrayerTime>): Int? {
        val sorted = prayerTimes.sortedBy { it.date }
        var bestDay: Int? = null
        var bestFall = 0
        for (i in 1 until sorted.size) {
            val a = dhuhrToMinutes(sorted[i - 1]) ?: continue
            val b = dhuhrToMinutes(sorted[i]) ?: continue
            val fall = a - b
            if (fall > bestFall) {
                bestFall = fall
                bestDay = sorted[i].date
            }
        }
        return if (bestFall >= 45) bestDay else null
    }

    fun resolveTimetableDayForUkEmbeddedDst(
        calendarDay: Int,
        transitionDayInTable: Int,
        ukTransitionDay: Int,
        maxTableDay: Int,
    ): Int {
        val t = transitionDayInTable
        val u = ukTransitionDay
        if (t == u) return calendarDay
        val low = minOf(t, u)
        val high = maxOf(t, u) - 1
        if (calendarDay < low || calendarDay > high) return calendarDay
        return minOf(maxTableDay, maxOf(1, calendarDay + (t - u)))
    }

    private fun maxPrayerTableDay(prayerTimes: List<PrayerTime>, year: Int, month: Int): Int {
        val m = maxOf(0, prayerTimes.maxOfOrNull { it.date } ?: 0)
        if (m > 0) return m
        return YearMonth.of(year, month).lengthOfMonth()
    }

    private fun getLastSundayOfMonth(year: Int, month: Int): Int {
        val lastDay = YearMonth.of(year, month).atEndOfMonth()
        val wd = lastDay.dayOfWeek.value % 7 + 1 // Sunday=1 … Saturday=7 (Swift weekday)
        val last = lastDay.dayOfMonth
        val sunday = 1
        val offset = (wd - sunday + 7) % 7
        return last - offset
    }

    fun getUkMarchSpringForwardDay(year: Int, dstDates: List<UkDstYear>): Int {
        val row = dstDates.firstOrNull { it.year == year }
        if (row != null) {
            val seg = row.startDate.split("-")
            if (seg.size == 3) {
                val mo = seg[1].toIntOrNull()
                val d = seg[2].toIntOrNull()
                if (mo == 3 && d != null && d in 1..31) return d
            }
        }
        return getLastSundayOfMonth(year, 3)
    }

    fun resolveEmbeddedDstTimetableDayOfMonth(
        slug: String,
        month: Int,
        year: Int,
        calendarDay: Int,
        prayerTimes: List<PrayerTime>,
        dstDates: List<UkDstYear>,
    ): Int {
        if (!mosqueTimetableAlreadyIncludesDst(slug) || (month != 3 && month != 10)) {
            return calendarDay
        }
        val maxDay = maxPrayerTableDay(prayerTimes, year, month)
        if (month == 3) {
            val t = detectMarchSummerStartDayInTable(prayerTimes) ?: return calendarDay
            val u = getUkMarchSpringForwardDay(year, dstDates)
            return resolveTimetableDayForUkEmbeddedDst(calendarDay, t, u, maxDay)
        }
        val t = detectOctoberWinterStartDayInTable(prayerTimes) ?: return calendarDay
        var u = getLastSundayOfMonth(year, 10)
        dstDates.firstOrNull { it.year == year }?.let { row ->
            val seg = row.endDate.split("-")
            if (seg.size == 3) {
                val mo = seg[1].toIntOrNull()
                val d = seg[2].toIntOrNull()
                if (mo == 10 && d != null && d in 1..31) u = d
            }
        }
        return resolveTimetableDayForUkEmbeddedDst(calendarDay, t, u, maxDay)
    }

    data class MonthlyDayDisplay(val adhan: PrayerTime, val iqamahLookupDay: Int)

    fun resolveMonthlyDayDisplay(
        slug: String,
        year: Int,
        month: Int,
        calendarDay: Int,
        monthlyData: MonthPrayerData,
        dstDates: List<UkDstYear>,
    ): MonthlyDayDisplay? {
        val iqamahLookupDay = resolveEmbeddedDstTimetableDayOfMonth(
            slug = slug,
            month = month,
            year = year,
            calendarDay = calendarDay,
            prayerTimes = monthlyData.prayerTimes,
            dstDates = dstDates,
        )
        val adhan = findDayData(monthlyData.prayerTimes, iqamahLookupDay) ?: return null
        return MonthlyDayDisplay(adhan, iqamahLookupDay)
    }

    // MARK: - Risalah March iqāmah override

    private fun buildMasjidRisalahMarchIqamahTimes(springForwardMarchDay: Int): List<IqamahTimeRange> {
        val maghrib = "5 mins after adhan"
        val fajrLate = "20 minutes after adhan"
        val d = minOf(31, maxOf(1, springForwardMarchDay))
        val rows = mutableListOf(
            IqamahTimeRange("1-10", "05:30", "12:45", "15:30", maghrib, "19:45", null),
            IqamahTimeRange("11-20", "05:15", "12:45", "15:45", maghrib, "20:00", null),
        )
        if (d > 21) {
            rows.add(
                IqamahTimeRange("21-${d - 1}", fajrLate, "12:45", "16:00", maghrib, "20:30", null),
            )
        }
        rows.add(IqamahTimeRange("$d-31", fajrLate, "13:30", "17:00", maghrib, "21:30", null))
        return rows
    }

    fun applyMasjidRisalahMarchIqamahIfNeeded(
        slug: String,
        monthNum: Int,
        year: Int,
        data: MonthPrayerData,
        dstDates: List<UkDstYear>,
    ): MonthPrayerData {
        if (normalizeMosqueSlug(slug) != RISALAH_SLUG || monthNum != 3) return data
        val spring = getUkMarchSpringForwardDay(year, dstDates)
        return data.copy(
            iqamahTimes = buildMasjidRisalahMarchIqamahTimes(spring),
        )
    }

    // MARK: - Ramadan

    fun isDateWithinRamadanRange(date: Instant, ramadan: RamadanPrayerData): Boolean {
        val (y, m, d) = getDateInSheffield(date)
        val dateStr = isoDateString(y, m, d)
        return dateStr >= ramadan.gregorianStart && dateStr <= ramadan.gregorianEnd
    }

    fun getRamadanDay(date: Instant, ramadan: RamadanPrayerData): Int {
        val (y, m, d) = getDateInSheffield(date)
        val start = sheffieldNoonUTCFromISO(ramadan.gregorianStart)
        val dateAtNoon = sheffieldNoonUTC(y, m, d)
        val diffMs = dateAtNoon.epochSecond - start.epochSecond
        val diffDays = floor(diffMs.toDouble() / 86400.0).toInt()
        return minOf(30, maxOf(1, diffDays + 1))
    }

    private fun sheffieldNoonUTCFromISO(yyyyMMdd: String): Instant {
        val parts = yyyyMMdd.split("-").mapNotNull { it.trim().toIntOrNull() }
        if (parts.size != 3) return Instant.EPOCH
        return sheffieldNoonUTC(parts[0], parts[1], parts[2])
    }

    // MARK: - DST adjustment (iqāmah month remap)

    fun isInDSTAdjustmentPeriod(date: Instant, dstDates: List<UkDstYear>): Boolean {
        val zdt = date.atZone(sheffieldTimeZone)
        val y = zdt.year
        val row = dstDates.firstOrNull { it.year == y } ?: return false
        val start = parseISODate(row.startDate)
        val end = parseISODate(row.endDate)
        val checkMonth = zdt.monthValue
        val checkDay = zdt.dayOfMonth

        if (checkMonth == 10) {
            val endZdt = end.atZone(sheffieldTimeZone)
            val endY = endZdt.year
            val endM = endZdt.monthValue
            val endD = endZdt.dayOfMonth
            val isAfter = y > endY ||
                (y == endY && checkMonth > endM) ||
                (y == endY && checkMonth == endM && checkDay >= endD)
            return isAfter && checkMonth == 10
        }
        if (checkMonth == 3) {
            val startZdt = start.atZone(sheffieldTimeZone)
            val sY = startZdt.year
            val sM = startZdt.monthValue
            val sD = startZdt.dayOfMonth
            val isAfter = y > sY ||
                (y == sY && checkMonth > sM) ||
                (y == sY && checkMonth == sM && checkDay >= sD)
            return isAfter && checkMonth == 3
        }
        return false
    }

    private fun parseISODate(s: String): Instant {
        val p = s.split("-").mapNotNull { it.trim().toIntOrNull() }
        if (p.size != 3) return Instant.EPOCH
        return LocalDate.of(p[0], p[1], p[2])
            .atStartOfDay(sheffieldTimeZone)
            .toInstant()
    }

    data class DstAdjustmentIqamahDate(val month: Int, val day: Int)

    fun getDSTAdjustmentIqamahDate(date: Instant, dstDates: List<UkDstYear>): DstAdjustmentIqamahDate? {
        val (year, checkMonth, checkDay) = getDateInSheffield(date)
        val anchor = sheffieldNoonUTC(year, checkMonth, checkDay)
        if (!isInDSTAdjustmentPeriod(anchor, dstDates)) return null
        val yearData = dstDates.firstOrNull { it.year == year } ?: return null
        val dstStartDay = yearData.startDate.takeLast(2).toIntOrNull() ?: 0
        val dstEndDay = yearData.endDate.takeLast(2).toIntOrNull() ?: 0
        if (checkMonth == 10) {
            val dayOffset = checkDay - dstEndDay
            if (dayOffset >= 0) {
                val novemberDate = minOf(dayOffset + 1, 30)
                return DstAdjustmentIqamahDate(11, novemberDate)
            }
        }
        if (checkMonth == 3) {
            val dayOffset = checkDay - dstStartDay
            if (dayOffset >= 0) {
                val aprilDate = minOf(dayOffset + 1, 30)
                return DstAdjustmentIqamahDate(4, aprilDate)
            }
        }
        return null
    }

    // MARK: - Display adhān (DST ±1h in Mar/Oct adjustment)

    /** Matches Swift: Gregorian calendar without explicit timezone (system default). */
    private fun isInOctoberTransition(date: Instant): Boolean {
        val zdt = date.atZone(ZoneId.systemDefault())
        return zdt.monthValue == 10 && zdt.dayOfMonth >= 22
    }

    /** Matches Swift: Gregorian calendar without explicit timezone (system default). */
    private fun isInMarchTransition(date: Instant): Boolean {
        val zdt = date.atZone(ZoneId.systemDefault())
        return zdt.monthValue == 3 && zdt.dayOfMonth >= 21
    }

    private fun subtractOneHour(time: String): String {
        val p = time.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (p.size != 2) return time
        var h = p[0] - 1
        if (h < 0) h = 23
        return String.format(Locale.ROOT, "%02d:%02d", h, p[1])
    }

    private fun addOneHour(time: String): String {
        val p = time.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (p.size != 2) return time
        var h = p[0] + 1
        if (h >= 24) h = 0
        return String.format(Locale.ROOT, "%02d:%02d", h, p[1])
    }

    private fun adjustPrayerTimeForDSTSync(time: String, date: Instant): String {
        if (isInOctoberTransition(date)) return subtractOneHour(time)
        if (isInMarchTransition(date)) return addOneHour(time)
        return time
    }

    fun isInDSTAdjustmentPeriodSync(date: Instant): Boolean =
        isInOctoberTransition(date) || isInMarchTransition(date)

    fun getDisplayedPrayerTimes(
        prayerTimes: DailyPrayerTimes,
        date: Instant,
        mosqueSlug: String,
    ): DailyPrayerTimes {
        if (mosqueTimetableAlreadyIncludesDst(mosqueSlug)) return prayerTimes
        if (!isInDSTAdjustmentPeriodSync(date)) return prayerTimes
        return prayerTimes.copy(
            fajr = adjustPrayerTimeForDSTSync(prayerTimes.fajr, date),
            sunrise = adjustPrayerTimeForDSTSync(prayerTimes.sunrise, date),
            dhuhr = adjustPrayerTimeForDSTSync(prayerTimes.dhuhr, date),
            asr = adjustPrayerTimeForDSTSync(prayerTimes.asr, date),
            maghrib = adjustPrayerTimeForDSTSync(prayerTimes.maghrib, date),
            isha = adjustPrayerTimeForDSTSync(prayerTimes.isha, date),
        )
    }

    // MARK: - Resolve day (monthly vs Ramadan)

    fun resolvePrayerTimes(
        slug: String,
        on: Instant,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: List<UkDstYear>,
        asrTimingPreference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ): DailyPrayerTimes {
        val (y, m, d) = getDateInSheffield(on)
        val dateStr = isoDateString(y, m, d)

        if (ramadan != null && isDateWithinRamadanRange(on, ramadan)) {
            val ramadanDay = getRamadanDay(on, ramadan)
            val row = findRamadanDayData(ramadan.prayerTimes, ramadanDay)
                ?: throw PrayerEngineError.MissingRamadanRow
            return DailyPrayerTimes(
                date = dateStr,
                fajr = row.fajr,
                sunrise = row.shurooq,
                dhuhr = row.dhuhr,
                asr = selectAsrAdhanTime(row, asrTimingPreference),
                maghrib = row.maghrib,
                isha = row.isha,
            )
        }

        val monthlyData = monthly ?: throw PrayerEngineError.MissingMonthly
        val adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug, m, y, monthlyData, ukDst)
        val resolved = resolveMonthlyDayDisplay(slug, y, m, d, adjustedMonthly, ukDst)
            ?: throw PrayerEngineError.MissingDayRow
        val adhan = resolved.adhan
        return DailyPrayerTimes(
            date = dateStr,
            fajr = adhan.fajr,
            sunrise = adhan.shurooq,
            dhuhr = adhan.dhuhr,
            asr = selectAsrAdhanTime(adhan, asrTimingPreference),
            maghrib = adhan.maghrib,
            isha = adhan.isha,
        )
    }

    fun resolveIqamahTimes(
        slug: String,
        on: Instant,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: List<UkDstYear>,
    ): DailyIqamahTimes {
        val (y, m, d) = getDateInSheffield(on)

        if (ramadan != null && isDateWithinRamadanRange(on, ramadan)) {
            val ramadanDay = getRamadanDay(on, ramadan)
            val iq = getIqamahTimesForDate(ramadanDay, ramadan.iqamahTimes)
            val j = if (iq.jummah.trim().isEmpty()) ramadan.jummahIqamah else iq.jummah
            return iq.copy(jummah = j)
        }

        val monthlyData = monthly ?: throw PrayerEngineError.MissingMonthly
        val adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug, m, y, monthlyData, ukDst)
        val resolved = resolveMonthlyDayDisplay(slug, y, m, d, adjustedMonthly, ukDst)
            ?: throw PrayerEngineError.MissingDayRow
        val iq = getIqamahTimesForDate(resolved.iqamahLookupDay, adjustedMonthly.iqamahTimes)
        val j = if (iq.jummah.trim().isEmpty()) adjustedMonthly.jummahIqamah else iq.jummah
        return iq.copy(jummah = j)
    }

    /** MWHS-style iqāmah mapping in Mar/Oct DST bands (uses April/November rows). */
    fun resolveIqamahTimesWithDstMapping(
        slug: String,
        on: Instant,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        ukDst: List<UkDstYear>,
    ): DailyIqamahTimes {
        if (mosqueTimetableAlreadyIncludesDst(slug)) {
            return resolveIqamahTimes(slug, on, monthly, ramadan, ukDst)
        }
        val mapped = getDSTAdjustmentIqamahDate(on, ukDst)
        if (mapped != null) {
            val (y, _, _) = getDateInSheffield(on)
            val adj = sheffieldNoonUTC(y, mapped.month, mapped.day)
            return resolveIqamahTimes(slug, adj, monthly, ramadan, ukDst)
        }
        return resolveIqamahTimes(slug, on, monthly, ramadan, ukDst)
    }

    // MARK: - Hero circle countdown (widget-aligned)

    private data class ResolvedHeroPrayer(
        val id: String,
        val name: String,
        val adhan: String,
        val iqamahs: List<String>,
        val adhanDate: Instant?,
    )

    /** Label semantics for the home hero countdown (matches `MasjidlyWidgetResolver` phase rules). */
    fun heroCountdownPresentation(
        prayerTimes: DailyPrayerTimes,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        now: Instant = Instant.now(),
        asrIqamahPreference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ): HeroCountdownPresentation? {
        val dayStart = now.atZone(sheffieldTimeZone).truncatedTo(ChronoUnit.DAYS)
        val isFriday = now.atZone(sheffieldTimeZone).dayOfWeek == DayOfWeek.FRIDAY
        val checkDate = dayStart.toInstant()

        fun wallClockToday(time: String): Instant? {
            val p = time.split(":").mapNotNull { it.trim().toIntOrNull() }
            if (p.size != 2) return null
            return dayStart.withHour(p[0]).withMinute(p[1]).withSecond(0).withNano(0).toInstant()
        }

        val jummahRaw = splitJummahIqamahTimes(iqamahTimes.jummah)
        val jummahTimes = if (jummahRaw.isEmpty()) listOf(iqamahTimes.dhuhr) else jummahRaw
        val jummahAdhan = nextHeroDisplayIqamahRaw(
            prayerId = "dhuhr",
            isFriday = isFriday,
            rawIqamahs = jummahTimes,
            adhan = prayerTimes.dhuhr,
            now = now,
            wallClock = ::wallClockToday,
        )

        val prayersList = listOf(
            ResolvedHeroPrayer(
                id = "fajr",
                name = "Fajr",
                adhan = prayerTimes.fajr,
                iqamahs = listOf(getIqamahTime("fajr", prayerTimes.fajr, iqamahTimes)),
                adhanDate = wallClockToday(prayerTimes.fajr),
            ),
            ResolvedHeroPrayer(
                id = "dhuhr",
                name = if (isFriday) "Jummah" else "Dhuhr",
                adhan = if (isFriday) jummahAdhan else prayerTimes.dhuhr,
                iqamahs = if (isFriday) emptyList() else listOf(
                    getIqamahTime("dhuhr", prayerTimes.dhuhr, iqamahTimes),
                ),
                adhanDate = wallClockToday(if (isFriday) jummahAdhan else prayerTimes.dhuhr),
            ),
            ResolvedHeroPrayer(
                id = "asr",
                name = "Asr",
                adhan = prayerTimes.asr,
                iqamahs = listOf(
                    selectAsrIqamahTime(iqamahTimes.asr, prayerTimes.asr, asrIqamahPreference),
                ),
                adhanDate = wallClockToday(prayerTimes.asr),
            ),
            ResolvedHeroPrayer(
                id = "maghrib",
                name = "Maghrib",
                adhan = prayerTimes.maghrib,
                iqamahs = listOf(getIqamahTime("maghrib", prayerTimes.maghrib, iqamahTimes)),
                adhanDate = wallClockToday(prayerTimes.maghrib),
            ),
            ResolvedHeroPrayer(
                id = "isha",
                name = "Isha",
                adhan = prayerTimes.isha,
                iqamahs = listOf(
                    resolveIshaIqamahForDisplay(
                        slug = mosqueSlug,
                        date = checkDate,
                        ishaAdhan = prayerTimes.isha,
                        iqamahTimes = iqamahTimes,
                        maghribAdhan = prayerTimes.maghrib,
                    ),
                ),
                adhanDate = wallClockToday(prayerTimes.isha),
            ),
        )

        var nextPrayerIndex = 0
        var nextEventDate: Instant? = null
        var nextEventIsIqamah = false
        var foundTodayEvent = false

        for ((i, p) in prayersList.withIndex()) {
            val adhanDate = p.adhanDate
            if (adhanDate != null && adhanDate.isAfter(now)) {
                nextPrayerIndex = i
                nextEventDate = adhanDate
                nextEventIsIqamah = false
                foundTodayEvent = true
                break
            }

            val candidateIqamah = nextHeroDisplayIqamahRaw(
                prayerId = p.id,
                isFriday = isFriday,
                rawIqamahs = p.iqamahs,
                adhan = p.adhan,
                now = now,
                wallClock = ::wallClockToday,
            )
            if (isParseableTime(candidateIqamah) && candidateIqamah != p.adhan) {
                val iqamahDate = wallClockToday(candidateIqamah)
                if (iqamahDate != null && iqamahDate.isAfter(now)) {
                    nextPrayerIndex = i
                    nextEventDate = iqamahDate
                    nextEventIsIqamah = true
                    foundTodayEvent = true
                    break
                }
            }
        }

        if (!foundTodayEvent || nextEventDate == null) return null

        val next = prayersList[nextPrayerIndex]
        val progressStartDate: Instant = when {
            nextEventIsIqamah -> next.adhanDate ?: dayStart.toInstant()
            nextPrayerIndex > 0 -> prayersList[nextPrayerIndex - 1].adhanDate ?: dayStart.toInstant()
            else -> dayStart.toInstant()
        }

        val labelKind = when {
            nextEventIsIqamah -> HeroCountdownLabelKind.IQAMAH_IN
            nextPrayerIndex == 0 -> HeroCountdownLabelKind.ADHAN_IN
            else -> HeroCountdownLabelKind.NEXT_PRAYER
        }

        return HeroCountdownPresentation(
            labelKind = labelKind,
            targetDate = nextEventDate,
            progressStartDate = progressStartDate,
        )
    }

    /** Jummah multi-slot: next iqamah strictly after [now] once adhan has passed; otherwise first slot. */
    private fun nextHeroDisplayIqamahRaw(
        prayerId: String,
        isFriday: Boolean,
        rawIqamahs: List<String>,
        adhan: String,
        now: Instant,
        wallClock: (String) -> Instant?,
    ): String {
        val supportsMultipleSlots = (prayerId == "dhuhr" && isFriday) || prayerId == "asr"
        if (!supportsMultipleSlots || rawIqamahs.size <= 1) {
            return rawIqamahs.firstOrNull().orEmpty()
        }
        val adhanDate = wallClock(adhan) ?: return rawIqamahs.firstOrNull().orEmpty()
        if (now.isBefore(adhanDate)) {
            return rawIqamahs.firstOrNull().orEmpty()
        }
        for (raw in rawIqamahs) {
            val d = wallClock(raw)
            if (d != null && d.isAfter(now)) return raw
        }
        return rawIqamahs.lastOrNull().orEmpty()
    }

    fun heroRemainingSeconds(p: HeroCountdownPresentation, now: Instant): Int =
        p.remainingSeconds(now)

    fun heroProgress01(p: HeroCountdownPresentation, now: Instant): Double =
        p.progress01(now)

    /** Hero tap countdown: leading `-`, then `H:MM:SS` if ≥ 1 hour, else `M:SS` (minutes unpadded, seconds zero-padded). */
    fun formatHeroCountdownClock(totalSeconds: Int): String {
        val s = maxOf(0, totalSeconds)
        if (s >= 3600) {
            val h = s / 3600
            val rem = s % 3600
            val m = rem / 60
            val sec = rem % 60
            return "-$h:${String.format(Locale.ROOT, "%02d", m)}:${String.format(Locale.ROOT, "%02d", sec)}"
        }
        val m = s / 60
        val sec = s % 60
        return "-$m:${String.format(Locale.ROOT, "%02d", sec)}"
    }

    // MARK: - Next prayer / countdown

    fun getNextPrayerAndCountdown(
        prayerTimes: DailyPrayerTimes,
        iqamahTimes: DailyIqamahTimes,
        mosqueSlug: String,
        now: Instant = Instant.now(),
        asrIqamahPreference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
        includeTomorrowFajr: Boolean = true,
    ): NextPrayerCountdownResult? {
        val dayStart = now.atZone(sheffieldTimeZone).truncatedTo(ChronoUnit.DAYS)
        val isFriday = now.atZone(sheffieldTimeZone).dayOfWeek == DayOfWeek.FRIDAY
        val checkDate = dayStart.toInstant()

        fun wallClockToday(hhmm: String): Instant? {
            val p = hhmm.split(":").mapNotNull { it.trim().toIntOrNull() }
            if (p.size != 2) return null
            return dayStart.withHour(p[0]).withMinute(p[1]).withSecond(0).withNano(0).toInstant()
        }

        val jummahRaw = splitJummahIqamahTimes(iqamahTimes.jummah)
        val jummahTimes = if (jummahRaw.isEmpty()) listOf(iqamahTimes.dhuhr) else jummahRaw
        val jummahAdhan = nextHeroDisplayIqamahRaw(
            prayerId = "dhuhr",
            isFriday = isFriday,
            rawIqamahs = jummahTimes,
            adhan = prayerTimes.dhuhr,
            now = now,
            wallClock = ::wallClockToday,
        )

        val prayers = listOf(
            Triple("Fajr", prayerTimes.fajr, getIqamahTime("fajr", prayerTimes.fajr, iqamahTimes)),
            Triple(
                if (isFriday) "Jummah" else "Dhuhr",
                if (isFriday) jummahAdhan else prayerTimes.dhuhr,
                if (isFriday) "" else getIqamahTime("dhuhr", prayerTimes.dhuhr, iqamahTimes),
            ),
            Triple(
                "Asr",
                prayerTimes.asr,
                selectAsrIqamahTime(iqamahTimes.asr, prayerTimes.asr, asrIqamahPreference),
            ),
            Triple(
                "Maghrib",
                prayerTimes.maghrib,
                getIqamahTime("maghrib", prayerTimes.maghrib, iqamahTimes),
            ),
            Triple(
                "Isha",
                prayerTimes.isha,
                resolveIshaIqamahForDisplay(
                    slug = mosqueSlug,
                    date = checkDate,
                    ishaAdhan = prayerTimes.isha,
                    iqamahTimes = iqamahTimes,
                    maghribAdhan = prayerTimes.maghrib,
                ),
            ),
        )

        for (prayer in prayers) {
            val (name, adhan, iqamah) = prayer
            val isJummah = name == "Jummah"
            val adhanT = wallClockToday(adhan)
            if (adhanT != null && adhanT.isAfter(now)) {
                val diff = (adhanT.epochSecond - now.epochSecond).toInt()
                return NextPrayerCountdownResult(name, adhan, diff, isIqamah = false, isJummah = isJummah)
            }
            if (!isJummah && isParseableTime(iqamah) && iqamah != adhan) {
                val iqT = wallClockToday(iqamah)
                if (iqT != null && iqT.isAfter(now)) {
                    val diff = (iqT.epochSecond - now.epochSecond).toInt()
                    return NextPrayerCountdownResult(name, iqamah, diff, isIqamah = true, isJummah = false)
                }
            }
        }

        if (!includeTomorrowFajr) return null

        val fajrT = wallClockToday(prayers[0].second)
        if (fajrT != null) {
            val tomorrow = dayStart.plusDays(1)
            val nextFajr = tomorrow
                .withHour(fajrT.atZone(sheffieldTimeZone).hour)
                .withMinute(fajrT.atZone(sheffieldTimeZone).minute)
                .withSecond(0)
                .withNano(0)
                .toInstant()
            val diff = (nextFajr.epochSecond - now.epochSecond).toInt()
            return NextPrayerCountdownResult(
                nextName = "Fajr",
                nextTime = prayers[0].second,
                totalSeconds = maxOf(0, diff),
                isIqamah = false,
                isJummah = false,
            )
        }

        return null
    }

    // MARK: - Midnight / Last Third of the Night

    fun timeToMinutes(time: String): Int? {
        val parts = time.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (parts.size != 2) return null
        return parts[0] * 60 + parts[1]
    }

    fun minutesToTime(minutes: Int): String {
        val clamped = ((minutes % 1440) + 1440) % 1440
        return String.format(Locale.ROOT, "%02d:%02d", clamped / 60, clamped % 60)
    }

    data class MidnightAndLastThird(val midnight: String?, val lastThird: String?)

    /**
     * Night period: from today's Maghrib to **next day's Fajr**.
     * Midnight = midpoint of the night; Last Third starts at 2/3 through.
     */
    fun computeMidnightAndLastThird(maghrib: String, nextDayFajr: String?): MidnightAndLastThird {
        val nextFajr = nextDayFajr
        if (nextFajr == null ||
            !isParseableTime(maghrib) ||
            !isParseableTime(nextFajr)
        ) {
            return MidnightAndLastThird(null, null)
        }
        val maghribMin = timeToMinutes(maghrib) ?: return MidnightAndLastThird(null, null)
        val fajrMin = timeToMinutes(nextFajr) ?: return MidnightAndLastThird(null, null)

        val nightDuration = if (fajrMin >= maghribMin) {
            fajrMin - maghribMin
        } else {
            (24 * 60 - maghribMin) + fajrMin
        }

        if (nightDuration <= 0) return MidnightAndLastThird(null, null)

        val midnight = minutesToTime(maghribMin + nightDuration / 2)
        val lastThird = minutesToTime(maghribMin + (nightDuration * 2) / 3)
        return MidnightAndLastThird(midnight, lastThird)
    }

    // MARK: - Time parsing helpers

    fun isParseableTime(t: String): Boolean {
        if (t.isEmpty() || t == "-" || t == "—" || t == "--:--") return false
        if (nonParseablePhraseRegex.containsMatchIn(t)) return false
        return parseableTimeRegex.matches(t.trim())
    }

    private fun prayerWallClockDate(hour: Int, minute: Int, referenceNow: Instant = Instant.now()): ZonedDateTime? {
        val ymd = getDateInSheffield(referenceNow)
        return LocalDate.of(ymd.year, ymd.month, ymd.day)
            .atTime(hour, minute)
            .atZone(sheffieldTimeZone)
    }

    /** Formats an `HH:mm` prayer clock for UI using [locale] (digits, separators, AM/PM). */
    fun formatPrayerTimeForDisplay(timeString: String, uses24Hour: Boolean, locale: Locale): String {
        if (!isParseableTime(timeString)) return timeString
        val m = parseableTimeRegex.matchEntire(timeString.trim()) ?: return timeString
        val hour = m.groupValues[1].toIntOrNull() ?: return timeString
        val minute = m.groupValues[2].toIntOrNull() ?: return timeString
        val date = prayerWallClockDate(hour, minute) ?: return timeString
        val pattern = if (uses24Hour) "HH:mm" else "h:mma"
        return DateTimeFormatter.ofPattern(pattern, locale)
            .withZone(sheffieldTimeZone)
            .format(date)
    }

    /**
     * Localized clock for `HH:mm` data (digits, separators, AM/PM).
     * Matches Expo `formatPrayerClockForDisplay`.
     */
    fun formatPrayerClockForDisplay(timeString: String, uses24h: Boolean, locale: Locale): String {
        if (!isParseableTime(timeString)) return timeString
        val m = parseableTimeRegex.matchEntire(timeString.trim()) ?: return timeString
        val hour = m.groupValues[1].toIntOrNull() ?: return timeString
        val minute = m.groupValues[2].toIntOrNull() ?: return timeString
        val date = LocalDate.of(2000, 6, 15)
            .atTime(hour, minute)
            .atZone(sheffieldTimeZone)
        val pattern = if (uses24h) "HH:mm" else "h:mm a"
        val formatter = DateTimeFormatter.ofPattern(pattern, locale)
        return formatter.format(date)
    }

    data class PrayerTimeHeroParts(val clock: String, val meridiem: String?)

    /** Hero clock uses separate `h:mm` + `a` strings so AM/PM sits tight. */
    fun formatPrayerTimeHeroParts(
        timeString: String,
        uses24Hour: Boolean,
        locale: Locale,
    ): PrayerTimeHeroParts {
        if (!isParseableTime(timeString)) return PrayerTimeHeroParts(timeString, null)
        val m = parseableTimeRegex.matchEntire(timeString.trim()) ?: return PrayerTimeHeroParts(timeString, null)
        val hour = m.groupValues[1].toIntOrNull() ?: return PrayerTimeHeroParts(timeString, null)
        val minute = m.groupValues[2].toIntOrNull() ?: return PrayerTimeHeroParts(timeString, null)
        val date = prayerWallClockDate(hour, minute) ?: return PrayerTimeHeroParts(timeString, null)
        if (uses24Hour) {
            val clock = DateTimeFormatter.ofPattern("HH:mm", locale)
                .withZone(sheffieldTimeZone)
                .format(date)
            return PrayerTimeHeroParts(clock, null)
        }
        val clock = DateTimeFormatter.ofPattern("h:mm", locale)
            .withZone(sheffieldTimeZone)
            .format(date)
        val meridiem = DateTimeFormatter.ofPattern("a", locale)
            .withZone(sheffieldTimeZone)
            .format(date)
        return PrayerTimeHeroParts(clock, meridiem)
    }

    fun formatTo12Hour(timeString: String): String {
        if (!isParseableTime(timeString)) return timeString
        val p = timeString.split(":").mapNotNull { it.trim().toIntOrNull() }
        if (p.size != 2) return timeString
        val ampm = if (p[0] >= 12) "pm" else "am"
        val h12 = if (p[0] % 12 == 0) 12 else p[0] % 12
        return String.format(Locale.ROOT, "%d:%02d%s", h12, p[1], ampm)
    }
}
