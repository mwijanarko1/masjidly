package com.mikhailspeaks.masjidly.domain

/** Mirrors iOS `PrayerLocalization.swift`. */
object PrayerLocalization {
    fun displayName(canonicalEnglish: String, language: AppLanguage): String {
        val key = when (canonicalEnglish) {
            "Fajr" -> "prayer.fajr"
            "Sunrise" -> "prayer.sunrise"
            "Dhuhr" -> "prayer.dhuhr"
            "Jummah" -> "prayer.jummah"
            "Asr" -> "prayer.asr"
            "Maghrib" -> "prayer.maghrib"
            "Isha" -> "prayer.isha"
            "Tahajjud" -> "prayer.tahajjud"
            else -> return canonicalEnglish
        }
        return LocaleStrings.t(key, language)
    }
}

fun AdhanPrayerToggle.localizedLabel(language: AppLanguage): String = when (this) {
    AdhanPrayerToggle.FAJR -> LocaleStrings.t("settings.notification.fajr", language)
    AdhanPrayerToggle.DHUHR_JUMMAH -> LocaleStrings.t("settings.notification.dhuhr_jummah", language)
    AdhanPrayerToggle.ASR -> LocaleStrings.t("settings.notification.asr", language)
    AdhanPrayerToggle.MAGHRIB -> LocaleStrings.t("settings.notification.maghrib", language)
    AdhanPrayerToggle.ISHA -> LocaleStrings.t("settings.notification.isha", language)
}

fun IqamahPrayerToggle.localizedLabel(language: AppLanguage): String = when (this) {
    IqamahPrayerToggle.FAJR -> LocaleStrings.t("settings.notification.fajr", language)
    IqamahPrayerToggle.DHUHR_JUMMAH -> LocaleStrings.t("settings.notification.dhuhr_jummah", language)
    IqamahPrayerToggle.ASR -> LocaleStrings.t("settings.notification.asr", language)
    IqamahPrayerToggle.MAGHRIB -> LocaleStrings.t("settings.notification.maghrib", language)
    IqamahPrayerToggle.ISHA -> LocaleStrings.t("settings.notification.isha", language)
}
