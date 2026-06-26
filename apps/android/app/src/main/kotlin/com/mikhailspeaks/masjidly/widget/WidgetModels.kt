package com.mikhailspeaks.masjidly.widget

import com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind
import kotlinx.serialization.Serializable

object WidgetSharedConfig {
    const val PREFS_NAME = "masjidly_widget"
    const val SNAPSHOT_KEY = "widgetPrayerSnapshot.v1"
    const val SNAPSHOT_BY_MOSQUE_PREFIX = "widgetPrayerSnapshot.v1.mosque."
    const val MOSQUE_DIRECTORY_KEY = "widgetMosqueDirectory.v1"
    const val APP_SELECTED_MOSQUE_ID_KEY = "appSelectedMosqueId"
}

@Serializable
data class WidgetMosqueSnapshot(
    val id: String,
    val name: String,
    val slug: String,
    val citySlug: String? = null,
    val cityName: String? = null,
    val countryCode: String? = null,
    val countryName: String? = null,
)

@Serializable
data class WidgetPrayerDaySnapshot(
    val date: String,
    val prayers: WidgetDailyPrayerTimes,
    val iqamah: WidgetDailyIqamahTimes,
)

@Serializable
data class WidgetPrayerSnapshot(
    val schemaVersion: Int,
    val generatedAt: String,
    val mosque: WidgetMosqueSnapshot,
    val days: List<WidgetPrayerDaySnapshot>,
    val uses24HourTime: Boolean,
    val appLanguageRawValue: String,
    val asrIqamahPreference: String? = null,
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

@Serializable
data class WidgetDailyPrayerTimes(
    var date: String,
    var fajr: String,
    var sunrise: String,
    var dhuhr: String,
    var asr: String,
    var maghrib: String,
    var isha: String,
)

@Serializable
data class WidgetDailyIqamahTimes(
    var fajr: String,
    var dhuhr: String,
    var asr: String,
    var maghrib: String,
    var isha: String,
    var jummah: String,
)

enum class WidgetStateKind {
    CONTENT,
    MISSING,
    STALE,
}

data class WidgetPrayerRow(
    val id: String,
    val name: String,
    val adhan: String,
    val iqamahs: List<String>,
    val isPassed: Boolean,
    val isNext: Boolean,
)

data class WidgetPrayerState(
    val kind: WidgetStateKind,
    val mosqueName: String,
    val prayerId: String,
    val prayerName: String,
    val adhanTime: String,
    val iqamahTime: String,
    val targetDateEpochMillis: Long? = null,
    val countdownLabelKind: HeroCountdownLabelKind? = null,
    val rows: List<WidgetPrayerRow>,
    val displayDateEpochMillis: Long,
) {
    val mosqueDisplayName: String
        get() = mosqueName.ifBlank { "Masjidly" }

    companion object {
        val placeholder = WidgetPrayerState(
            kind = WidgetStateKind.CONTENT,
            mosqueName = "Masjidly",
            prayerId = "dhuhr",
            prayerName = "Dhuhr",
            adhanTime = "1:10pm",
            iqamahTime = "1:30pm",
            targetDateEpochMillis = System.currentTimeMillis() + 3_600_000,
            countdownLabelKind = HeroCountdownLabelKind.ADHAN_IN,
            rows = listOf(
                WidgetPrayerRow("fajr", "Fajr", "5:00am", listOf("5:20am"), isPassed = true, isNext = false),
                WidgetPrayerRow("dhuhr", "Dhuhr", "1:10pm", listOf("1:30pm"), isPassed = false, isNext = true),
                WidgetPrayerRow("asr", "Asr", "5:30pm", listOf("5:45pm"), isPassed = false, isNext = false),
                WidgetPrayerRow("maghrib", "Maghrib", "8:45pm", listOf("8:50pm"), isPassed = false, isNext = false),
                WidgetPrayerRow("isha", "Isha", "10:15pm", listOf("10:30pm"), isPassed = false, isNext = false),
            ),
            displayDateEpochMillis = System.currentTimeMillis(),
        )

        val missing = WidgetPrayerState(
            kind = WidgetStateKind.MISSING,
            mosqueName = "Masjidly",
            prayerId = "",
            prayerName = "",
            adhanTime = "--:--",
            iqamahTime = "--:--",
            rows = emptyList(),
            displayDateEpochMillis = System.currentTimeMillis(),
        )

        fun stale() = missing.copy(kind = WidgetStateKind.STALE)
    }
}
