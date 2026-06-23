package com.mikhailspeaks.masjidly.features.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mikhailspeaks.masjidly.data.ConvexConfig
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.data.convex.ConvexHttpClient
import com.mikhailspeaks.masjidly.data.convex.ConvexPrayerRepository
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Reschedules prayer notifications after device reboot — mirrors iOS resync on app launch. */
class PrayerNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val pending = goAsync()
        scope.launch {
            try {
                val appContext = context.applicationContext
                val settings = SettingsStore(appContext)
                val notifications = settings.notifications
                if (!notifications.masterEnabled) return@launch

                val diskCache = PrayerTimesDiskCache(appContext)
                val mosques = diskCache.loadMosques() ?: return@launch
                val mosque = MosqueSelection.resolveSelectedMosque(
                    mosques = mosques,
                    selectedId = settings.selectedMosqueId,
                    selectedSlug = settings.selectedMosqueSlug,
                ) ?: return@launch

                val scheduler = PrayerNotificationScheduler(
                    appContext,
                    ConvexPrayerRepository(ConvexHttpClient(ConvexConfig.deploymentUrl)),
                    diskCache,
                )
                scheduler.rescheduleUpcomingPrayerNotifications(
                    mosque = mosque,
                    days = 7,
                    settings = notifications,
                    language = settings.appLanguage,
                    asrIqamahPreference = settings.asrIqamahPreference,
                )
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    }
}
