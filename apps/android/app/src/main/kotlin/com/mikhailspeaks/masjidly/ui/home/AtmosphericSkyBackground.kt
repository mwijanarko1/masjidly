package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.colorspace.ColorSpaces
import androidx.compose.ui.util.lerp as lerpFloat

/** Mirrors iOS `.animation(.easeInOut(duration: 0.8), value: selectedPrayerIndex)` on the home sky. */
private const val SKY_ANIMATION_MS = 800
private const val GRADIENT_STOP_COUNT = 4

private val skyFloatSpec = tween<Float>(durationMillis = SKY_ANIMATION_MS, easing = FastOutSlowInEasing)

/** Animated home theme values kept in sync when the prayer theme changes. */
data class HomeThemeAnimation(
    val textColor: Color,
    val skyColors: List<Color>,
    val glowColor: Color,
    val glowAlpha: Float,
)

/**
 * Drives sky, glow, and text-color transitions with one shared progress value so gradient
 * stops stay aligned. Oklab interpolation keeps dark Fajr/Isha skies smooth; text color
 * snaps at the midpoint when light/dark foreground flips (Fajr↔Sunrise, Maghrib↔Isha).
 */
@Composable
fun rememberHomeThemeAnimation(theme: ResolvedTheme): HomeThemeAnimation {
    var fromTheme by remember { mutableStateOf(theme) }
    var toTheme by remember { mutableStateOf(theme) }
    val progress = remember { Animatable(1f) }

    LaunchedEffect(theme) {
        if (theme == toTheme) return@LaunchedEffect
        fromTheme = toTheme
        toTheme = theme
        progress.snapTo(0f)
        progress.animateTo(1f, skyFloatSpec)
    }

    return blendThemes(fromTheme, toTheme, progress.value)
}

/** @see rememberHomeThemeAnimation */
@Composable
fun rememberAnimatedHomeTextColor(theme: ResolvedTheme): Color =
    rememberHomeThemeAnimation(theme).textColor

/**
 * Multi-layer atmospheric background matching iOS `AtmosphericSkyBackground`,
 * with smooth gradient and glow interpolation when the prayer theme changes.
 */
@Composable
fun AtmosphericSkyBackground(
    animation: HomeThemeAnimation,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(animation.skyColors)),
        )
        if (animation.glowAlpha > 0f) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val center = androidx.compose.ui.geometry.Offset(size.width * 0.5f, size.height * 0.82f)
                val maxRadius = size.width * 0.7f
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            animation.glowColor.copy(alpha = 0.6f * animation.glowAlpha),
                            animation.glowColor.copy(alpha = 0.3f * animation.glowAlpha),
                            Color.Transparent,
                        ),
                        center = center,
                        radius = maxRadius,
                    ),
                    radius = maxRadius,
                    center = center,
                    blendMode = BlendMode.Screen,
                )
            }
        }
    }
}

private fun blendThemes(from: ResolvedTheme, to: ResolvedTheme, fraction: Float): HomeThemeAnimation {
    val t = fraction.coerceIn(0f, 1f)
    val fromStops = gradientStops(from.sky.baseColors, GRADIENT_STOP_COUNT)
    val toStops = gradientStops(to.sky.baseColors, GRADIENT_STOP_COUNT)
    val skyColors = fromStops.zip(toStops) { start, end -> lerpInOklab(start, end, t) }

    val fromGlow = from.sky.glowColor
    val toGlow = to.sky.glowColor
    val fromGlowAlpha = if (fromGlow != null) from.sky.glowBaseAlpha else 0f
    val toGlowAlpha = if (toGlow != null) to.sky.glowBaseAlpha else 0f
    val glowAlpha = lerpFloat(fromGlowAlpha, toGlowAlpha, t)
    val glowColor = when {
        fromGlow != null && toGlow != null -> lerpInOklab(fromGlow, toGlow, t)
        fromGlow != null -> fromGlow
        toGlow != null -> toGlow
        else -> Color.Transparent
    }

    val textColor = if (from.usesLightForeground != to.usesLightForeground) {
        if (t >= 0.5f) to.textColor else from.textColor
    } else {
        lerpInOklab(from.textColor, to.textColor, t)
    }

    return HomeThemeAnimation(
        textColor = textColor,
        skyColors = skyColors,
        glowColor = glowColor,
        glowAlpha = glowAlpha,
    )
}

/** Samples [colors] at evenly spaced fractions so 2- and 4-stop gradients interpolate cleanly. */
private fun gradientStops(colors: List<Color>, stopCount: Int): List<Color> {
    if (colors.isEmpty()) return List(stopCount) { Color.Black }
    if (stopCount <= 1) return listOf(colors.first())
    return (0 until stopCount).map { index ->
        val fraction = index.toFloat() / (stopCount - 1).toFloat()
        sampleGradient(colors, fraction)
    }
}

private fun sampleGradient(colors: List<Color>, fraction: Float): Color {
    if (colors.size == 1) return colors.first()
    val clamped = fraction.coerceIn(0f, 1f)
    val scaled = clamped * (colors.size - 1)
    val startIndex = scaled.toInt().coerceIn(0, colors.size - 2)
    val localFraction = scaled - startIndex
    return lerpInOklab(colors[startIndex], colors[startIndex + 1], localFraction)
}

private fun lerpInOklab(start: Color, stop: Color, fraction: Float): Color {
    val startOklab = start.convert(ColorSpaces.Oklab)
    val stopOklab = stop.convert(ColorSpaces.Oklab)
    return Color(
        red = lerpFloat(startOklab.red, stopOklab.red, fraction),
        green = lerpFloat(startOklab.green, stopOklab.green, fraction),
        blue = lerpFloat(startOklab.blue, stopOklab.blue, fraction),
        alpha = lerpFloat(startOklab.alpha, stopOklab.alpha, fraction),
        colorSpace = ColorSpaces.Oklab,
    ).convert(ColorSpaces.Srgb)
}
