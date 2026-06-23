package com.mikhailspeaks.masjidly.features.home

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import com.mikhailspeaks.masjidly.features.settings.SettingsViewModel
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshotService

class HomeViewModelFactory(
    private val appContext: Context,
    private val repository: PrayerRepository,
    private val settings: SettingsStore,
    private val diskCache: PrayerTimesDiskCache,
    private val notificationScheduler: PrayerNotificationScheduler,
) : ViewModelProvider.Factory {
    private val widgetSnapshotService by lazy {
        WidgetPrayerSnapshotService(appContext, repository, settings, diskCache)
    }

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        when {
            modelClass.isAssignableFrom(HomeViewModel::class.java) ->
                return HomeViewModel(
                    repository,
                    settings,
                    diskCache,
                    notificationScheduler,
                    widgetSnapshotService,
                ) as T
            modelClass.isAssignableFrom(SettingsViewModel::class.java) ->
                return SettingsViewModel(repository, settings, diskCache, notificationScheduler) as T
        }
        throw IllegalArgumentException("Unknown ViewModel: ${modelClass.name}")
    }
}
