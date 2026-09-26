package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.appwidget.updateAll

private val allMasjidlyWidgets = listOf(
    MasjidlyPrayerSmallWidget(),
    MasjidlyPrayerMediumWidget(),
    MasjidlyPrayerLargeWidget(),
)

/** Refreshes all Masjidly Glance widgets after theme or snapshot changes. */
suspend fun updateAllMasjidlyWidgets(context: Context) {
    updateCountdownMasjidlyWidgets(context)
    WidgetCountdownRefresher.rescheduleFromSnapshot(context)
}

/** Refreshes every placed widget (countdown tick path). */
suspend fun updateCountdownMasjidlyWidgets(context: Context) {
    allMasjidlyWidgets.forEach { widget ->
        widget.updateAll(context)
    }
}
