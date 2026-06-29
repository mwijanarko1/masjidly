package com.mikhailspeaks.masjidly.data

import android.content.Context
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.NotificationSettings
import com.mikhailspeaks.masjidly.ui.home.CustomSkyGradientColors
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.toHexString
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

    init {
        migrateLegacyPrayerGradientStylesIfNeeded()
    }

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

    /** When true, the Sunrise home page shows the Duha prayer window under the sunrise time. */
    var showDuhaTime: Boolean
        get() = prefs.getBoolean(KEY_SHOW_DUHA_TIME, true)
        set(value) {
            prefs.edit().putBoolean(KEY_SHOW_DUHA_TIME, value).apply()
            bump()
        }

    /** When true, prayer home pages show iqamah times under the adhan time. */
    var showIqamahTime: Boolean
        get() = prefs.getBoolean(KEY_SHOW_IQAMAH_TIME, true)
        set(value) {
            prefs.edit().putBoolean(KEY_SHOW_IQAMAH_TIME, value).apply()
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

    var hasDismissedExactAlarmPrompt: Boolean
        get() = prefs.getBoolean(KEY_HAS_DISMISSED_EXACT_ALARM_PROMPT, false)
        set(value) {
            prefs.edit().putBoolean(KEY_HAS_DISMISSED_EXACT_ALARM_PROMPT, value).apply()
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

    fun resolvedTheme(dynamicTheme: TimeTheme): ResolvedTheme {
        val timeTheme = if (themeMode == ThemeMode.DYNAMIC) dynamicTheme else fixedTheme
        return resolvedAppearanceFor(timeTheme)
    }

    fun resolvedAppearanceFor(timeTheme: TimeTheme): ResolvedTheme {
        val gradientSet = skyGradientSet(timeTheme)
        val customColors = customGradientColors(timeTheme)
        return ResolvedTheme(
            timeTheme = timeTheme,
            gradientSet = gradientSet,
            customTopColor = if (gradientSet == SkyGradientSet.CUSTOM) customColors.topColor else null,
            customBottomColor = if (gradientSet == SkyGradientSet.CUSTOM) customColors.bottomColor else null,
        )
    }

    fun customGradientColors(timeTheme: TimeTheme): CustomSkyGradientColors =
        prayerCustomGradientColors[timeTheme.wireValue] ?: CustomSkyGradientColors.defaultsFor(timeTheme)

    fun setCustomGradientColors(colors: CustomSkyGradientColors, timeTheme: TimeTheme) {
        if (timeTheme !in TimeTheme.configurableGradientThemes) return
        val updated = prayerCustomGradientColors.toMutableMap()
        updated[timeTheme.wireValue] = colors
        prayerCustomGradientColors = updated
    }

    fun setCustomGradientTopColor(color: androidx.compose.ui.graphics.Color, timeTheme: TimeTheme) {
        val colors = customGradientColors(timeTheme).copy(topHex = color.toHexString())
        setCustomGradientColors(colors, timeTheme)
    }

    fun setCustomGradientBottomColor(color: androidx.compose.ui.graphics.Color, timeTheme: TimeTheme) {
        val colors = customGradientColors(timeTheme).copy(bottomHex = color.toHexString())
        setCustomGradientColors(colors, timeTheme)
    }

    fun skyGradientSet(timeTheme: TimeTheme): SkyGradientSet {
        if (timeTheme !in TimeTheme.configurableGradientThemes) {
            return timeTheme.defaultGradientSet()
        }
        val override = prayerGradientStyles[timeTheme.wireValue] ?: return timeTheme.defaultGradientSet()
        return SkyGradientSet.fromWire(override) ?: timeTheme.defaultGradientSet()
    }

    fun setSkyGradientSet(set: SkyGradientSet, timeTheme: TimeTheme) {
        if (timeTheme !in TimeTheme.configurableGradientThemes) return
        val styles = prayerGradientStyles.toMutableMap()
        styles[timeTheme.wireValue] = set.wireValue
        prayerGradientStyles = styles
        if (set == SkyGradientSet.CUSTOM && prayerCustomGradientColors[timeTheme.wireValue] == null) {
            setCustomGradientColors(CustomSkyGradientColors.defaultsFor(timeTheme), timeTheme)
        }
    }

    private fun migrateLegacyPrayerGradientStylesIfNeeded() {
        val current = prayerGradientStyles
        if (current.isEmpty()) return
        val migrated = migratePrayerGradientStyles(current)
        if (migrated != current) {
            prayerGradientStyles = migrated
        }
    }

    private fun migratePrayerGradientStyles(styles: Map<String, String>): Map<String, String> {
        val configurableKeys = TimeTheme.configurableGradientThemes.map { it.wireValue }.toSet()
        val normalized = styles
            .mapKeys { (key, _) -> key.lowercase() }
            .mapValues { (_, value) -> normalizeGradientWireValue(value) }
            .filterKeys { it in configurableKeys }

        if (normalized.isEmpty()) return emptyMap()

        // Older builds seeded every prayer as "classic" — drop so per-prayer product defaults apply.
        val legacyAllClassic = normalized.size >= configurableKeys.size &&
            normalized.values.all { it == SkyGradientSet.CLASSIC.wireValue }
        if (legacyAllClassic) return emptyMap()

        return normalized
    }

    private fun normalizeGradientWireValue(raw: String): String = when (raw.lowercase()) {
        "original" -> SkyGradientSet.CLASSIC.wireValue
        "modern" -> SkyGradientSet.SET2.wireValue
        else -> raw.lowercase()
    }

    private var prayerCustomGradientColors: Map<String, CustomSkyGradientColors>
        get() {
            val raw = prefs.getString(KEY_PRAYER_CUSTOM_GRADIENT_COLORS_JSON, null) ?: return emptyMap()
            return runCatching { json.decodeFromString<Map<String, CustomSkyGradientColors>>(raw) }
                .getOrDefault(emptyMap())
        }
        set(value) {
            prefs.edit().putString(KEY_PRAYER_CUSTOM_GRADIENT_COLORS_JSON, json.encodeToString(value)).apply()
            bump()
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
        private const val KEY_SHOW_DUHA_TIME = "showDuhaTime"
        private const val KEY_SHOW_IQAMAH_TIME = "showIqamahTime"
        private const val KEY_FIRST_APP_OPEN_TRACKED_AT = "firstAppOpenTrackedAt1970"
        private const val KEY_HAS_COMPLETED_ENJOYMENT_REVIEW_FLOW = "hasCompletedEnjoymentReviewFlow"
        private const val KEY_HAS_DISMISSED_EXACT_ALARM_PROMPT = "hasDismissedExactAlarmPrompt"
        private const val KEY_LAST_SEEN_BUILD_VERSION = "lastSeenBuildVersion"
        private const val KEY_NOTIFICATIONS_JSON = "notificationsJSON"
        private const val KEY_PRAYER_GRADIENT_STYLES_JSON = "prayerGradientStylesJSON"
        private const val KEY_PRAYER_CUSTOM_GRADIENT_COLORS_JSON = "prayerCustomGradientColorsJSON"
    }
}
