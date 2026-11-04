package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.updateAll

internal val allMasjidlyWidgets: List<GlanceAppWidget> = listOf(
    MasjidlyPrayerSmallWidget(),
    MasjidlyPrayerMediumWidget(),
    MasjidlyPrayerLargeWidget(),
    MasjidlyLockProgressWidget(),
    MasjidlyLockStripWidget(),
    MasjidlyLockListMorningWidget(),
    MasjidlyLockListEveningWidget(),
    MasjidlyLockMinutesWidget(),
    MasjidlyLockCodeWidget(),
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
