package com.mikhailspeaks.masjidly.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

enum class MasjidlyWidgetFamily { SMALL, MEDIUM, LARGE }

abstract class MasjidlyPrayerWidget(
    private val family: MasjidlyWidgetFamily,
) : GlanceAppWidget() {
    // Fixed S/M/L providers; Exact matches the launcher cell size.
    override val sizeMode: SizeMode = SizeMode.Exact

    protected open val includeTomorrowFajr: Boolean = family != MasjidlyWidgetFamily.LARGE

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                val now = Instant.now()
                val snapshot = WidgetSnapshotStore(context).readSnapshot()
                val state = snapshot?.let {
                    WidgetResolver.resolve(
                        snapshot = it,
                        now = now,
                        includeTomorrowFajr = includeTomorrowFajr,
                    )
                } ?: WidgetPrayerState.missing
                val language = snapshot?.let { AppLanguage.fromWire(it.appLanguageRawValue) } ?: AppLanguage.ENGLISH
                PrayerWidgetContent(state = state, language = language, family = family, now = now)
            }
        }
        val snapshot = WidgetSnapshotStore(context).readSnapshot()
        val scheduleState = snapshot?.let {
            WidgetResolver.resolve(
                snapshot = it,
                now = Instant.now(),
                includeTomorrowFajr = includeTomorrowFajr,
            )
        }
        if (scheduleState != null) {
            WidgetCountdownRefresher.scheduleIfNeeded(context, scheduleState)
        }
    }
}

class MasjidlyPrayerSmallWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.SMALL)
class MasjidlyPrayerMediumWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.MEDIUM)
class MasjidlyPrayerLargeWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.LARGE)

abstract class MasjidlyPrayerWidgetReceiver(
    widget: GlanceAppWidget,
) : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = widget

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scope.launch { WidgetCountdownRefresher.rescheduleFromSnapshot(context) }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        scope.launch { WidgetCountdownRefresher.rescheduleFromSnapshot(context) }
    }

    override fun onDisabled(context: Context) {
        scope.launch { WidgetCountdownRefresher.rescheduleFromSnapshot(context) }
        super.onDisabled(context)
    }
}

class MasjidlyPrayerSmallWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyPrayerSmallWidget())
class MasjidlyPrayerMediumWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyPrayerMediumWidget())
class MasjidlyPrayerLargeWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyPrayerLargeWidget())
