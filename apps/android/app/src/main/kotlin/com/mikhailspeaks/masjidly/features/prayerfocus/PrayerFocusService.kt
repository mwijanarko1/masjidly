package com.mikhailspeaks.masjidly.features.prayerfocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.mikhailspeaks.masjidly.MainActivity
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationContent
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Runs only while a Prayer Focus window is active. Polls UsageStats for the visible app while the
 * screen is on and covers selected apps with [PrayerFocusOverlay]. Uses the `specialUse` type: no
 * other foreground service type describes user-requested app blocking during a time window.
 */
class PrayerFocusService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val tracker = ForegroundAppTracker()
    private val seenEvents = LinkedHashSet<ForegroundAppTracker.Event>()
    private lateinit var overlay: PrayerFocusOverlay
    private lateinit var settingsStore: SettingsStore

    private var window: PrayerFocusWindow? = null
    private var selected: Set<String> = emptySet()
    private var excluded: Set<String> = emptySet()
    private var launchers: Set<String> = emptySet()
    private var lastQueryMillis = 0L
    private var polling = false
    /** Lets the launcher's resume event land after "Close app" before covering again. */
    private var holdOverlayUntilMillis = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            tick()
            if (polling) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // Handler delays pause during deep sleep; the boundary alarm is what guarantees expiry then.
    private val expiryRunnable = Runnable { PrayerFocusController.reconcile(this) }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    stopPolling()
                    overlay.hide()
                }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> startPolling()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        settingsStore = SettingsStore(applicationContext)
        // Post so the overlay is never removed from inside its own click dispatch.
        overlay = PrayerFocusOverlay(
            context = this,
            onCloseApp = { handler.post(::goHome) },
            onPrayed = {
                handler.post {
                    // Drop the overlay now; the service then stops once Stop reconciles.
                    stopPolling()
                    overlay.hide()
                    PrayerFocusController.stopCurrentWindow(this)
                }
            },
        )
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        ContextCompat.registerReceiver(this, screenReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val active = PrayerFocusScheduleBuilder.activeWindow(
            PrayerFocusStateStore(this).windows,
            System.currentTimeMillis(),
        )
        // startForegroundService() requires startForeground() even when there is nothing to do.
        startForegroundCompat(buildNotification(active))
        if (active == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (active != window) {
            seenEvents.clear()
            tracker.reset()
            // Look back so an app already open when the window starts is covered.
            lastQueryMillis = System.currentTimeMillis() - BOOTSTRAP_LOOKBACK_MS
        }
        window = active
        val settings = settingsStore.prayerFocus
        excluded = PrayerFocusApps.excludedPackages(this)
        launchers = PrayerFocusApps.launcherPackages(this)
        selected = settings.selectedPackages - excluded

        handler.removeCallbacks(expiryRunnable)
        handler.postDelayed(expiryRunnable, (active.endEpochMillis - System.currentTimeMillis()).coerceAtLeast(0L))
        val power = getSystemService(PowerManager::class.java)
        if (power?.isInteractive != false) startPolling()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        stopPolling()
        handler.removeCallbacks(expiryRunnable)
        overlay.hide()
        runCatching { unregisterReceiver(screenReceiver) }
        super.onDestroy()
    }

    private fun startPolling() {
        if (polling) return
        polling = true
        handler.post(pollRunnable)
    }

    private fun stopPolling() {
        polling = false
        handler.removeCallbacks(pollRunnable)
    }

    private fun tick() {
        val active = window
        val now = System.currentTimeMillis()
        if (active == null || now >= active.endEpochMillis) {
            overlay.hide()
            stopPolling()
            PrayerFocusController.reconcile(this)
            return
        }
        if (!PrayerFocusPermissions.hasUsageAccess(this) || !PrayerFocusPermissions.canDrawOverlays(this)) {
            // A revoked grant ends enforcement; status then shows what is missing.
            overlay.hide()
            stopPolling()
            PrayerFocusController.reconcile(this)
            return
        }
        tracker.apply(readEvents(now), launchers)
        if (now >= holdOverlayUntilMillis && tracker.shouldCover(selected, excluded)) {
            overlay.show(overlayContent(active))
        } else {
            overlay.hide()
        }
    }

    /** Re-reads a short overlap because usage events can be recorded slightly after they happen. */
    private fun readEvents(now: Long): List<ForegroundAppTracker.Event> {
        val usm = getSystemService(UsageStatsManager::class.java) ?: return emptyList()
        val begin = lastQueryMillis - EVENT_OVERLAP_MS
        val usageEvents = runCatching { usm.queryEvents(begin, now) }.getOrNull() ?: return emptyList()
        lastQueryMillis = now
        seenEvents.removeAll { it.timeMillis < begin }

        val result = mutableListOf<ForegroundAppTracker.Event>()
        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val kind = kindOf(event.eventType) ?: continue
            val mapped = ForegroundAppTracker.Event(kind, event.packageName, event.className, event.timeStamp)
            if (seenEvents.add(mapped)) result += mapped
        }
        return result
    }

    private fun kindOf(type: Int): ForegroundAppTracker.Kind? = when (type) {
        UsageEvents.Event.ACTIVITY_RESUMED -> ForegroundAppTracker.Kind.RESUMED
        UsageEvents.Event.ACTIVITY_PAUSED -> ForegroundAppTracker.Kind.PAUSED
        UsageEvents.Event.ACTIVITY_STOPPED -> ForegroundAppTracker.Kind.STOPPED
        UsageEvents.Event.KEYGUARD_SHOWN -> ForegroundAppTracker.Kind.KEYGUARD_SHOWN
        else -> null
    }

    private fun goHome() {
        holdOverlayUntilMillis = System.currentTimeMillis() + CLOSE_APP_HOLD_MS
        overlay.hide()
        val home = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(home) }
    }

    private fun overlayContent(active: PrayerFocusWindow): PrayerFocusOverlayContent {
        val language = settingsStore.appLanguage
        val prayerName = PrayerNotificationContent.prayerDisplayName(active.prayer.wireValue, active.isFriday, language)
        return PrayerFocusOverlayContent(
            title = LocaleStrings.format("prayer_focus.overlay.title_format", language, prayerName),
            message = LocaleStrings.format("prayer_focus.overlay.message_format", language, prayerName),
            endsAt = LocaleStrings.format("prayer_focus.overlay.ends_format", language, formatClock(active.endEpochMillis)),
            okLabel = LocaleStrings.t("prayer_focus.overlay.ok", language),
            prayedLabel = LocaleStrings.t("prayer_focus.overlay.prayed", language),
            theme = settingsStore.resolvedAppearanceFor(TimeTheme.fromWire(active.prayer.wireValue)),
            locale = settingsStore.resolvedLocale(),
            isRightToLeft = language.isRightToLeft,
        )
    }

    private fun formatClock(epochMillis: Long): String =
        formatPrayerFocusClock(epochMillis, settingsStore.uses24HourTime, settingsStore.resolvedLocale())

    private fun buildNotification(active: PrayerFocusWindow?): Notification {
        val language = settingsStore.appLanguage
        ensureChannel(this, LocaleStrings.t("settings.prayer_focus.title", language))
        val title = if (active != null) {
            val prayerName = PrayerNotificationContent.prayerDisplayName(active.prayer.wireValue, active.isFriday, language)
            LocaleStrings.format("prayer_focus.overlay.title_format", language, prayerName)
        } else {
            LocaleStrings.t("settings.prayer_focus.title", language)
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getBroadcast(
            this,
            0,
            Intent(this, PrayerFocusReceiver::class.java).setAction(PrayerFocusReceiver.ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .apply {
                if (active != null) {
                    setContentText(
                        LocaleStrings.format("prayer_focus.notification.body_format", language, formatClock(active.endEpochMillis)),
                    )
                }
            }
            .setContentIntent(openApp)
            .addAction(0, LocaleStrings.t("prayer_focus.notification.stop", language), stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    companion object {
        const val ACTION_REFRESH = "com.mikhailspeaks.masjidly.prayerfocus.REFRESH"
        private const val CHANNEL_ID = "prayer-focus"
        private const val NOTIFICATION_ID = 0x5046

        /** Starting point for device measurement of detection delay against battery cost. */
        private const val POLL_INTERVAL_MS = 1_000L
        private const val EVENT_OVERLAP_MS = 5_000L
        private const val CLOSE_APP_HOLD_MS = 1_500L
        private const val BOOTSTRAP_LOOKBACK_MS = 6 * 60 * 60 * 1_000L

        @Volatile
        var isRunning = false
            private set

        private fun ensureChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW),
            )
        }
    }
}

/** Formats an instant as a timetable clock in the app's 12/24-hour style and language. */
internal fun formatPrayerFocusClock(epochMillis: Long, uses24Hour: Boolean, locale: Locale): String {
    val hhmm = DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(Instant.ofEpochMilli(epochMillis))
    return PrayerTimesEngine.formatPrayerTimeForDisplay(hhmm, uses24Hour, locale)
}
