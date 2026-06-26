package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import kotlinx.serialization.Serializable
import kotlin.math.pow

@Serializable
data class CustomSkyGradientColors(
    val topHex: String,
    val bottomHex: String,
) {
    val topColor: Color get() = Color.fromHex(topHex)
    val bottomColor: Color get() = Color.fromHex(bottomHex)

    companion object {
        fun defaultsFor(theme: TimeTheme): CustomSkyGradientColors {
            val sky = theme.sky(theme.defaultGradientSet())
            return CustomSkyGradientColors(
                topHex = sky.top.toHexString(),
                bottomHex = sky.bottom.toHexString(),
            )
        }
    }
}

fun Color.toHexString(): String = String.format("%06X", 0xFFFFFF and toArgb())

fun Color.Companion.fromHex(hex: String): Color {
    val cleaned = hex.trim().removePrefix("#").uppercase()
    val value = cleaned.toLongOrNull(16) ?: 0L
    return Color(0xFF000000L or value)
}

fun textColorForCustomGradient(top: Color, bottom: Color): Color {
    val luminance = (top.relativeLuminance() + bottom.relativeLuminance()) / 2f
    return if (luminance < 0.45f) Color.White else Color(0xFF111111)
}

private fun Color.relativeLuminance(): Float {
    fun channel(value: Float): Float =
        if (value <= 0.03928f) value / 12.92f else ((value + 0.055f) / 1.055f).pow(2.4f)

    return 0.2126f * channel(red) + 0.7152f * channel(green) + 0.0722f * channel(blue)
}
