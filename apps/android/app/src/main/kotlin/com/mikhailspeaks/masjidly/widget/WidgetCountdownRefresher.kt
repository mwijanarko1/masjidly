package com.mikhailspeaks.masjidly.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationPermissions
import java.time.Instant

/**
 * Per-second widget refreshes while the next prayer is within 2 hours (all widget sizes).
 */
object WidgetCountdownRefresher {
    const val ACTION_COUNTDOWN_TICK = "com.mikhailspeaks.masjidly.widget.COUNTDOWN_TICK"
    private const val REQUEST_CODE = 42_001
    private const val COUNTDOWN_WINDOW_SECONDS = 2 * 3_600
    /** Minute sync for headlines; Chronometer handles per-second display. */
    private const val SYNC_INTERVAL_MILLIS = 60_000L

    suspend fun rescheduleFromSnapshot(context: Context) {
        val appContext = context.applicationContext
        if (!hasAnyPrayerWidget(appContext)) {
            cancel(appContext)
            return
        }
        val snapshot = WidgetSnapshotStore(appContext).readSnapshot()
        val includeTomorrowFajr = !hasLargeWidget(appContext)
        val state = snapshot?.let {
            WidgetResolver.resolve(
                snapshot = it,
                now = Instant.now(),
                includeTomorrowFajr = includeTomorrowFajr,
            )
        }
        if (state != null) {
            scheduleIfNeeded(appContext, state)
        } else {
            cancel(appContext)
        }
    }

    fun scheduleIfNeeded(context: Context, state: WidgetPrayerState) {
        val appContext = context.applicationContext
        if (!hasAnyPrayerWidgetBlocking(appContext)) {
            cancel(appContext)
            return
        }

        val targetMillis = state.targetDateEpochMillis
        if (state.kind != WidgetStateKind.CONTENT || targetMillis == null) {
            cancel(appContext)
            return
        }

        val nowMillis = System.currentTimeMillis()
        val remainingSeconds = ((targetMillis - nowMillis) / 1000).toInt()
        if (remainingSeconds <= 0) {
            scheduleAlarm(appContext, nowMillis + 1_000L)
            return
        }

        val fireAtMillis = when {
            remainingSeconds <= 1 -> targetMillis
            remainingSeconds > COUNTDOWN_WINDOW_SECONDS -> targetMillis - COUNTDOWN_WINDOW_SECONDS * 1_000L
            else -> nowMillis + SYNC_INTERVAL_MILLIS
        }
        scheduleAlarm(appContext, fireAtMillis)
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(pendingIntent(context))
    }

    private fun scheduleAlarm(context: Context, fireAtMillis: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = pendingIntent(context)
        if (PrayerNotificationPermissions.canScheduleExactAlarms(context)) {
            runCatching {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pending,
                )
            }.onFailure {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pending,
                )
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAtMillis,
                pending,
            )
        } else {
            @Suppress("DEPRECATION")
            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMillis, pending)
        }
    }

    private suspend fun hasAnyPrayerWidget(context: Context): Boolean {
        val manager = GlanceAppWidgetManager(context)
        return listOf(
            MasjidlyPrayerSmallWidget::class.java,
            MasjidlyPrayerMediumWidget::class.java,
            MasjidlyPrayerLargeWidget::class.java,
        ).any { manager.getGlanceIds(it).isNotEmpty() }
    }

    private fun hasAnyPrayerWidgetBlocking(context: Context): Boolean {
        return runCatching {
            kotlinx.coroutines.runBlocking { hasAnyPrayerWidget(context) }
        }.getOrDefault(false)
    }

    private suspend fun hasLargeWidget(context: Context): Boolean {
        return GlanceAppWidgetManager(context)
            .getGlanceIds(MasjidlyPrayerLargeWidget::class.java)
            .isNotEmpty()
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetCountdownReceiver::class.java).apply {
            action = ACTION_COUNTDOWN_TICK
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
