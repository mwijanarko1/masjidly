package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager

private val allMasjidlyWidgets = listOf(
    MasjidlyPrayerSmallWidget::class.java to MasjidlyPrayerSmallWidget(),
    MasjidlyPrayerMediumWidget::class.java to MasjidlyPrayerMediumWidget(),
    MasjidlyPrayerLargeWidget::class.java to MasjidlyPrayerLargeWidget(),
)

/** Refreshes all Masjidly Glance widgets after theme or snapshot changes. */
suspend fun updateAllMasjidlyWidgets(context: Context) {
    updateCountdownMasjidlyWidgets(context)
    WidgetCountdownRefresher.rescheduleFromSnapshot(context)
}

/** Refreshes every placed widget (countdown tick path). */
suspend fun updateCountdownMasjidlyWidgets(context: Context) {
    val manager = GlanceAppWidgetManager(context)
    allMasjidlyWidgets.forEach { (receiverClass, widget) ->
        manager.getGlanceIds(receiverClass).forEach { glanceId ->
            widget.update(context, glanceId)
        }
    }
}
