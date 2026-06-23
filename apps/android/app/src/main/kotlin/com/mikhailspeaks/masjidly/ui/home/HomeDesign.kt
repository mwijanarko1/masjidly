package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import com.mikhailspeaks.masjidly.domain.DailyPrayerTimes

/** Mirrors iOS `HomeDesign.ThemeMode`. */
enum class ThemeMode(val wireValue: String) {
    DYNAMIC("dynamic"),
    FIXED("fixed"),
    ;

    companion object {
        fun fromWire(value: String?): ThemeMode =
            if (value == FIXED.wireValue) FIXED else DYNAMIC
    }
}

/**
 * Mirrors iOS `HomeDesign.SkyTheme` with multi-color gradients + glow.
 */
data class SkyTheme(
    val baseColors: List<Color>,
    val glowColor: Color?,
    val glowBaseAlpha: Float = 1.0f,
) {
    val top: Color get() = baseColors.first()
    val bottom: Color get() = baseColors.last()
}

/** Mirrors iOS `HomeDesign.TimeTheme` sky gradients for the home hero. */
enum class TimeTheme(
    val wireValue: String,
    val sky: SkyTheme,
    val usesLightForeground: Boolean,
) {
    FAJR(
        "fajr",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF020326),
                Color(0xFF06114F),
                Color(0xFF0B1E6D),
                Color(0xFF3B2A5A),
            ),
            glowColor = Color(0xFFF08A4B),
        ),
        usesLightForeground = true,
    ),
    SUNRISE(
        "sunrise",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF6B7280),
                Color(0xFFC084FC),
                Color(0xFFFB923C),
                Color(0xFFF59E0B),
            ),
            glowColor = Color(0xFFFEF08A),
        ),
        usesLightForeground = false,
    ),
    DHUHR(
        "dhuhr",
        SkyTheme(
            baseColors = listOf(
                Color(0xFFE0F2FE),
                Color(0xFF7DD3FC),
                Color(0xFF38BDF8),
            ),
            glowColor = Color(0xFF38BDF8),
            glowBaseAlpha = 0.2f,
        ),
        usesLightForeground = false,
    ),
    ASR(
        "asr",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF93C5FD),
                Color(0xFFFDE68A),
                Color(0xFFFDBA74),
            ),
            glowColor = Color(0xFFD6B38A),
        ),
        usesLightForeground = false,
    ),
    MAGHRIB(
        "maghrib",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF6D3FA9),
                Color(0xFFA855F7),
                Color(0xFFF472B6),
                Color(0xFFFB7185),
            ),
            glowColor = Color(0xFFF59E0B),
        ),
        usesLightForeground = true,
    ),
    ISHA(
        "isha",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF000000),
                Color(0xFF020617),
                Color(0xFF0F172A),
            ),
            glowColor = Color(0xFF0F172A),
            glowBaseAlpha = 0.4f,
        ),
        usesLightForeground = true,
    ),
    TAHAJJUD(
        "tahajjud",
        SkyTheme(
            baseColors = listOf(
                Color(0xFF000000),
                Color(0xFF01030A),
                Color(0xFF020617),
            ),
            glowColor = null,
        ),
        usesLightForeground = true,
    ),
    ;

    val top: Color get() = sky.top
    val bottom: Color get() = sky.bottom
    val glow: Color? get() = sky.glowColor

    val textColor: Color
        get() = if (usesLightForeground) Color.White else Color(0xFF111111)

    /** Full vertical gradient brush with all sky colors. */
    val verticalGradientBrush: Brush
        get() = Brush.verticalGradient(sky.baseColors)

    /** Linear gradient (top-leading to bottom-trailing) for timetable/settings backgrounds. */
    val diagonalGradientBrush: Brush
        get() = Brush.linearGradient(sky.baseColors, start = androidx.compose.ui.geometry.Offset.Zero, end = androidx.compose.ui.geometry.Offset(1f, 1f))

    companion object {
        val homePrayerThemes = listOf(FAJR, SUNRISE, DHUHR, ASR, MAGHRIB, ISHA)
        val selectablePrayerThemes = homePrayerThemes

        fun fromWire(value: String?): TimeTheme =
            entries.firstOrNull { it.wireValue == value?.lowercase() } ?: FAJR

        fun homeHeroTheme(
            displayedPrayerTimes: DailyPrayerTimes?,
            selectedPrayerIndex: Int,
        ): TimeTheme {
            if (displayedPrayerTimes == null) return FAJR
            return homePrayerThemes.getOrElse(selectedPrayerIndex.coerceIn(0, homePrayerThemes.lastIndex)) { FAJR }
        }
    }
}

/** Brand colors — mirrors iOS `HomeDesign.Colors`. */
object MasjidlyColors {
    val accent = Color(0xFF47A6FF)
    val activeGradientBrush = Brush.linearGradient(
        colors = listOf(Color(0xFF47A6FF), Color(0xFF2E8DFF)),
    )
}

/** Canonical prayer slots on home (6 items incl. Sunrise; Friday uses Jummah label). */
val HOME_PRAYER_CANONICAL = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")
val HOME_PRAYER_IDS = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

/** Timetable / carousel labels (5 daily prayers). */
val PRAYER_IDS = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
val PRAYER_LABELS = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
