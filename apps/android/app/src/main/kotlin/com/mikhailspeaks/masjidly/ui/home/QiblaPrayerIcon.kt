package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import com.mikhailspeaks.masjidly.ui.haptic.hapticCombinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.ui.theme.MasjidlyFontFamily

private const val FRAME_REF = 120f

/** Mirrors iOS `QiblaPrayerIcon` — rings, sun-phase icon, optional Qibla pointer, hero countdown overlay. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun QiblaPrayerIcon(
    theme: ResolvedTheme,
    rotationDegrees: Float?,
    modifier: Modifier = Modifier,
    size: Dp = 120.dp,
    textColor: Color = theme.textColor,
    showCountdown: Boolean = false,
    countdownLabel: String = "",
    countdownTime: String = "",
    countdownProgress: Double = 0.0,
    onTap: (() -> Unit)? = null,
    onLongPress: (() -> Unit)? = null,
) {
    val scale = size.value / FRAME_REF
    val color = textColor
    val outerRingOpacity by animateFloatAsState(
        targetValue = if (showCountdown) 0.42f else 0.24f,
        animationSpec = tween(220),
        label = "outerRingOpacity",
    )
    val centerIconAlpha by animateFloatAsState(
        targetValue = if (showCountdown) 0f else 1f,
        animationSpec = tween(220),
        label = "centerIconAlpha",
    )
    val countdownAlpha by animateFloatAsState(
        targetValue = if (showCountdown) 1f else 0f,
        animationSpec = tween(220),
        label = "countdownAlpha",
    )
    val sunPhaseOffsetY = sunPhaseContentOffsetY(theme, scale)

    val gestureModifier = if (onTap != null || onLongPress != null) {
        Modifier.hapticCombinedClickable(
            onClick = { onTap?.invoke() },
            onLongClick = { onLongPress?.invoke() },
        )
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .size(size)
            .then(gestureModifier)
            .semantics {
                contentDescription = if (showCountdown) {
                    "$countdownLabel $countdownTime"
                } else {
                    "Qibla direction"
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeScale = scale * density
            val outerDiam = 112f * scale * density
            val innerDiam = 106f * scale * density
            val cx = this.size.width / 2f
            val cy = this.size.height / 2f

            if (showCountdown) {
                val progress = countdownProgress.coerceIn(0.0, 1.0).toFloat()
                drawArc(
                    color = color.copy(alpha = 0.38f),
                    startAngle = -90f,
                    sweepAngle = 360f * progress,
                    useCenter = false,
                    topLeft = Offset(cx - outerDiam / 2f, cy - outerDiam / 2f),
                    size = androidx.compose.ui.geometry.Size(outerDiam, outerDiam),
                    style = Stroke(width = 2f * strokeScale, cap = StrokeCap.Round),
                )
            }

            drawCircle(
                color = color.copy(alpha = outerRingOpacity),
                radius = outerDiam / 2f,
                center = Offset(cx, cy),
                style = Stroke(width = if (showCountdown) 1.15f * strokeScale else 1f * strokeScale),
            )
            drawCircle(
                color = color.copy(alpha = 0.08f),
                radius = innerDiam / 2f,
                center = Offset(cx, cy),
                style = Stroke(width = 0.8f * strokeScale),
            )

        }

        if (rotationDegrees != null) {
            Canvas(modifier = Modifier.size(size + (24.dp * scale))) {
                val strokeScale = scale * density
                val cx = this.size.width / 2f
                val cy = this.size.height / 2f
                rotate(rotationDegrees) {
                    val triSize = 12f * strokeScale
                    // Keep the iOS outside-the-ring pointer visible; the main 120dp canvas clips overflow.
                    val tipY = cy - (FRAME_REF / 2f + 10f) * scale * density
                    val path = Path().apply {
                        moveTo(cx, tipY)
                        lineTo(cx + triSize / 2f, tipY + triSize)
                        lineTo(cx - triSize / 2f, tipY + triSize)
                        close()
                    }
                    drawPath(path, color = color.copy(alpha = if (showCountdown) 0.92f else 1f))
                }
            }
        }

        PrayerSunPhaseIcon(
            theme = theme,
            modifier = Modifier
                .scale(scale)
                .offset(y = sunPhaseOffsetY.dp)
                .alpha(centerIconAlpha),
        )

        Column(
            modifier = Modifier
                .width(78.dp * scale)
                .offset(y = if (showCountdown) 0.dp else (3f * scale).dp)
                .alpha(countdownAlpha),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = countdownLabel.uppercase(),
                color = color.copy(alpha = 0.52f),
                fontSize = (9f * scale).sp,
                fontFamily = MasjidlyFontFamily.GillSans,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.4.sp,
                maxLines = 1,
                textAlign = TextAlign.Center,
            )
            Text(
                text = countdownTime,
                color = color.copy(alpha = 0.92f),
                fontSize = (20f * scale).sp,
                fontFamily = MasjidlyFontFamily.GillSans,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                textAlign = TextAlign.Center,
            )
        }
    }
}

private fun sunPhaseContentOffsetY(theme: ResolvedTheme, scale: Float): Float {
    val baseY = -6f
    val down5 = FRAME_REF * 0.05f
    return when (theme.timeTheme) {
        TimeTheme.FAJR, TimeTheme.DHUHR, TimeTheme.ASR, TimeTheme.ISHA ->
            (baseY + down5) * scale
        TimeTheme.SUNRISE, TimeTheme.MAGHRIB, TimeTheme.TAHAJJUD ->
            baseY * scale
    }
}

fun heroCountdownLabel(
    kind: com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind,
    language: com.mikhailspeaks.masjidly.domain.AppLanguage,
): String = when (kind) {
    com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind.ADHAN_IN ->
        com.mikhailspeaks.masjidly.domain.LocaleStrings.t("home.countdown.adhan_in", language)
    com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind.IQAMAH_IN ->
        com.mikhailspeaks.masjidly.domain.LocaleStrings.t("home.countdown.iqamah_in", language)
    com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind.NEXT_PRAYER ->
        com.mikhailspeaks.masjidly.domain.LocaleStrings.t("home.countdown.next_prayer", language)
}
