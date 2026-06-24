package com.mikhailspeaks.masjidly.data

import android.content.Context
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.NotificationSettings
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.SkyGradientSet
import com.mikhailspeaks.masjidly.ui.home.ThemeMode
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant

/**
 * Persisted user preferences — mirrors iOS `SettingsStore.swift`.
 */
class SettingsStore(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val _revision = MutableStateFlow(0)
    val revision: StateFlow<Int> = _revision.asStateFlow()

    private fun bump() {
        _revision.value += 1
    }

    var selectedMosqueId: String?
        get() = prefs.getString(KEY_SELECTED_MOSQUE_ID, null)
        set(value) {
            prefs.edit().putString(KEY_SELECTED_MOSQUE_ID, value).apply()
            bump()
        }

    var selectedMosqueSlug: String?
        get() = prefs.getString(KEY_SELECTED_MOSQUE_SLUG, null)
        set(value) {
            prefs.edit().putString(KEY_SELECTED_MOSQUE_SLUG, value).apply()
            bump()
        }

    var selectedCityGroupingKey: String?
        get() = prefs.getString(KEY_SELECTED_CITY_GROUPING, null)
        set(value) {
            prefs.edit().putString(KEY_SELECTED_CITY_GROUPING, value).apply()
            bump()
        }

    var selectedCountryGroupingKey: String?
        get() = prefs.getString(KEY_SELECTED_COUNTRY_GROUPING, null)
        set(value) {
            prefs.edit().putString(KEY_SELECTED_COUNTRY_GROUPING, value).apply()
            bump()
        }

    var uses24HourTime: Boolean
        get() = prefs.getBoolean(KEY_USES_24H, false)
        set(value) {
            prefs.edit().putBoolean(KEY_USES_24H, value).apply()
            bump()
        }

    var asrIqamahPreference: AsrIqamahPreference
        get() = AsrIqamahPreference.fromWire(prefs.getString(KEY_ASR_IQAMAH_PREF, null))
        set(value) {
            prefs.edit().putString(KEY_ASR_IQAMAH_PREF, value.wireValue).apply()
            bump()
        }

    var hasCompletedOnboarding: Boolean
        get() = prefs.getBoolean(KEY_HAS_COMPLETED_ONBOARDING, false)
        set(value) {
            prefs.edit().putBoolean(KEY_HAS_COMPLETED_ONBOARDING, value).apply()
            bump()
        }

    var appLanguage: AppLanguage
        get() = AppLanguage.fromWire(prefs.getString(KEY_APP_LANGUAGE, null))
        set(value) {
            prefs.edit().putString(KEY_APP_LANGUAGE, value.wireValue).apply()
            bump()
        }

    var themeMode: ThemeMode
        get() = ThemeMode.fromWire(prefs.getString(KEY_THEME_MODE, null))
        set(value) {
            prefs.edit().putString(KEY_THEME_MODE, value.wireValue).apply()
            bump()
        }

    var fixedTheme: TimeTheme
        get() = TimeTheme.fromWire(prefs.getString(KEY_FIXED_THEME, null))
        set(value) {
            prefs.edit().putString(KEY_FIXED_THEME, value.wireValue).apply()
            bump()
        }

    var hideQiblaCompass: Boolean
        get() = prefs.getBoolean(KEY_HIDE_QIBLA, false)
        set(value) {
            prefs.edit().putBoolean(KEY_HIDE_QIBLA, value).apply()
            bump()
        }

    /** First launch timestamp for the soft review prompt — mirrors iOS `firstAppOpenTrackedAt`. */
    var firstAppOpenTrackedAt: Instant?
        get() = prefs.getLong(KEY_FIRST_APP_OPEN_TRACKED_AT, 0L).takeIf { it > 0L }?.let(Instant::ofEpochMilli)
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_FIRST_APP_OPEN_TRACKED_AT).apply()
            } else {
                prefs.edit().putLong(KEY_FIRST_APP_OPEN_TRACKED_AT, value.toEpochMilli()).apply()
            }
            bump()
        }

    /** After either review-prompt answer, don't show it again. */
    var hasCompletedEnjoymentReviewFlow: Boolean
        get() = prefs.getBoolean(KEY_HAS_COMPLETED_ENJOYMENT_REVIEW_FLOW, false)
        set(value) {
            prefs.edit().putBoolean(KEY_HAS_COMPLETED_ENJOYMENT_REVIEW_FLOW, value).apply()
            bump()
        }

    fun ensureFirstAppOpenTrackedAtRecordedIfNeeded() {
        if (firstAppOpenTrackedAt == null) firstAppOpenTrackedAt = Instant.now()
    }

    fun resetEnjoymentReviewPromptForTesting() {
        hasCompletedEnjoymentReviewFlow = false
        firstAppOpenTrackedAt = Instant.now().minusSeconds(2 * 86_400L)
    }

    /** Last build version string shown in the What's New modal — mirrors iOS `lastSeenBuildVersion`. */
    var lastSeenBuildVersion: String?
        get() = prefs.getString(KEY_LAST_SEEN_BUILD_VERSION, null)
        set(value) {
            if (value == null) {
                prefs.edit().remove(KEY_LAST_SEEN_BUILD_VERSION).apply()
            } else {
                prefs.edit().putString(KEY_LAST_SEEN_BUILD_VERSION, value).apply()
            }
            bump()
        }

    var notifications: NotificationSettings
        get() {
            val raw = prefs.getString(KEY_NOTIFICATIONS_JSON, null) ?: return NotificationSettings()
            return runCatching { json.decodeFromString<NotificationSettings>(raw) }
                .getOrDefault(NotificationSettings())
        }
        set(value) {
            prefs.edit().putString(KEY_NOTIFICATIONS_JSON, json.encodeToString(value)).apply()
            bump()
        }

    fun resolvedLocale() = appLanguage.resolvedLocale()

    fun resolvedTheme(dynamicTheme: TimeTheme): ResolvedTheme = resolvedAppearance(dynamicTheme)

    fun resolvedAppearance(for timeTheme: TimeTheme): ResolvedTheme =
        ResolvedTheme(timeTheme, skyGradientSet(for = timeTheme))

    fun resolvedAppearance(dynamicTheme: TimeTheme): ResolvedTheme {
        val timeTheme = if (themeMode == ThemeMode.DYNAMIC) dynamicTheme else fixedTheme
        return resolvedAppearance(for = timeTheme)
    }

    fun skyGradientSet(for timeTheme: TimeTheme): SkyGradientSet {
        val raw = prayerGradientStyles[timeTheme.wireValue] ?: timeTheme.defaultGradientSet().wireValue
        return SkyGradientSet.fromWire(raw) ?: timeTheme.defaultGradientSet()
    }

    fun setSkyGradientSet(set: SkyGradientSet, for timeTheme: TimeTheme) {
        val styles = prayerGradientStyles.toMutableMap()
        styles[timeTheme.wireValue] = set.wireValue
        prayerGradientStyles = styles
    }

    private var prayerGradientStyles: Map<String, String>
        get() {
            val raw = prefs.getString(KEY_PRAYER_GRADIENT_STYLES_JSON, null) ?: return emptyMap()
            return runCatching { json.decodeFromString<Map<String, String>>(raw) }
                .getOrDefault(emptyMap())
        }
        set(value) {
            prefs.edit().putString(KEY_PRAYER_GRADIENT_STYLES_JSON, json.encodeToString(value)).apply()
            bump()
        }

    companion object {
        private const val PREFS_NAME = "masjidly_settings"
        private const val KEY_SELECTED_MOSQUE_ID = "selectedMosqueId"
        private const val KEY_SELECTED_MOSQUE_SLUG = "selectedMosqueSlug"
        private const val KEY_SELECTED_CITY_GROUPING = "selectedCityGroupingKey"
        private const val KEY_SELECTED_COUNTRY_GROUPING = "selectedCountryGroupingKey"
        private const val KEY_USES_24H = "uses24HourTime"
        private const val KEY_ASR_IQAMAH_PREF = "asrIqamahPreference"
        private const val KEY_HAS_COMPLETED_ONBOARDING = "hasCompletedOnboarding"
        private const val KEY_APP_LANGUAGE = "appLanguage"
        private const val KEY_THEME_MODE = "themeMode"
        private const val KEY_FIXED_THEME = "fixedTheme"
        private const val KEY_HIDE_QIBLA = "hideQiblaCompass"
        private const val KEY_FIRST_APP_OPEN_TRACKED_AT = "firstAppOpenTrackedAt1970"
        private const val KEY_HAS_COMPLETED_ENJOYMENT_REVIEW_FLOW = "hasCompletedEnjoymentReviewFlow"
        private const val KEY_LAST_SEEN_BUILD_VERSION = "lastSeenBuildVersion"
        private const val KEY_NOTIFICATIONS_JSON = "notificationsJSON"
        private const val KEY_PRAYER_GRADIENT_STYLES_JSON = "prayerGradientStylesJSON"
    }
}
