package com.mikhailspeaks.masjidly.features.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.NotificationSettings

/** Copy and channel wiring for prayer notifications — mirrors iOS `PrayerNotificationContent.swift`. */
object PrayerNotificationContent {
    const val CHANNEL_ID = "prayer-times"
    const val IDENTIFIER_PREFIX = "masjidly.prayer."

    object CategoryId {
        const val ADHAN = "masjidly.category.adhan"
        const val IQAMAH = "masjidly.category.iqamah"
        const val REMINDER = "masjidly.category.reminder"
    }

    object UserInfoKey {
        const val KIND = "masjidly.kind"
        const val PRAYER = "masjidly.prayer"
        const val MOSQUE_SLUG = "masjidly.mosque_slug"
        const val ISO_DATE = "masjidly.iso_date"
        const val REMINDER_MINUTES = "masjidly.reminder_minutes"
    }

    enum class PayloadKind(val wireValue: String) {
        ADHAN("adhan"),
        IQAMAH("iqamah"),
        REMINDER_BEFORE_ADHAN("reminderBeforeAdhan"),
        REMINDER_BEFORE_IQAMAH("reminderBeforeIqamah"),
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer Times",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Adhan, iqamah, and prayer reminders"
        }
        manager.createNotificationChannel(channel)
    }

    fun prayerDisplayName(prayerKey: String, isFriday: Boolean, language: AppLanguage): String =
        when (prayerKey) {
            "fajr" -> LocaleStrings.t("settings.notification.fajr", language)
            "dhuhr" -> if (isFriday) {
                LocaleStrings.t("prayer.jummah", language)
            } else {
                LocaleStrings.t("settings.notification.dhuhr_jummah", language).substringBefore(" /")
            }
            "asr" -> LocaleStrings.t("settings.notification.asr", language)
            "maghrib" -> LocaleStrings.t("settings.notification.maghrib", language)
            "isha" -> LocaleStrings.t("settings.notification.isha", language)
            else -> prayerKey.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }

    fun adhanCopy(prayerKey: String, isFriday: Boolean, language: AppLanguage): Pair<String, String> {
        val name = prayerDisplayName(prayerKey, isFriday, language)
        return LocaleStrings.format("notification.copy.adhan.title", language, name) to
            LocaleStrings.t("notification.copy.adhan.body", language)
    }

    fun iqamahCopy(prayerKey: String, isFriday: Boolean, language: AppLanguage): Pair<String, String> {
        val name = prayerDisplayName(prayerKey, isFriday, language)
        return LocaleStrings.format("notification.copy.iqamah.title", language, name) to
            LocaleStrings.format("notification.copy.iqamah.body", language, name)
    }

    fun beforeAdhanReminderCopy(
        prayerKey: String,
        isFriday: Boolean,
        minutes: Int,
        language: AppLanguage,
    ): Pair<String, String> {
        val name = prayerDisplayName(prayerKey, isFriday, language)
        return LocaleStrings.format("notification.copy.before_adhan.title", language, name) to
            LocaleStrings.format("notification.copy.before_adhan.body", language, minutes.toString())
    }

    fun beforeIqamahReminderCopy(
        prayerKey: String,
        isFriday: Boolean,
        minutes: Int,
        language: AppLanguage,
    ): Pair<String, String> {
        val name = prayerDisplayName(prayerKey, isFriday, language)
        return LocaleStrings.format("notification.copy.before_iqamah.title", language, name) to
            LocaleStrings.format("notification.copy.before_iqamah.body", language, minutes.toString())
    }

    @Suppress("UNUSED_PARAMETER")
    fun usesSound(settings: NotificationSettings, channel: SoundChannel): Boolean = true

    enum class SoundChannel {
        ADHAN,
        IQAMAH,
        REMINDER,
    }

    fun debugUserInfo(
        kind: PayloadKind,
        prayerKey: String,
        mosqueSlug: String,
        isoDate: String = "2099-01-01",
    ): Map<String, String> = mapOf(
        UserInfoKey.KIND to kind.wireValue,
        UserInfoKey.PRAYER to prayerKey,
        UserInfoKey.MOSQUE_SLUG to mosqueSlug,
        UserInfoKey.ISO_DATE to isoDate,
    )

    /** Bundled adhan for in-app playback — mirrors iOS `bundledAdhanPlaybackURL()`. */
    fun bundledAdhanRawResource(): Int? {
        val candidates = listOf(
            R.raw.adhan_1,
            R.raw.adhan_2,
        )
        return candidates.firstOrNull()
    }
}
