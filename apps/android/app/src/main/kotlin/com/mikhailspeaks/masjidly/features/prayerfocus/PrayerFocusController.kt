package com.mikhailspeaks.masjidly.features.prayerfocus

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetSnapshotStore
import java.time.Instant
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Android counterpart to iOS `PrayerFocusController`: plans windows from the active mosque's
 * snapshot, keeps one exact alarm at the next boundary, and starts or stops the monitoring service.
 *
 * Enforcement is best effort. People can revoke permissions, force-stop Masjidly, or leave
 * the overlay; status never claims blocking when a prerequisite is missing.
 */
object PrayerFocusController {
    sealed interface Status {
        data object Off : Status
        data object NeedsUsageAccess : Status
        data object NeedsOverlay : Status
        data object NeedsExactAlarm : Status
        data object NeedsSelection : Status
        data object NoUpcomingTimes : Status
        data object Failed : Status
        data class Scheduled(val next: PrayerFocusWindow) : Status
        data class Active(val window: PrayerFocusWindow) : Status
    }

    private const val ALARM_REQUEST_CODE = 0x5046 // "PF"; distinct receiver from prayer notifications.

    fun status(context: Context, settings: PrayerFocusSettings, nowMillis: Long = System.currentTimeMillis()): Status {
        if (!settings.isEnabled) return Status.Off
        missingPrerequisite(context, settings)?.let { return it }
        val state = PrayerFocusStateStore(context)
        if (state.startFailed) return Status.Failed
        val windows = state.windows
        PrayerFocusScheduleBuilder.activeWindow(windows, nowMillis)?.let { return Status.Active(it) }
        val next = windows.firstOrNull { it.startEpochMillis > nowMillis } ?: return Status.NoUpcomingTimes
        return Status.Scheduled(next)
    }

    /**
     * Replaces the plan from the latest snapshot and reconciles the alarm and service.
     * Called on app resume, settings or timetable change, snapshot refresh, boot, time change,
     * every boundary alarm, and Stop. Cheap and idempotent.
     */
    @Synchronized
    fun reconcile(context: Context) {
        val appContext = context.applicationContext
        val settingsStore = SettingsStore(appContext)
        val settings = settingsStore.prayerFocus
        val state = PrayerFocusStateStore(appContext)
        val now = Instant.now()

        val planned = if (settings.isEnabled && missingPrerequisite(appContext, settings) == null) {
            currentSnapshot(appContext, settingsStore)?.let { snapshot ->
                PrayerFocusScheduleBuilder.windows(
                    snapshot = snapshot,
                    settings = settings,
                    now = now,
                    suppressedUntil = state.suppressedUntilMillis?.let(Instant::ofEpochMilli),
                )
            }.orEmpty()
        } else {
            emptyList()
        }
        state.windows = planned

        val nowMillis = now.toEpochMilli()
        scheduleBoundaryAlarm(appContext, PrayerFocusScheduleBuilder.nextBoundary(planned, nowMillis))

        if (PrayerFocusScheduleBuilder.activeWindow(planned, nowMillis) != null) {
            startMonitoring(appContext, state)
        } else {
            state.startFailed = false
            stopMonitoring(appContext)
        }
    }

    /** Ends only the current window; future prayers still pause apps (iOS parity). */
    fun stopCurrentWindow(context: Context) {
        val state = PrayerFocusStateStore(context)
        val active = PrayerFocusScheduleBuilder.activeWindow(state.windows, System.currentTimeMillis())
        if (active != null) state.suppressedUntilMillis = active.endEpochMillis
        reconcile(context)
    }

    /** All grants present and at least one app chosen; says nothing about upcoming times. */
    fun isReady(context: Context, settings: PrayerFocusSettings): Boolean =
        missingPrerequisite(context, settings) == null

    private fun missingPrerequisite(context: Context, settings: PrayerFocusSettings): Status? = when {
        !PrayerFocusPermissions.hasUsageAccess(context) -> Status.NeedsUsageAccess
        !PrayerFocusPermissions.canDrawOverlays(context) -> Status.NeedsOverlay
        !PrayerFocusPermissions.canScheduleExactAlarms(context) -> Status.NeedsExactAlarm
        settings.selectedPackages.isEmpty() -> Status.NeedsSelection
        else -> null
    }

    /** Only a snapshot for the current active mosque and Asr preference may drive blocking. */
    private fun currentSnapshot(context: Context, settings: SettingsStore): WidgetPrayerSnapshot? {
        val snapshot = WidgetSnapshotStore(context).readSnapshot() ?: return null
        val mosqueId = settings.selectedMosqueId
        if (mosqueId != null && mosqueId != snapshot.mosque.id) return null
        if ((snapshot.asrIqamahPreference ?: "first") != settings.asrIqamahPreference.wireValue) return null
        return snapshot
    }

    private fun startMonitoring(context: Context, state: PrayerFocusStateStore) {
        val intent = Intent(context, PrayerFocusService::class.java).setAction(PrayerFocusService.ACTION_REFRESH)
        try {
            if (PrayerFocusService.isRunning) {
                // Already foreground: a plain start just refreshes the window it enforces.
                context.startService(intent)
            } else {
                ContextCompat.startForegroundService(context, intent)
            }
            state.startFailed = false
        } catch (_: IllegalStateException) {
            // Includes ForegroundServiceStartNotAllowedException (Android 12+ background start limits).
            state.startFailed = true
        } catch (_: SecurityException) {
            state.startFailed = true
        }
    }

    /**
     * Asks the service to re-check rather than calling stopService(): a start that is still in flight
     * must reach startForeground() first, and the service then stops itself when no window is active.
     */
    private fun stopMonitoring(context: Context) {
        if (!PrayerFocusService.isRunning) return
        val intent = Intent(context, PrayerFocusService::class.java).setAction(PrayerFocusService.ACTION_REFRESH)
        try {
            context.startService(intent)
        } catch (_: IllegalStateException) {
            context.stopService(Intent(context, PrayerFocusService::class.java))
        }
    }

    private fun scheduleBoundaryAlarm(context: Context, atMillis: Long?) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            Intent(context, PrayerFocusReceiver::class.java).setAction(PrayerFocusReceiver.ACTION_BOUNDARY),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (atMillis == null) {
            alarmManager.cancel(pendingIntent)
            return
        }
        // Only exact alarms carry the documented exemption for starting a foreground service from
        // the background, so never fall back to an inexact alarm that would silently start late.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.cancel(pendingIntent)
            return
        }
        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pendingIntent)
        } catch (_: SecurityException) {
            alarmManager.cancel(pendingIntent)
        }
    }
}

/** Bounded scheduling state, separate from prayer notification alarm identifiers. */
internal class PrayerFocusStateStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    var windows: List<PrayerFocusWindow>
        get() = prefs.getString(KEY_WINDOWS, null)
            ?.let { runCatching { json.decodeFromString<List<PrayerFocusWindow>>(it) }.getOrNull() }
            .orEmpty()
        set(value) {
            prefs.edit().putString(KEY_WINDOWS, json.encodeToString(value)).apply()
        }

    var suppressedUntilMillis: Long?
        get() = prefs.getLong(KEY_SUPPRESSED_UNTIL, 0L).takeIf { it > 0L }
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_SUPPRESSED_UNTIL).apply()
            } else {
                prefs.edit().putLong(KEY_SUPPRESSED_UNTIL, value).apply()
            }
        }

    var startFailed: Boolean
        get() = prefs.getBoolean(KEY_START_FAILED, false)
        set(value) {
            prefs.edit().putBoolean(KEY_START_FAILED, value).apply()
        }

    companion object {
        private const val PREFS_NAME = "masjidly_prayer_focus"
        private const val KEY_WINDOWS = "windows.v1"
        private const val KEY_SUPPRESSED_UNTIL = "suppressedUntil.v1"
        private const val KEY_START_FAILED = "startFailed.v1"
    }
}
