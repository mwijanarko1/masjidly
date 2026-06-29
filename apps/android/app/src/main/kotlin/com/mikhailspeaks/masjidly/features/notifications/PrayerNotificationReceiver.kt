package com.mikhailspeaks.masjidly.features.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class PrayerNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: return
        val categoryId = intent.getStringExtra(EXTRA_CATEGORY_ID)
            ?: PrayerNotificationContent.CategoryId.REMINDER

        val extras = buildMap {
            intent.getStringExtra(EXTRA_KIND)?.let { put(PrayerNotificationContent.UserInfoKey.KIND, it) }
            intent.getStringExtra(EXTRA_PRAYER)?.let { put(PrayerNotificationContent.UserInfoKey.PRAYER, it) }
            intent.getStringExtra(EXTRA_MOSQUE_SLUG)?.let { put(PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG, it) }
            intent.getStringExtra(EXTRA_ISO_DATE)?.let { put(PrayerNotificationContent.UserInfoKey.ISO_DATE, it) }
            if (intent.hasExtra(EXTRA_REMINDER_MINUTES)) {
                put(
                    PrayerNotificationContent.UserInfoKey.REMINDER_MINUTES,
                    intent.getIntExtra(EXTRA_REMINDER_MINUTES, 0).toString(),
                )
            }
        }

        PrayerNotificationPresenter.show(
            context = context,
            id = id,
            title = title,
            body = body,
            categoryId = categoryId,
            extras = extras,
        )
    }

    companion object {
        const val EXTRA_ID = "masjidly.extra.notification_id"
        const val EXTRA_TITLE = "masjidly.extra.notification_title"
        const val EXTRA_BODY = "masjidly.extra.notification_body"
        const val EXTRA_CATEGORY_ID = "masjidly.extra.notification_category"
        const val EXTRA_KIND = PrayerNotificationContent.UserInfoKey.KIND
        const val EXTRA_PRAYER = PrayerNotificationContent.UserInfoKey.PRAYER
        const val EXTRA_MOSQUE_SLUG = PrayerNotificationContent.UserInfoKey.MOSQUE_SLUG
        const val EXTRA_ISO_DATE = PrayerNotificationContent.UserInfoKey.ISO_DATE
        const val EXTRA_REMINDER_MINUTES = PrayerNotificationContent.UserInfoKey.REMINDER_MINUTES

        fun buildIntent(
            context: Context,
            id: String,
            title: String,
            body: String,
            categoryId: String,
            extras: Map<String, String>,
        ): Intent = Intent(context, PrayerNotificationReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_CATEGORY_ID, categoryId)
            extras.forEach { (key, value) ->
                when (key) {
                    EXTRA_KIND -> putExtra(EXTRA_KIND, value)
                    EXTRA_PRAYER -> putExtra(EXTRA_PRAYER, value)
                    EXTRA_MOSQUE_SLUG -> putExtra(EXTRA_MOSQUE_SLUG, value)
                    EXTRA_ISO_DATE -> putExtra(EXTRA_ISO_DATE, value)
                    EXTRA_REMINDER_MINUTES -> putExtra(EXTRA_REMINDER_MINUTES, value.toIntOrNull() ?: 0)
                }
            }
        }

        fun pendingIntent(context: Context, id: String, intent: Intent): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        fun scheduleExact(context: Context, fireAtMillis: Long, pendingIntent: PendingIntent) {
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || PrayerNotificationPermissions.canScheduleExactAlarms(context)) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMillis, pendingIntent)
                    return
                } catch (_: SecurityException) {
                    // Exact-alarm access can be revoked between checking and scheduling.
                }
            }
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMillis, pendingIntent)
        }

        fun cancel(context: Context, id: String) {
            val intent = Intent(context, PrayerNotificationReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }
}
