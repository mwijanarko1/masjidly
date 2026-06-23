package com.mikhailspeaks.masjidly.ui.home

import android.icu.text.DateFormatSymbols
import android.icu.util.IslamicCalendar
import android.icu.util.ULocale
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Home date chrome strings — mirrors iOS `HomeView.dateString` / `hijriDateString`
 * and Expo `gregorianDateString` / `hijriDateString`.
 */
object HomeDateFormatting {
    fun gregorianDateString(
        date: Instant,
        locale: Locale,
        zone: ZoneId = ZoneId.systemDefault(),
    ): String =
        DateTimeFormatter.ofPattern("EEEE, d MMMM", locale)
            .withZone(zone)
            .format(date)
            .uppercase(locale)

    /** iOS pattern: `d MMMM yyyy` → e.g. "8 MUHARRAM 1448" (no era suffix). */
    fun hijriDateString(date: Instant, locale: Locale): String {
        val uLocale = ULocale.forLocale(locale)
        val islamicCal = IslamicCalendar(uLocale).apply {
            setCalculationType(IslamicCalendar.CalculationType.ISLAMIC_UMALQURA)
            timeInMillis = date.toEpochMilli()
        }

        return buildIslamicDateString(islamicCal, uLocale, locale)
            ?: run {
                islamicCal.setCalculationType(IslamicCalendar.CalculationType.ISLAMIC_CIVIL)
                buildIslamicDateString(islamicCal, uLocale, locale)
            }
            .orEmpty()
    }

    private fun buildIslamicDateString(
        islamicCal: IslamicCalendar,
        uLocale: ULocale,
        locale: Locale,
    ): String? =
        runCatching {
            val symbols = DateFormatSymbols(islamicCal, uLocale)
            val month = symbols.months[islamicCal.get(IslamicCalendar.MONTH)]
            val day = islamicCal.get(IslamicCalendar.DAY_OF_MONTH)
            val year = islamicCal.get(IslamicCalendar.YEAR)
            // Explicit d MMMM yyyy — ICU pattern instances add ", yyyy G" / "AH" for some locales.
            "$day $month $year".uppercase(locale)
        }.getOrNull()
}
