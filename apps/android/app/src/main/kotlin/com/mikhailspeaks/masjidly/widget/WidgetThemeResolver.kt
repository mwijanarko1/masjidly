package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.glance.unit.ColorProvider
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.ui.home.ThemeMode
import com.mikhailspeaks.masjidly.ui.home.TimeTheme

object WidgetThemeResolver {
    fun resolvedTheme(context: Context, prayerId: String): TimeTheme {
        val settings = SettingsStore(context)
        if (settings.themeMode == ThemeMode.FIXED) {
            return settings.fixedTheme
        }
        return TimeTheme.fromWire(prayerId)
    }

    fun Color.toGlanceColorProvider(): ColorProvider = ColorProvider(toArgb())
}
