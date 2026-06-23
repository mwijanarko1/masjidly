package com.mikhailspeaks.masjidly.features.settings

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationContent
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationPresenter
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import kotlinx.coroutines.launch

/** Android counterpart to iOS `SettingsViewModel.swift`. */
class SettingsViewModel(
    private val repository: PrayerRepository,
    private val settings: SettingsStore,
    private val diskCache: PrayerTimesDiskCache,
    private val notificationScheduler: PrayerNotificationScheduler,
) : ViewModel() {
    var supportsMultipleAsrAdhan by mutableStateOf(false)
        private set

    var mosques: List<Mosque> = emptyList()
        private set

    init {
        refreshAsrAdhanSupport()
    }

    fun refreshAsrAdhanSupport() {
        viewModelScope.launch {
            val slug = settings.selectedMosqueSlug
                ?: settings.selectedMosqueId?.let { id ->
                    diskCache.loadMosques()?.firstOrNull { it.id == id }?.slug
                }
                ?: return@launch

            val parts = PrayerTimesEngine.getDateInSheffield(java.time.Instant.now())
            val month = MonthName.from(parts.month) ?: return@launch

            supportsMultipleAsrAdhan = try {
                val monthly = repository.getMonthlyPrayerTimes(slug, month, parts.year)
                if (monthly != null) {
                    diskCache.saveMonthly(slug, month.rawValue, parts.year, monthly)
                }
                val resolved = monthly ?: diskCache.loadMonthly(slug, month.rawValue, parts.year)
                resolved?.prayerTimes?.any { !it.asrMithl2.isNullOrEmpty() } == true
            } catch (_: Exception) {
                val cached = diskCache.loadMonthly(slug, month.rawValue, parts.year)
                cached?.prayerTimes?.any { !it.asrMithl2.isNullOrEmpty() } == true
            }
        }
    }

    fun updateMosques(list: List<Mosque>) {
        mosques = list
    }

    fun onNotificationsChanged() {
        viewModelScope.launch { applyNotificationPolicy() }
    }

    fun fireTestNotification(context: Context, type: TestNotificationType) {
        viewModelScope.launch {
            if (!notificationScheduler.requestAuthorizationIfNeeded()) return@launch
            val language = settings.appLanguage
            val slug = settings.selectedMosqueSlug.orEmpty()
            when (type) {
                TestNotificationType.ADHAN -> {
                    val copy = PrayerNotificationContent.adhanCopy("maghrib", isFriday = false, language)
                    PrayerNotificationPresenter.showInstantTest(
                        context = context,
                        title = copy.first,
                        body = copy.second,
                        categoryId = PrayerNotificationContent.CategoryId.ADHAN,
                        extras = PrayerNotificationContent.debugUserInfo(
                            PrayerNotificationContent.PayloadKind.ADHAN,
                            "maghrib",
                            slug,
                        ),
                    )
                }
                TestNotificationType.IQAMAH -> {
                    val copy = PrayerNotificationContent.iqamahCopy("maghrib", isFriday = false, language)
                    PrayerNotificationPresenter.showInstantTest(
                        context = context,
                        title = copy.first,
                        body = copy.second,
                        categoryId = PrayerNotificationContent.CategoryId.IQAMAH,
                        extras = PrayerNotificationContent.debugUserInfo(
                            PrayerNotificationContent.PayloadKind.IQAMAH,
                            "maghrib",
                            slug,
                        ),
                    )
                }
                TestNotificationType.REMINDER -> {
                    val copy = PrayerNotificationContent.beforeAdhanReminderCopy(
                        "maghrib",
                        isFriday = false,
                        minutes = 10,
                        language,
                    )
                    PrayerNotificationPresenter.showInstantTest(
                        context = context,
                        title = copy.first,
                        body = copy.second,
                        categoryId = PrayerNotificationContent.CategoryId.REMINDER,
                        extras = PrayerNotificationContent.debugUserInfo(
                            PrayerNotificationContent.PayloadKind.REMINDER_BEFORE_ADHAN,
                            "maghrib",
                            slug,
                        ),
                    )
                }
                TestNotificationType.ALL -> {
                    fireTestNotification(context, TestNotificationType.ADHAN)
                    fireTestNotification(context, TestNotificationType.IQAMAH)
                    fireTestNotification(context, TestNotificationType.REMINDER)
                }
            }
        }
    }

    private suspend fun applyNotificationPolicy() {
        val n = settings.notifications
        val mosque = settings.selectedMosqueSlug?.let { slug ->
            mosques.firstOrNull { it.slug == slug }
        } ?: settings.selectedMosqueId?.let { id ->
            mosques.firstOrNull { it.id == id }
        }
        if (n.masterEnabled && mosque != null) {
            notificationScheduler.rescheduleUpcomingPrayerNotifications(
                mosque = mosque,
                days = 7,
                settings = n,
                language = settings.appLanguage,
                asrIqamahPreference = settings.asrIqamahPreference,
            )
        } else {
            notificationScheduler.cancelAllPrayerNotifications()
        }
    }

    enum class TestNotificationType {
        ADHAN,
        IQAMAH,
        REMINDER,
        ALL,
    }
}
