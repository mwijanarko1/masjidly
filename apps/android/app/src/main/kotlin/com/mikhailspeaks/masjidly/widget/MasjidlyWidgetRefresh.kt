package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager

/** Refreshes all Masjidly Glance widgets after theme or snapshot changes. */
suspend fun updateAllMasjidlyWidgets(context: Context) {
    val manager = GlanceAppWidgetManager(context)
    listOf(
        MasjidlyPrayerSmallWidget::class.java to MasjidlyPrayerSmallWidget(),
        MasjidlyPrayerMediumWidget::class.java to MasjidlyPrayerMediumWidget(),
        MasjidlyPrayerLargeWidget::class.java to MasjidlyPrayerLargeWidget(),
    ).forEach { (receiverClass, widget) ->
        manager.getGlanceIds(receiverClass).forEach { glanceId ->
            widget.update(context, glanceId)
        }
    }
}
