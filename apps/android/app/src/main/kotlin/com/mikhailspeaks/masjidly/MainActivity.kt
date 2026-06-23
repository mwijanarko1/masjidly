package com.mikhailspeaks.masjidly

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.mikhailspeaks.masjidly.data.ConvexConfig
import com.mikhailspeaks.masjidly.features.audio.AdhanSoundPreviewPlayer
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationContent
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.data.convex.ConvexHttpClient
import com.mikhailspeaks.masjidly.data.convex.ConvexPrayerRepository
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.home.HomeViewModelFactory
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)

        AdhanSoundPreviewPlayer.attach(applicationContext)
        handleAdhanNotificationIntent(intent)

        val settingsStore = SettingsStore(applicationContext)
        val diskCache = PrayerTimesDiskCache(applicationContext)
        val repository = ConvexPrayerRepository(ConvexHttpClient(ConvexConfig.deploymentUrl))
        val notificationScheduler = PrayerNotificationScheduler(applicationContext, repository, diskCache)
        val homeViewModelFactory = HomeViewModelFactory(
            applicationContext,
            repository,
            settingsStore,
            diskCache,
            notificationScheduler,
        )

        setContent {
            val homeViewModel: HomeViewModel = viewModel(factory = homeViewModelFactory)
            MasjidlyApp(
                homeViewModel = homeViewModel,
                settingsStore = settingsStore,
                viewModelFactory = homeViewModelFactory,
                notificationScheduler = notificationScheduler,
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAdhanNotificationIntent(intent)
    }

    private fun handleAdhanNotificationIntent(intent: Intent?) {
        if (intent == null) return
        val kind = intent.getStringExtra(PrayerNotificationContent.UserInfoKey.KIND) ?: return
        if (kind != PrayerNotificationContent.PayloadKind.ADHAN.wireValue) return
        AdhanSoundPreviewPlayer.toggle(this)
        intent.removeExtra(PrayerNotificationContent.UserInfoKey.KIND)
    }
}
