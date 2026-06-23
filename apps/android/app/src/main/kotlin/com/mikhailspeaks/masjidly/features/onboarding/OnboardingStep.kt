package com.mikhailspeaks.masjidly.features.onboarding

/** Mirrors iOS `OnboardingStep.swift`. */
sealed class OnboardingStep {
    data object ChooseLanguage : OnboardingStep()
    data object ChooseMosque : OnboardingStep()
    data class PrayerShortcut(val index: Int) : OnboardingStep()
    data object QiblaCountdown : OnboardingStep()
    data object Qibla : OnboardingStep()
    data object OpenTimetable : OnboardingStep()
    data object ExploreTimetable : OnboardingStep()
    data object CloseTimetable : OnboardingStep()
    data object OpenSettings : OnboardingStep()
    data object ExploreSettings : OnboardingStep()
    data object CloseSettings : OnboardingStep()
    data object Notifications : OnboardingStep()
}

/** Mirrors iOS `OnboardingNotificationDraft`. */
data class OnboardingNotificationDraft(
    var adhanEnabled: Boolean = true,
    var iqamahEnabled: Boolean = true,
    var preAdhanReminderMinutes: Int? = null,
    var preIqamahReminderMinutes: Int? = null,
    var fajr: Boolean = true,
    var dhuhrJummah: Boolean = true,
    var asr: Boolean = true,
    var maghrib: Boolean = true,
    var isha: Boolean = true,
    var adhanFajr: Boolean = true,
    var adhanDhuhrJummah: Boolean = true,
    var adhanAsr: Boolean = true,
    var adhanMaghrib: Boolean = true,
    var adhanIsha: Boolean = true,
    var iqamahFajr: Boolean = true,
    var iqamahDhuhrJummah: Boolean = true,
    var iqamahAsr: Boolean = true,
    var iqamahMaghrib: Boolean = true,
    var iqamahIsha: Boolean = true,
) {
    companion object {
        fun fromSettings(settings: com.mikhailspeaks.masjidly.domain.NotificationSettings): OnboardingNotificationDraft =
            OnboardingNotificationDraft(
                adhanEnabled = settings.adhanEnabled,
                iqamahEnabled = settings.iqamahEnabled,
                preAdhanReminderMinutes = settings.preAdhanReminderMinutes,
                preIqamahReminderMinutes = settings.preIqamahReminderMinutes,
                adhanFajr = settings.adhanFajr,
                adhanDhuhrJummah = settings.adhanDhuhrJummah,
                adhanAsr = settings.adhanAsr,
                adhanMaghrib = settings.adhanMaghrib,
                adhanIsha = settings.adhanIsha,
                iqamahFajr = settings.iqamahFajr,
                iqamahDhuhrJummah = settings.iqamahDhuhrJummah,
                iqamahAsr = settings.iqamahAsr,
                iqamahMaghrib = settings.iqamahMaghrib,
                iqamahIsha = settings.iqamahIsha,
            )
    }
}
