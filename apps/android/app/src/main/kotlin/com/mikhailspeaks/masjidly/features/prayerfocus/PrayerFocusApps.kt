package com.mikhailspeaks.masjidly.features.prayerfocus

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager

data class PrayerFocusAppOption(val packageName: String, val label: String)

/**
 * Launchable apps the person may choose to cover. Visibility comes from the scoped `<queries>`
 * intents in the manifest (launcher, home, settings, dial); no `QUERY_ALL_PACKAGES`.
 */
object PrayerFocusApps {
    /** Surfaces that must stay reachable so the feature can always be stopped or revoked. */
    private val alwaysExcluded = setOf(
        "com.android.settings",
        "com.android.systemui",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.emergency",
        "com.google.android.dialer",
        "com.samsung.android.dialer",
        "com.android.dialer",
    )

    fun launchableApps(context: Context): List<PrayerFocusAppOption> {
        val pm = context.packageManager
        val excluded = excludedPackages(context)
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return queryActivities(pm, launcherIntent)
            .asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filterNot { it in excluded }
            .map { pkg ->
                val label = runCatching {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                }.getOrDefault(pkg)
                PrayerFocusAppOption(pkg, label)
            }
            .sortedBy { it.label.lowercase() }
            .toList()
    }

    /** Masjidly, launchers, Settings, dialers, and permission surfaces are never covered. */
    fun excludedPackages(context: Context): Set<String> {
        val pm = context.packageManager
        val result = alwaysExcluded.toMutableSet()
        result += context.packageName
        result += launcherPackages(context)
        result += queryActivities(pm, Intent(Settings.ACTION_SETTINGS)).map { it.activityInfo.packageName }
        result += queryActivities(pm, Intent(Intent.ACTION_DIAL)).map { it.activityInfo.packageName }
        runCatching {
            context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        }.getOrNull()?.let { result += it }
        return result
    }

    fun launcherPackages(context: Context): Set<String> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return queryActivities(context.packageManager, home).mapTo(mutableSetOf()) { it.activityInfo.packageName }
    }

    private fun queryActivities(pm: PackageManager, intent: Intent): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
}
