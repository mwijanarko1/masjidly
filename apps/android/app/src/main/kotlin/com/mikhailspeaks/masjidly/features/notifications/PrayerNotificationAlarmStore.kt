package com.mikhailspeaks.masjidly.features.notifications

import android.content.Context

/** Tracks scheduled alarm identifiers so they can be cancelled on reschedule. */
internal class PrayerNotificationAlarmStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun scheduledIds(): Set<String> =
        prefs.getStringSet(KEY_IDS, emptySet()).orEmpty()

    fun replaceScheduledIds(ids: Collection<String>) {
        prefs.edit().putStringSet(KEY_IDS, ids.toSet()).apply()
    }

    fun clear() {
        prefs.edit().remove(KEY_IDS).apply()
    }

    companion object {
        private const val PREFS_NAME = "masjidly_prayer_notification_alarms"
        private const val KEY_IDS = "scheduled_ids"
    }
}
