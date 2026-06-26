package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.glance.unit.ColorProvider
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.ThemeMode
import com.mikhailspeaks.masjidly.ui.home.TimeTheme

object WidgetThemeResolver {
    fun resolvedAppearance(context: Context, prayerId: String): ResolvedTheme {
        val settings = SettingsStore(context)
        val timeTheme = if (settings.themeMode == ThemeMode.FIXED) {
            settings.fixedTheme
        } else {
            TimeTheme.fromWire(prayerId)
        }
        return settings.resolvedAppearanceFor(timeTheme)
    }

    fun Color.toGlanceColorProvider(): ColorProvider = ColorProvider(this)
}
