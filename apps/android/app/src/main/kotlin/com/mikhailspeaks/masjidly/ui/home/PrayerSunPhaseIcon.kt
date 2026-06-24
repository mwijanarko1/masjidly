package com.mikhailspeaks.masjidly.ui.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

/** Mirrors iOS `PrayerSunPhaseIcon` — theme-specific sun/moon line art (100×88 ref canvas). */
@Composable
fun PrayerSunPhaseIcon(
    theme: ResolvedTheme,
    modifier: Modifier = Modifier,
) {
    val color = theme.textColor
    Canvas(
        modifier = modifier.size(width = 100.dp, height = 88.dp),
    ) {
        val thin = Stroke(width = 1.8f * density, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val medium = Stroke(width = 2.2f * density, cap = StrokeCap.Round, join = StrokeJoin.Round)
        val cx = size.width * 0.5f
        when (theme.timeTheme) {
            TimeTheme.FAJR -> drawFajr(cx, color, thin)
            TimeTheme.SUNRISE -> drawSunrise(cx, color, thin, medium)
            TimeTheme.DHUHR -> drawDhuhr(cx, color, thin, medium)
            TimeTheme.ASR -> drawAsr(cx, color, thin, medium)
            TimeTheme.MAGHRIB -> drawMaghrib(cx, color, thin, medium)
            TimeTheme.ISHA, TimeTheme.TAHAJJUD -> drawIsha(cx, color, thin, medium)
        }
    }
}

private fun DrawScope.fourPointStarPath(cx: Float, cy: Float, starSize: Float): Path {
    val c = starSize * 0.25f
    return Path().apply {
        moveTo(cx, cy - starSize)
        quadraticTo(cx + c, cy - c, cx + starSize, cy)
        quadraticTo(cx + c, cy + c, cx, cy + starSize)
        quadraticTo(cx - c, cy + c, cx - starSize, cy)
        quadraticTo(cx - c, cy - c, cx, cy - starSize)
        close()
    }
}

private fun DrawScope.drawFajr(cx: Float, color: Color, thin: Stroke) {
    val baseY = size.height * 0.61f
    val lineHalf = 16f * density
    drawLine(color, Offset(cx - lineHalf, baseY), Offset(cx + lineHalf, baseY), strokeWidth = thin.width, cap = StrokeCap.Round)
    drawPath(fourPointStarPath(cx, baseY - 14f * density, 6f * density), color, style = thin)
}

private fun DrawScope.drawSunrise(cx: Float, color: Color, thin: Stroke, medium: Stroke) {
    val baseY = size.height * 0.66f
    val r = 14f * density
    val lineHalf = 32f * density
    drawLine(color, Offset(cx - lineHalf, baseY), Offset(cx + lineHalf, baseY), strokeWidth = medium.width, cap = StrokeCap.Round)
    drawArc(
        color = color,
        startAngle = 180f,
        sweepAngle = 180f,
        useCenter = false,
        topLeft = Offset(cx - r, baseY - r),
        size = Size(r * 2, r * 2),
        style = medium,
    )
    val gap = 6f * density
    val rayLen = 8f * density
    for (deg in listOf(-135.0, -90.0, -45.0)) {
        val rad = Math.toRadians(deg)
        val startR = r + gap
        val endR = r + gap + rayLen
        val sx = cx + cos(rad).toFloat() * startR
        val sy = baseY + sin(rad).toFloat() * startR
        val ex = cx + cos(rad).toFloat() * endR
        val ey = baseY + sin(rad).toFloat() * endR
        drawLine(color, Offset(sx, sy), Offset(ex, ey), strokeWidth = medium.width, cap = StrokeCap.Round)
    }
}

private fun DrawScope.drawDhuhr(cx: Float, color: Color, thin: Stroke, medium: Stroke) {
    val cy = size.height * 0.50f
    val r = 12f * density
    drawCircle(color, radius = r, center = Offset(cx, cy), style = medium)
    val gap = 6f * density
    val len = 8f * density
    for (i in 0 until 8) {
        val angle = i * 45.0 * Math.PI / 180.0
        val startR = r + gap
        val endR = r + gap + len
        drawLine(
            color,
            Offset(cx + cos(angle).toFloat() * startR, cy + sin(angle).toFloat() * startR),
            Offset(cx + cos(angle).toFloat() * endR, cy + sin(angle).toFloat() * endR),
            strokeWidth = medium.width,
            cap = StrokeCap.Round,
        )
    }
}

private fun DrawScope.drawAsr(cx: Float, color: Color, thin: Stroke, medium: Stroke) {
    val cy = size.height * 0.45f
    val bodyH = 14f * density
    val top = cy - bodyH * 0.5f
    val bottom = cy + bodyH * 0.5f
    val startX = cx - 10f * density
    drawLine(color, Offset(startX, top), Offset(startX, bottom), strokeWidth = medium.width, cap = StrokeCap.Round)
    drawLine(
        color,
        Offset(startX, bottom),
        Offset(startX + 28f * density, bottom + 8f * density),
        strokeWidth = thin.width,
        cap = StrokeCap.Round,
    )
}

private fun DrawScope.drawMaghrib(cx: Float, color: Color, thin: Stroke, medium: Stroke) {
    val baseY = size.height * 0.65f
    val r = 14f * density
    val lineHalf = 32f * density
    drawLine(color, Offset(cx - lineHalf, baseY), Offset(cx + lineHalf, baseY), strokeWidth = medium.width, cap = StrokeCap.Round)
    drawArc(
        color = color,
        startAngle = 180f,
        sweepAngle = 180f,
        useCenter = false,
        topLeft = Offset(cx - r, baseY - r),
        size = Size(r * 2, r * 2),
        style = medium,
    )
    val arrowY = baseY - r - 4f * density
    drawLine(color, Offset(cx, arrowY - 8f * density), Offset(cx, arrowY), strokeWidth = thin.width, cap = StrokeCap.Round)
    drawLine(color, Offset(cx - 3f * density, arrowY - 3f * density), Offset(cx, arrowY), strokeWidth = thin.width, cap = StrokeCap.Round)
    drawLine(color, Offset(cx + 3f * density, arrowY - 3f * density), Offset(cx, arrowY), strokeWidth = thin.width, cap = StrokeCap.Round)
}

private fun DrawScope.drawIsha(cx: Float, color: Color, thin: Stroke, medium: Stroke) {
    val cy = size.height * 0.50f
    drawPath(fourPointStarPath(cx - 4f * density, cy, 8f * density), color, style = medium)
    drawPath(fourPointStarPath(cx + 12f * density, cy - 6f * density, 4f * density), color, style = thin)
    drawPath(fourPointStarPath(cx + 10f * density, cy + 8f * density, 3f * density), color, style = thin)
}
