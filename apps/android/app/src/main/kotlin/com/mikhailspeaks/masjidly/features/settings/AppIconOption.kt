package com.mikhailspeaks.masjidly.features.settings

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.annotation.DrawableRes
import com.mikhailspeaks.masjidly.R

/**
 * Android counterpart to iOS `AppIconOption`.
 *
 * Uses activity-alias launcher components so each theme can ship its own icon.
 * Sky is the default (enabled) alias; the others start disabled.
 */
enum class AppIconOption(
    val aliasClassName: String,
    @DrawableRes val previewResId: Int,
    val titleKey: String,
) {
    DAWN(
        aliasClassName = "MainActivityDawn",
        previewResId = R.drawable.app_icon_option_dawn,
        titleKey = "settings.app_icon.dawn",
    ),
    SKY(
        aliasClassName = "MainActivitySky",
        previewResId = R.drawable.app_icon_option_sky,
        titleKey = "settings.app_icon.sky",
    ),
    AFTERNOON(
        aliasClassName = "MainActivityAfternoon",
        previewResId = R.drawable.app_icon_option_afternoon,
        titleKey = "settings.app_icon.afternoon",
    ),
    ROSE(
        aliasClassName = "MainActivityRose",
        previewResId = R.drawable.app_icon_option_rose,
        titleKey = "settings.app_icon.rose",
    );

    fun componentName(context: Context): ComponentName =
        ComponentName(context.packageName, "${context.packageName}.$aliasClassName")

    companion object {
        fun current(context: Context): AppIconOption {
            val pm = context.packageManager
            for (option in entries) {
                val state = pm.getComponentEnabledSetting(option.componentName(context))
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    return option
                }
                // DEFAULT means "use manifest value". Sky is enabled in the manifest.
                if (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && option == SKY) {
                    return option
                }
            }
            return SKY
        }

        fun apply(context: Context, option: AppIconOption) {
            if (current(context) == option) return
            val pm = context.packageManager
            // Enable the new launcher first so the home-screen icon never disappears.
            pm.setComponentEnabledSetting(
                option.componentName(context),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for (candidate in entries) {
                if (candidate == option) continue
                pm.setComponentEnabledSetting(
                    candidate.componentName(context),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }
}
