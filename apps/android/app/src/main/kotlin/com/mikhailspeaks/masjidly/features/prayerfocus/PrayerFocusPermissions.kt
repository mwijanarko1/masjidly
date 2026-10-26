package com.mikhailspeaks.masjidly.features.prayerfocus

import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationPermissions

/** Runtime grants Prayer Focus depends on. Manifest declarations alone are never trusted. */
object PrayerFocusPermissions {
    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java) ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun canDrawOverlays(context: Context): Boolean = Settings.canDrawOverlays(context)

    /** An exact alarm is what lets the monitoring service start on time from the background. */
    fun canScheduleExactAlarms(context: Context): Boolean =
        PrayerNotificationPermissions.canScheduleExactAlarms(context)

    fun hasNotificationPermission(context: Context): Boolean =
        PrayerNotificationPermissions.hasPostNotificationsPermission(context)

    fun openUsageAccessSettings(context: Context) {
        // Some OEM builds reject the package URI; fall back to the full list.
        val withPackage = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, packageUri(context))
        if (!start(context, withPackage)) start(context, Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    fun openOverlaySettings(context: Context) {
        // Android 11+ ignores the package URI on the public action and opens the top-level list, so
        // try the app's own overlay page first. Some OEM builds don't export it; fall back below.
        val direct = Intent().setClassName(SETTINGS_PACKAGE, OVERLAY_SETTINGS_ACTIVITY).setData(packageUri(context))
        if (start(context, direct)) return
        val withPackage = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri(context))
        if (!start(context, withPackage)) start(context, Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
    }

    fun openExactAlarmSettings(context: Context) {
        PrayerNotificationPermissions.openExactAlarmSettings(context)
    }

    fun openNotificationSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri(context))
        }
        start(context, intent)
    }

    private const val SETTINGS_PACKAGE = "com.android.settings"
    private const val OVERLAY_SETTINGS_ACTIVITY = "com.android.settings.Settings\$AppDrawOverlaySettingsActivity"

    private fun packageUri(context: Context): Uri = Uri.parse("package:${context.packageName}")

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
