package com.mikhailspeaks.masjidly.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.R
import java.util.Locale

/**
 * Mirrors iOS `HomeDesign.Typography` — Gill Sans is Masjidly's primary voice.
 */
object MasjidlyFontFamily {
    val GillSans = FontFamily(
        Font(R.font.gill_sans_light, FontWeight.Light),
        Font(R.font.gill_sans_regular, FontWeight.Normal),
        Font(R.font.gill_sans_regular, FontWeight.Medium),
        Font(R.font.gill_sans_semibold, FontWeight.SemiBold),
        Font(R.font.gill_sans_bold, FontWeight.Bold),
    )
}

/** Mirrors iOS `Environment(\.locale)` scaling in `AppFontModifier`. */
val LocalMasjidlyLocale = staticCompositionLocalOf { Locale.getDefault() }

fun localeFontScale(locale: Locale): Float = when (locale.language) {
    "ur" -> 1.25f
    "ar" -> 1.20f
    else -> 1f
}

fun appFontSize(baseSp: Float, locale: Locale): TextUnit =
    (baseSp * localeFontScale(locale)).sp

fun appTextStyle(
    sizeSp: Float,
    weight: FontWeight = FontWeight.Normal,
    locale: Locale,
    tabularDigits: Boolean = false,
): TextStyle = TextStyle(
    fontFamily = MasjidlyFontFamily.GillSans,
    fontWeight = weight,
    fontSize = appFontSize(sizeSp, locale),
    fontFeatureSettings = if (tabularDigits) "tnum" else null,
)

@Composable
fun rememberAppTextStyle(
    sizeSp: Float,
    weight: FontWeight = FontWeight.Normal,
    tabularDigits: Boolean = false,
): TextStyle {
    val locale = LocalMasjidlyLocale.current
    return appTextStyle(sizeSp, weight, locale, tabularDigits)
}
