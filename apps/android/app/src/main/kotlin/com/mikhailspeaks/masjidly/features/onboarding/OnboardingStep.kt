package com.mikhailspeaks.masjidly.features.onboarding

import com.mikhailspeaks.masjidly.domain.NotificationSettings

/** Mirrors iOS `OnboardingStep.swift`. */
sealed class OnboardingStep {
    data object ChooseLanguage : OnboardingStep()
    data object RequestLocation : OnboardingStep()
    data object ChooseMosque : OnboardingStep()
    data object Notifications : OnboardingStep()
}

/** Mirrors iOS `OnboardingNotificationDraft`. */
data class OnboardingNotificationDraft(
    var adhanEnabled: Boolean = true,
    var iqamahEnabled: Boolean = true,
    var preAdhanReminderMinutes: Int? = 10,
    var preIqamahReminderMinutes: Int? = 10,
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
        fun fromSettings(settings: NotificationSettings): OnboardingNotificationDraft =
            OnboardingNotificationDraft(
                adhanEnabled = settings.adhanEnabled,
                iqamahEnabled = settings.iqamahEnabled,
                preAdhanReminderMinutes = settings.preAdhanReminderMinutes,
                preIqamahReminderMinutes = settings.preIqamahReminderMinutes,
                fajr = settings.fajr,
                dhuhrJummah = settings.dhuhrJummah,
                asr = settings.asr,
                maghrib = settings.maghrib,
                isha = settings.isha,
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

        /** Onboarding starts from the same defaults as a fresh install. */
        val defaultEnabled: OnboardingNotificationDraft
            get() = fromSettings(NotificationSettings.defaultEnabled)
    }
}
