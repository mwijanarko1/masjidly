package com.mikhailspeaks.masjidly.widget

import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Box
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme

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
            .background(skyBackgroundImageProvider(appearance))
            .clickable(onClick)
            .padding(widgetContentPadding(family)),
    ) {
        content()
    }
}

internal fun widgetContentPadding(family: MasjidlyWidgetFamily) = when (family) {
    MasjidlyWidgetFamily.SMALL -> 8.dp
    MasjidlyWidgetFamily.MEDIUM -> 8.dp
    MasjidlyWidgetFamily.LARGE -> 20.dp
}
