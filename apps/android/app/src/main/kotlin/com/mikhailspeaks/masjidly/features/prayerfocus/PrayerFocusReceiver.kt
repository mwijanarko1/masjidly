package com.mikhailspeaks.masjidly.features.prayerfocus

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Window boundary alarms, the notification Stop action, and system events that invalidate the plan
 * (reboot clears alarms; clock, zone, and exact-alarm grant changes move or enable them).
 */
class PrayerFocusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_STOP -> PrayerFocusController.stopCurrentWindow(context)
            ACTION_BOUNDARY,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            -> PrayerFocusController.reconcile(context)
        }
    }

    companion object {
        const val ACTION_BOUNDARY = "com.mikhailspeaks.masjidly.prayerfocus.BOUNDARY"
        const val ACTION_STOP = "com.mikhailspeaks.masjidly.prayerfocus.STOP"
    }
}
