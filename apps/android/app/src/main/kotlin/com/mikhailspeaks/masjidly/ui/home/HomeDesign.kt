package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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

/** User-facing labels: **Original** (`classic`), **Modern** (`set2`). */
enum class SkyGradientSet(val wireValue: String) {
    CLASSIC("classic"),
    SET2("set2"),
    ;

    companion object {
        fun fromWire(value: String?): SkyGradientSet? =
            entries.firstOrNull { it.wireValue == value?.lowercase() }
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

/** Mirrors iOS `HomeDesign.ResolvedTheme`. */
data class ResolvedTheme(
    val timeTheme: TimeTheme,
    val gradientSet: SkyGradientSet,
) {
    val sky: SkyTheme get() = timeTheme.sky(gradientSet)
    val textColor: Color get() = timeTheme.textColor(gradientSet)
    val usesLightForeground: Boolean get() = timeTheme.usesLightForeground(gradientSet)
    val wireValue: String get() = timeTheme.wireValue
    val top: Color get() = sky.top
    val bottom: Color get() = sky.bottom
    val glow: Color? get() = sky.glowColor

    val verticalGradientBrush: Brush
        get() = Brush.verticalGradient(sky.baseColors)

    val diagonalGradientBrush: Brush
        get() = Brush.linearGradient(
            sky.baseColors,
            start = Offset.Zero,
            end = Offset(1f, 1f),
        )
}

/** Mirrors iOS `HomeDesign.TimeTheme` sky gradients for the home hero. */
enum class TimeTheme(val wireValue: String) {
    FAJR("fajr"),
    SUNRISE("sunrise"),
    DHUHR("dhuhr"),
    ASR("asr"),
    MAGHRIB("maghrib"),
    ISHA("isha"),
    TAHAJJUD("tahajjud"),
    ;

    /** Default appearance when no per-prayer override is applied (onboarding, etc.). */
    val sky: SkyTheme get() = sky(defaultGradientSet())
    val textColor: Color get() = textColor(defaultGradientSet())
    val usesLightForeground: Boolean get() = usesLightForeground(defaultGradientSet())
    val top: Color get() = sky.top
    val bottom: Color get() = sky.bottom
    val glow: Color? get() = sky.glowColor

    val verticalGradientBrush: Brush
        get() = Brush.verticalGradient(sky.baseColors)

    val diagonalGradientBrush: Brush
        get() = Brush.linearGradient(
            sky.baseColors,
            start = Offset.Zero,
            end = Offset(1f, 1f),
        )

    fun defaultGradientSet(): SkyGradientSet = when (this) {
        FAJR, SUNRISE, MAGHRIB -> SkyGradientSet.SET2
        else -> SkyGradientSet.CLASSIC
    }

    fun sky(set: SkyGradientSet): SkyTheme = when (set) {
        SkyGradientSet.CLASSIC -> classicSetSky
        SkyGradientSet.SET2 -> set2Sky
    }

    fun textColor(set: SkyGradientSet): Color = when (set) {
        SkyGradientSet.CLASSIC -> when (this) {
            FAJR, MAGHRIB, ISHA, TAHAJJUD -> Color.White
            else -> Color(0xFF111111)
        }
        SkyGradientSet.SET2 -> when (this) {
            FAJR, ISHA, TAHAJJUD -> Color.White
            else -> Color(0xFF111111)
        }
    }

    fun usesLightForeground(set: SkyGradientSet): Boolean = textColor(set) == Color.White

    private val set2Sky: SkyTheme
        get() = when (this) {
            FAJR -> SkyTheme(
                baseColors = listOf(Color(0xFF6274E7), Color(0xFF8752A3)),
                glowColor = null,
            )
            SUNRISE -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF9FF1F2),
                    Color(0xFF6CD4E4),
                    Color(0xFF73E1EA),
                    Color(0xFFBDE2BD),
                ),
                glowColor = null,
            )
            DHUHR -> SkyTheme(
                baseColors = listOf(Color(0xFFEBF4F5), Color(0xFFB5C6E0)),
                glowColor = null,
            )
            ASR -> SkyTheme(
                baseColors = listOf(Color(0xFFFBD07C), Color(0xFFF7F779)),
                glowColor = null,
            )
            MAGHRIB -> SkyTheme(
                baseColors = listOf(Color(0xFFF2D7D9), Color(0xFFE786A7)),
                glowColor = null,
            )
            ISHA -> SkyTheme(
                baseColors = listOf(Color(0xFF000328), Color(0xFF00458E)),
                glowColor = null,
            )
            else -> classicSetSky
        }

    private val classicSetSky: SkyTheme
        get() = when (this) {
            FAJR -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF020326),
                    Color(0xFF06114F),
                    Color(0xFF0B1E6D),
                    Color(0xFF3B2A5A),
                ),
                glowColor = Color(0xFFF08A4B),
            )
            SUNRISE -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF6B7280),
                    Color(0xFFC084FC),
                    Color(0xFFFB923C),
                    Color(0xFFF59E0B),
                ),
                glowColor = Color(0xFFFEF08A),
            )
            DHUHR -> SkyTheme(
                baseColors = listOf(
                    Color(0xFFE0F2FE),
                    Color(0xFF7DD3FC),
                    Color(0xFF38BDF8),
                ),
                glowColor = Color(0xFF38BDF8),
                glowBaseAlpha = 0.2f,
            )
            ASR -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF93C5FD),
                    Color(0xFFFDE68A),
                    Color(0xFFFDBA74),
                ),
                glowColor = Color(0xFFD6B38A),
            )
            MAGHRIB -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF6D3FA9),
                    Color(0xFFA855F7),
                    Color(0xFFF472B6),
                    Color(0xFFFB7185),
                ),
                glowColor = Color(0xFFF59E0B),
            )
            ISHA -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF000000),
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                ),
                glowColor = Color(0xFF0F172A),
                glowBaseAlpha = 0.4f,
            )
            TAHAJJUD -> SkyTheme(
                baseColors = listOf(
                    Color(0xFF000000),
                    Color(0xFF01030A),
                    Color(0xFF020617),
                ),
                glowColor = null,
            )
        }

    companion object {
        val homePrayerThemes = listOf(FAJR, SUNRISE, DHUHR, ASR, MAGHRIB, ISHA)
        val selectablePrayerThemes = homePrayerThemes
        val configurableGradientThemes = homePrayerThemes

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
