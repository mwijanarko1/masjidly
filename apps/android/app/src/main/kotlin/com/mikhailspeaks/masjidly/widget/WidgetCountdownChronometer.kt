package com.mikhailspeaks.masjidly.widget

import android.os.SystemClock
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.TextUnit
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.layout.fillMaxWidth
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme

/** Live countdown as `-MM:SS` (or `-H:MM:SS` when over an hour) via system [Chronometer]. */
@Composable
fun WidgetCountdownChronometer(
    targetEpochMillis: Long,
    appearance: ResolvedTheme,
    textSize: TextUnit,
    modifier: GlanceModifier = GlanceModifier,
    centered: Boolean = false,
) {
    val remainingMillis = (targetEpochMillis - System.currentTimeMillis()).coerceAtLeast(0L)
    val base = SystemClock.elapsedRealtime() + remainingMillis
    val textColor = appearance.textColor.toArgb()
    val context = LocalContext.current
    val layoutId = if (centered) {
        R.layout.widget_countdown_chronometer_centered
    } else {
        R.layout.widget_countdown_chronometer
    }
    val remoteViews = RemoteViews(context.packageName, layoutId).apply {
        setTextColor(R.id.widget_countdown_minus, textColor)
        setTextViewTextSize(
            R.id.widget_countdown_minus,
            TypedValue.COMPLEX_UNIT_SP,
            textSize.value,
        )
        setChronometerCountDown(R.id.widget_countdown, true)
        setChronometer(R.id.widget_countdown, base, null, remainingMillis > 0L)
        setTextColor(R.id.widget_countdown, textColor)
        setTextViewTextSize(
            R.id.widget_countdown,
            TypedValue.COMPLEX_UNIT_SP,
            textSize.value,
        )
    }
    AndroidRemoteViews(
        remoteViews = remoteViews,
        modifier = if (centered) modifier.fillMaxWidth() else modifier,
    )
}
