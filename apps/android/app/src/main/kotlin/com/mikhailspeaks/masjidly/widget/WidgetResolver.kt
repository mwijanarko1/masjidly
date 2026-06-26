package com.mikhailspeaks.masjidly.widget

import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Android port of iOS `MasjidlyWidgetResolver` — drives small/medium/large widget layouts.
 */
object WidgetResolver {
    private val sheffieldTimeZone: ZoneId = PrayerTimesEngine.sheffieldTimeZone

    private data class ResolvedPrayer(
        val id: String,
        val name: String,
        val adhan: String,
        val iqamahs: List<String>,
        val adhanDate: Instant?,
    )

    private data class LocalizedNames(
        val fajr: String,
        val dhuhr: String,
        val asr: String,
        val maghrib: String,
        val isha: String,
        val jummah: String,
    )

    fun resolve(
        snapshot: WidgetPrayerSnapshot,
        now: Instant = Instant.now(),
        includeTomorrowFajr: Boolean = true,
    ): WidgetPrayerState {
        val todayString = isoDateString(now)
        val day = snapshot.days.firstOrNull { it.date == todayString } ?: return WidgetPrayerState.stale()
        var resolvedDay = day

        val locale = snapshotLocale(snapshot.appLanguageRawValue)
        val language = AppLanguage.fromWire(snapshot.appLanguageRawValue)
        val names = localizedPrayerNames(language)

        var dayStart = now.atZone(sheffieldTimeZone).truncatedTo(ChronoUnit.DAYS)

        fun wallClockDay(time: String, baseDate: ZonedDateTime): Instant? {
            val parts = time.split(":").mapNotNull { it.trim().toIntOrNull() }
            if (parts.size != 2) return null
            return baseDate.withHour(parts[0]).withMinute(parts[1]).withSecond(0).withNano(0).toInstant()
        }

        fun wallClockToday(time: String): Instant? = wallClockDay(time, dayStart)

        if (!includeTomorrowFajr) {
            val ishaIqamahRaw = resolveIqamah(
                prayer = "isha",
                adhan = resolvedDay.prayers.isha,
                iqamah = resolvedDay.iqamah,
                mosqueSlug = snapshot.mosque.slug,
                date = now,
                maghribAdhan = resolvedDay.prayers.maghrib,
                asrPreference = snapshot.asrIqamahPreference,
            )
            val ishaCutoff = wallClockDay(ishaIqamahRaw, dayStart)?.plusSeconds(10 * 60)
            if (ishaCutoff != null && !now.isBefore(ishaCutoff)) {
                val tomorrowString = isoDateString(dayStart.plusDays(1).toInstant())
                snapshot.days.firstOrNull { it.date == tomorrowString }?.let { tomorrowDay ->
                    resolvedDay = tomorrowDay
                    dayStart = dayStart.plusDays(1)
                }
            }
        }

        val resolvedIsFriday = dayStart.dayOfWeek == DayOfWeek.FRIDAY
        val jummahRaw = PrayerTimesEngine.splitJummahIqamahTimes(resolvedDay.iqamah.jummah)
        val jummahTimes = if (jummahRaw.isEmpty()) listOf(resolvedDay.iqamah.dhuhr) else jummahRaw
        val jummahAdhan = nextDisplayIqamahRaw(
            prayerId = "dhuhr",
            isFriday = resolvedIsFriday,
            rawIqamahs = jummahTimes,
            adhan = resolvedDay.prayers.dhuhr,
            now = now,
            wallClock = ::wallClockToday,
        )

        val prayersList = listOf(
            ResolvedPrayer(
                id = "fajr",
                name = names.fajr,
                adhan = resolvedDay.prayers.fajr,
                iqamahs = listOf(resolveIqamah("fajr", resolvedDay.prayers.fajr, resolvedDay.iqamah)),
                adhanDate = wallClockToday(resolvedDay.prayers.fajr),
            ),
            ResolvedPrayer(
                id = "dhuhr",
                name = if (resolvedIsFriday) {
                    jummahDisplayName(names.jummah, jummahAdhan, jummahTimes)
                } else {
                    names.dhuhr
                },
                adhan = if (resolvedIsFriday) jummahAdhan else resolvedDay.prayers.dhuhr,
                iqamahs = if (resolvedIsFriday) jummahTimes else listOf(
                    resolveIqamah("dhuhr", resolvedDay.prayers.dhuhr, resolvedDay.iqamah),
                ),
                adhanDate = wallClockToday(if (resolvedIsFriday) jummahAdhan else resolvedDay.prayers.dhuhr),
            ),
            ResolvedPrayer(
                id = "asr",
                name = names.asr,
                adhan = resolvedDay.prayers.asr,
                iqamahs = listOf(
                    selectAsrIqamah(
                        resolveIqamah("asr", resolvedDay.prayers.asr, resolvedDay.iqamah),
                        adhan = resolvedDay.prayers.asr,
                        preference = snapshot.asrIqamahPreference,
                    ),
                ),
                adhanDate = wallClockToday(resolvedDay.prayers.asr),
            ),
            ResolvedPrayer(
                id = "maghrib",
                name = names.maghrib,
                adhan = resolvedDay.prayers.maghrib,
                iqamahs = listOf(
                    resolveIqamah("maghrib", resolvedDay.prayers.maghrib, resolvedDay.iqamah),
                ),
                adhanDate = wallClockToday(resolvedDay.prayers.maghrib),
            ),
            ResolvedPrayer(
                id = "isha",
                name = names.isha,
                adhan = resolvedDay.prayers.isha,
                iqamahs = listOf(
                    resolveIqamah(
                        prayer = "isha",
                        adhan = resolvedDay.prayers.isha,
                        iqamah = resolvedDay.iqamah,
                        mosqueSlug = snapshot.mosque.slug,
                        date = now,
                        maghribAdhan = resolvedDay.prayers.maghrib,
                        asrPreference = snapshot.asrIqamahPreference,
                    ),
                ),
                adhanDate = wallClockToday(resolvedDay.prayers.isha),
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

            val candidateIqamah = nextDisplayIqamahRaw(
                prayerId = p.id,
                isFriday = resolvedIsFriday,
                rawIqamahs = p.iqamahs,
                adhan = p.adhan,
                now = now,
                wallClock = ::wallClockToday,
            )
            if (PrayerTimesEngine.isParseableTime(candidateIqamah) && candidateIqamah != p.adhan) {
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

        if (!foundTodayEvent && !includeTomorrowFajr) {
            nextPrayerIndex = prayersList.lastIndex.coerceAtLeast(0)
        }

        val isNextFajrTomorrow = !foundTodayEvent && includeTomorrowFajr
        val morrowDay = if (isNextFajrTomorrow) {
            val tomorrowString = isoDateString(dayStart.plusDays(1).toInstant())
            snapshot.days.firstOrNull { it.date == tomorrowString }
        } else {
            null
        }

        if (isNextFajrTomorrow && morrowDay == null) {
            return WidgetPrayerState.stale()
        }

        val next = if (isNextFajrTomorrow && morrowDay != null) {
            val morrowStart = dayStart.plusDays(1)
            ResolvedPrayer(
                id = "fajr",
                name = names.fajr,
                adhan = morrowDay.prayers.fajr,
                iqamahs = listOf(resolveIqamah("fajr", morrowDay.prayers.fajr, morrowDay.iqamah)),
                adhanDate = wallClockDay(morrowDay.prayers.fajr, morrowStart),
            )
        } else {
            prayersList[nextPrayerIndex]
        }

        val nextWallClockBase = if (isNextFajrTomorrow) dayStart.plusDays(1) else dayStart
        val rawIqamahsForNext = when {
            resolvedIsFriday && next.id == "dhuhr" -> jummahTimes
            isNextFajrTomorrow && morrowDay != null -> listOf(
                resolveIqamah("fajr", morrowDay.prayers.fajr, morrowDay.iqamah),
            )
            else -> listOf(
                resolveIqamah(
                    prayer = next.id,
                    adhan = next.adhan,
                    iqamah = if (isNextFajrTomorrow) morrowDay?.iqamah ?: day.iqamah else day.iqamah,
                    mosqueSlug = snapshot.mosque.slug,
                    date = nextWallClockBase.toInstant(),
                    maghribAdhan = (if (isNextFajrTomorrow) morrowDay?.prayers?.maghrib else day.prayers.maghrib)
                        ?: day.prayers.maghrib,
                    asrPreference = snapshot.asrIqamahPreference,
                ),
            )
        }

        val displayIqamahRaw = nextDisplayIqamahRaw(
            prayerId = next.id,
            isFriday = resolvedIsFriday,
            rawIqamahs = rawIqamahsForNext,
            adhan = next.adhan,
            now = now,
            wallClock = { wallClockDay(it, nextWallClockBase) },
        )

        val targetDate = if (isNextFajrTomorrow) next.adhanDate else nextEventDate
        val countdownLabelKind = when {
            nextEventIsIqamah -> HeroCountdownLabelKind.IQAMAH_IN
            nextPrayerIndex == 0 && !isNextFajrTomorrow -> HeroCountdownLabelKind.ADHAN_IN
            else -> HeroCountdownLabelKind.NEXT_PRAYER
        }

        val rows = prayersList.flatMapIndexed { i, p ->
            val isNext = i == nextPrayerIndex && !isNextFajrTomorrow
            val isPassed = when {
                isNextFajrTomorrow && i == 0 -> false
                else -> !isNext && (p.adhanDate?.isAfter(now) != true) && (nextPrayerIndex != 0 || i != 0)
            }

            val rowAdhan: String
            val rowIqamahs: List<String>
            if (isNextFajrTomorrow && i == 0 && morrowDay != null) {
                rowAdhan = morrowDay.prayers.fajr
                rowIqamahs = listOf(resolveIqamah("fajr", morrowDay.prayers.fajr, morrowDay.iqamah))
            } else {
                rowAdhan = p.adhan
                rowIqamahs = p.iqamahs
            }

            if (resolvedIsFriday && p.id == "dhuhr" && jummahTimes.size > 1) {
                jummahTimes.mapIndexed { idx, slot ->
                    WidgetPrayerRow(
                        id = "jummah_$idx",
                        name = "${names.jummah} ${idx + 1}",
                        adhan = format(rowAdhan, snapshot.uses24HourTime, locale, now),
                        iqamahs = listOf(format(slot, snapshot.uses24HourTime, locale, now)),
                        isPassed = isPassed,
                        isNext = isNext && slot == jummahAdhan,
                    )
                }
            } else {
                listOf(
                    WidgetPrayerRow(
                        id = p.id,
                        name = p.name,
                        adhan = format(rowAdhan, snapshot.uses24HourTime, locale, now),
                        iqamahs = rowIqamahs.map { format(it, snapshot.uses24HourTime, locale, now) },
                        isPassed = isPassed,
                        isNext = isNext,
                    ),
                )
            }
        }

        return WidgetPrayerState(
            kind = WidgetStateKind.CONTENT,
            mosqueName = snapshot.mosque.name,
            prayerId = next.id,
            prayerName = next.name,
            adhanTime = format(next.adhan, snapshot.uses24HourTime, locale, now),
            iqamahTime = format(displayIqamahRaw, snapshot.uses24HourTime, locale, now),
            targetDateEpochMillis = targetDate?.toEpochMilli(),
            countdownLabelKind = countdownLabelKind,
            rows = rows,
            displayDateEpochMillis = dayStart.toInstant().toEpochMilli(),
        )
    }

    private fun localizedPrayerNames(language: AppLanguage): LocalizedNames = when (language) {
        AppLanguage.ARABIC -> LocalizedNames("الفجر", "الظهر", "العصر", "المغرب", "العشاء", "الجمعة")
        AppLanguage.URDU -> LocalizedNames("فجر", "ظہر", "عصر", "مغرب", "عشاء", "جمعہ")
        AppLanguage.INDONESIAN -> LocalizedNames("Fajr", "Dzuhur", "Asr", "Maghrib", "Isha", "Jumat")
        AppLanguage.ENGLISH -> LocalizedNames("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah")
    }

    private fun jummahDisplayName(base: String, selectedRaw: String, allSlots: List<String>): String {
        if (allSlots.size <= 1) return base
        val selected = selectedRaw.trim()
        val idx = allSlots.indexOfFirst { it.trim() == selected }
        return if (idx >= 0) "$base ${idx + 1}" else base
    }

    private fun nextDisplayIqamahRaw(
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
        if (now.isBefore(adhanDate)) return rawIqamahs.firstOrNull().orEmpty()
        for (raw in rawIqamahs) {
            val d = wallClock(raw)
            if (d != null && d.isAfter(now)) return raw
        }
        return rawIqamahs.lastOrNull().orEmpty()
    }

    private fun resolveIqamah(
        prayer: String,
        adhan: String,
        iqamah: WidgetDailyIqamahTimes,
        mosqueSlug: String = "",
        date: Instant = Instant.now(),
        maghribAdhan: String = "",
        asrPreference: String? = null,
    ): String {
        val raw = when (prayer) {
            "fajr" -> if (iqamah.fajr == "Various") adhan else iqamah.fajr
            "dhuhr" -> iqamah.dhuhr
            "asr" -> if (iqamah.asr.equals("entry time", ignoreCase = true)) {
                adhan
            } else {
                selectAsrIqamah(iqamah.asr, adhan, asrPreference)
            }
            "maghrib" -> if (iqamah.maghrib == "sunset") adhan else iqamah.maghrib
            "isha" -> when {
                isMasjidRisalah(mosqueSlug) && isRisalahIshaIqamahMatchesAdhanPeriod(date) -> adhan
                isMuslimWelfareHouse(mosqueSlug) && isSummerIshaPeriod(date) -> "After Maghrib"
                iqamah.isha == "Straight after Maghrib" -> maghribAdhan.ifBlank { adhan }
                iqamah.isha == "Entry Time" -> adhan
                else -> iqamah.isha
            }
            else -> ""
        }
        return PrayerTimesEngine.resolveRelativeIqamah(raw, adhan)
    }

    private fun selectAsrIqamah(raw: String, adhan: String? = null, preference: String?): String {
        if (raw.equals("entry time", ignoreCase = true)) return adhan ?: raw
        val slots = PrayerTimesEngine.splitJummahIqamahTimes(raw).map { slot ->
            if (adhan != null) PrayerTimesEngine.resolveRelativeIqamah(slot, adhan) else slot
        }
        val resolved = slots.ifEmpty {
            listOf(adhan?.let { PrayerTimesEngine.resolveRelativeIqamah(raw, it) } ?: raw)
        }
        return if (preference == "second") resolved.drop(1).firstOrNull() ?: resolved.firstOrNull().orEmpty()
        else resolved.firstOrNull().orEmpty()
    }

    private fun isMasjidRisalah(slug: String): Boolean =
        slug.trim().lowercase() == "masjid-risalah"

    private fun isMuslimWelfareHouse(slug: String): Boolean =
        slug.trim().lowercase() == "muslim-welfare-house"

    private fun isSummerIshaPeriod(date: Instant): Boolean {
        val zoned = date.atZone(sheffieldTimeZone)
        val year = zoned.year
        val may15 = ZonedDateTime.of(year, 5, 15, 12, 0, 0, 0, sheffieldTimeZone)
        val aug15 = ZonedDateTime.of(year, 8, 15, 12, 0, 0, 0, sheffieldTimeZone)
        return !zoned.isBefore(may15) && !zoned.isAfter(aug15)
    }

    private fun isRisalahIshaIqamahMatchesAdhanPeriod(date: Instant): Boolean {
        val zoned = date.atZone(sheffieldTimeZone)
        val year = zoned.year
        val may1 = ZonedDateTime.of(year, 5, 1, 12, 0, 0, 0, sheffieldTimeZone)
        val july31 = ZonedDateTime.of(year, 7, 31, 12, 0, 0, 0, sheffieldTimeZone)
        return !zoned.isBefore(may1) && !zoned.isAfter(july31)
    }

    private fun isoDateString(instant: Instant): String {
        val zoned = instant.atZone(sheffieldTimeZone)
        return String.format(
            Locale.ROOT,
            "%04d-%02d-%02d",
            zoned.year,
            zoned.monthValue,
            zoned.dayOfMonth,
        )
    }

    private fun snapshotLocale(raw: String): Locale = AppLanguage.fromWire(raw).resolvedLocale()

    private fun format(time: String, uses24HourTime: Boolean, locale: Locale, reference: Instant): String =
        PrayerTimesEngine.formatPrayerTimeForDisplay(time, uses24HourTime, locale)
}
