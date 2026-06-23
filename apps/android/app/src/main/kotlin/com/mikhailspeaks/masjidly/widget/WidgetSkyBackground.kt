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
import com.mikhailspeaks.masjidly.ui.home.TimeTheme

@androidx.compose.runtime.Composable
fun WidgetSkyBackground(
    theme: TimeTheme,
    family: MasjidlyWidgetFamily,
    onClick: Action,
    content: @androidx.compose.runtime.Composable () -> Unit,
) {
    val cornerRadius = if (family == MasjidlyWidgetFamily.SMALL) 16.dp else 20.dp
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(cornerRadius)
            .background(ImageProvider(skyDrawableFor(theme)))
            .clickable(onClick)
            .padding(widgetContentPadding(family)),
    ) {
        content()
    }
}

private fun skyDrawableFor(theme: TimeTheme): Int = when (theme) {
    TimeTheme.FAJR -> R.drawable.widget_sky_fajr
    TimeTheme.SUNRISE -> R.drawable.widget_sky_sunrise
    TimeTheme.DHUHR -> R.drawable.widget_sky_dhuhr
    TimeTheme.ASR -> R.drawable.widget_sky_asr
    TimeTheme.MAGHRIB -> R.drawable.widget_sky_maghrib
    TimeTheme.ISHA, TimeTheme.TAHAJJUD -> R.drawable.widget_sky_isha
}

internal fun widgetContentPadding(family: MasjidlyWidgetFamily) = when (family) {
    MasjidlyWidgetFamily.SMALL -> 12.dp
    MasjidlyWidgetFamily.MEDIUM -> 12.dp
    MasjidlyWidgetFamily.LARGE -> 14.dp
}
