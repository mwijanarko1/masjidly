package com.mikhailspeaks.masjidly.domain

import kotlinx.serialization.Serializable

/** Mirrors iOS `NotificationSettings.swift`. */
@Serializable
data class NotificationSettings(
    var masterEnabled: Boolean = false,
    var adhanEnabled: Boolean = true,
    var iqamahEnabled: Boolean = true,
    var preAdhanReminderMinutes: Int? = null,
    var preIqamahReminderMinutes: Int? = null,
    var adhanFajr: Boolean = true,
    var adhanDhuhrJummah: Boolean = true,
    var adhanAsr: Boolean = true,
    var adhanMaghrib: Boolean = true,
    var adhanIsha: Boolean = true,
    var iqamahFajr: Boolean = true,
    var iqamahDhuhrJummah: Boolean = true,
    var iqamahAsr: Boolean = true,
    var iqamahMaghrib: Boolean = true,
    var iqamahIsha: Boolean = true,
)

enum class AdhanPrayerToggle(val label: String) {
    FAJR("Fajr"),
    DHUHR_JUMMAH("Dhuhr / Jummah"),
    ASR("Asr"),
    MAGHRIB("Maghrib"),
    ISHA("Isha"),
}

enum class IqamahPrayerToggle(val label: String) {
    FAJR("Fajr"),
    DHUHR_JUMMAH("Dhuhr / Jummah"),
    ASR("Asr"),
    MAGHRIB("Maghrib"),
    ISHA("Isha"),
}

fun NotificationSettings.adhanEnabled(prayer: AdhanPrayerToggle): Boolean = when (prayer) {
    AdhanPrayerToggle.FAJR -> adhanFajr
    AdhanPrayerToggle.DHUHR_JUMMAH -> adhanDhuhrJummah
    AdhanPrayerToggle.ASR -> adhanAsr
    AdhanPrayerToggle.MAGHRIB -> adhanMaghrib
    AdhanPrayerToggle.ISHA -> adhanIsha
}

fun NotificationSettings.setAdhanEnabled(prayer: AdhanPrayerToggle, enabled: Boolean) {
    when (prayer) {
        AdhanPrayerToggle.FAJR -> adhanFajr = enabled
        AdhanPrayerToggle.DHUHR_JUMMAH -> adhanDhuhrJummah = enabled
        AdhanPrayerToggle.ASR -> adhanAsr = enabled
        AdhanPrayerToggle.MAGHRIB -> adhanMaghrib = enabled
        AdhanPrayerToggle.ISHA -> adhanIsha = enabled
    }
}

fun NotificationSettings.iqamahEnabled(prayer: IqamahPrayerToggle): Boolean = when (prayer) {
    IqamahPrayerToggle.FAJR -> iqamahFajr
    IqamahPrayerToggle.DHUHR_JUMMAH -> iqamahDhuhrJummah
    IqamahPrayerToggle.ASR -> iqamahAsr
    IqamahPrayerToggle.MAGHRIB -> iqamahMaghrib
    IqamahPrayerToggle.ISHA -> iqamahIsha
}

fun NotificationSettings.setIqamahEnabled(prayer: IqamahPrayerToggle, enabled: Boolean) {
    when (prayer) {
        IqamahPrayerToggle.FAJR -> iqamahFajr = enabled
        IqamahPrayerToggle.DHUHR_JUMMAH -> iqamahDhuhrJummah = enabled
        IqamahPrayerToggle.ASR -> iqamahAsr = enabled
        IqamahPrayerToggle.MAGHRIB -> iqamahMaghrib = enabled
        IqamahPrayerToggle.ISHA -> iqamahIsha = enabled
    }
}

fun NotificationSettings.syncMasterFlag() {
    masterEnabled = adhanEnabled ||
        iqamahEnabled ||
        preAdhanReminderMinutes != null ||
        preIqamahReminderMinutes != null
}
