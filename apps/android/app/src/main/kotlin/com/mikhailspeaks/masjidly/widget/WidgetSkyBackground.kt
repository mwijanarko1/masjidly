package com.mikhailspeaks.masjidly.widget

import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Box
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.SkyGradientSet
import com.mikhailspeaks.masjidly.ui.home.TimeTheme

@androidx.compose.runtime.Composable
fun WidgetSkyBackground(
    appearance: ResolvedTheme,
    family: MasjidlyWidgetFamily,
    onClick: Action,
    content: @androidx.compose.runtime.Composable () -> Unit,
) {
    val cornerRadius = if (family == MasjidlyWidgetFamily.SMALL) 16.dp else 20.dp
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(cornerRadius)
            .background(ImageProvider(skyDrawableFor(appearance)))
            .clickable(onClick)
            .padding(widgetContentPadding(family)),
    ) {
        content()
    }
}

private fun skyDrawableFor(appearance: ResolvedTheme): Int {
    val modern = appearance.gradientSet == SkyGradientSet.SET2
    return when (appearance.timeTheme) {
        TimeTheme.FAJR -> if (modern) R.drawable.widget_sky_fajr_modern else R.drawable.widget_sky_fajr
        TimeTheme.SUNRISE -> if (modern) R.drawable.widget_sky_sunrise_modern else R.drawable.widget_sky_sunrise
        TimeTheme.DHUHR -> if (modern) R.drawable.widget_sky_dhuhr_modern else R.drawable.widget_sky_dhuhr
        TimeTheme.ASR -> if (modern) R.drawable.widget_sky_asr_modern else R.drawable.widget_sky_asr
        TimeTheme.MAGHRIB -> if (modern) R.drawable.widget_sky_maghrib_modern else R.drawable.widget_sky_maghrib
        TimeTheme.ISHA, TimeTheme.TAHAJJUD -> if (modern) R.drawable.widget_sky_isha_modern else R.drawable.widget_sky_isha
    }
}

internal fun widgetContentPadding(family: MasjidlyWidgetFamily) = when (family) {
    MasjidlyWidgetFamily.SMALL -> 12.dp
    MasjidlyWidgetFamily.MEDIUM -> 8.dp
    MasjidlyWidgetFamily.LARGE -> 14.dp
}
