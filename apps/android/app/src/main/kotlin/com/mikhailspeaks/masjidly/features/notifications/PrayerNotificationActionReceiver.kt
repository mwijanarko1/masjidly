package com.mikhailspeaks.masjidly.features.notifications

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.time.Instant
import java.time.temporal.ChronoUnit

class PrayerNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(PrayerNotificationReceiver.EXTRA_ID) ?: return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager?.cancel(id.hashCode())

        if (intent.action != ACTION_SNOOZE) return
        val title = intent.getStringExtra(PrayerNotificationReceiver.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(PrayerNotificationReceiver.EXTRA_BODY) ?: return
        val categoryId = intent.getStringExtra(PrayerNotificationReceiver.EXTRA_CATEGORY_ID)
            ?: PrayerNotificationContent.CategoryId.REMINDER
        val extras = buildMap {
            intent.getStringExtra(PrayerNotificationReceiver.EXTRA_KIND)?.let { put(PrayerNotificationContent.UserInfoKey.KIND, it) }
            intent.getStringExtra(PrayerNotificationReceiver.EXTRA_PRAYER)?.let { put(PrayerNotificationContent.UserInfoKey.PRAYER, it) }
            intent.getStringExtra(PrayerNotificationReceiver.EXTRA_MOSQUE_SLUG)?.let { put(PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG, it) }
            intent.getStringExtra(PrayerNotificationReceiver.EXTRA_ISO_DATE)?.let { put(PrayerNotificationContent.UserInfoKey.ISO_DATE, it) }
        }
        if (!PrayerNotificationPermissions.canScheduleExactAlarms(context)) return
        val snoozeId = "$id.snooze"
        val alarmIntent = PrayerNotificationReceiver.buildIntent(context, snoozeId, title, body, categoryId, extras)
        PrayerNotificationReceiver.scheduleExact(
            context,
            Instant.now().plus(10, ChronoUnit.MINUTES).toEpochMilli(),
            PrayerNotificationReceiver.pendingIntent(context, snoozeId, alarmIntent),
        )
    }

    companion object {
        const val ACTION_DISMISS = "com.mikhailspeaks.masjidly.notifications.DISMISS"
        const val ACTION_SNOOZE = "com.mikhailspeaks.masjidly.notifications.SNOOZE"

        fun pendingIntent(context: Context, id: String, action: String, source: Intent): PendingIntent {
            val intent = Intent(context, PrayerNotificationActionReceiver::class.java).apply {
                this.action = action
                source.extras?.let { putExtras(it) }
            }
            return PendingIntent.getBroadcast(
                context,
                "$id.$action".hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
