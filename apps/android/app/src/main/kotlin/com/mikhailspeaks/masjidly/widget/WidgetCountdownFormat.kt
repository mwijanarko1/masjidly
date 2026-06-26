package com.mikhailspeaks.masjidly.widget

import java.time.Instant
import java.util.Locale

/** Mirrors iOS `formatPaddedCountdown` (`-HH:MM:SS`). */
fun formatWidgetCountdown(totalSeconds: Int): String {
    val seconds = maxOf(0, totalSeconds)
    val hours = seconds / 3_600
    val minutes = (seconds % 3_600) / 60
    val secs = seconds % 60
    return String.format(Locale.ROOT, "-%02d:%02d:%02d", hours, minutes, secs)
}

data class WidgetCountdownDisplay(
    val showCountdown: Boolean,
    val remainingSeconds: Int,
    val targetEpochMillis: Long?,
    val primaryTimeText: String,
)

fun widgetCountdownDisplay(state: WidgetPrayerState, now: Instant): WidgetCountdownDisplay {
    val targetMillis = state.targetDateEpochMillis
    val remainingSeconds = targetMillis?.let {
        maxOf(0, ((it - now.toEpochMilli()) / 1000).toInt())
    } ?: 0
    val showCountdown = targetMillis != null && remainingSeconds > 0
    return WidgetCountdownDisplay(
        showCountdown = showCountdown,
        remainingSeconds = remainingSeconds,
        targetEpochMillis = targetMillis,
        primaryTimeText = if (showCountdown) {
            formatWidgetCountdown(remainingSeconds)
        } else {
            state.adhanTime
        },
    )
}

/** @deprecated Use [formatWidgetCountdown]. */
fun formatLargeWidgetCountdown(totalSeconds: Int): String = formatWidgetCountdown(totalSeconds)
