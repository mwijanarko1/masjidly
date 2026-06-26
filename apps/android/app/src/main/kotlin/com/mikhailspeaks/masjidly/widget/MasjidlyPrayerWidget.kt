package com.mikhailspeaks.masjidly.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
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

/** Android cell sizes: 2×2, 4×2, 4×4. */
object WidgetSizes {
    val SMALL = DpSize(110.dp, 110.dp)
    val SMALL_TALL = DpSize(110.dp, 140.dp)
    val SMALL_EXTRA_TALL = DpSize(110.dp, 170.dp)
    val MEDIUM = DpSize(250.dp, 110.dp)
    val MEDIUM_TALL = DpSize(250.dp, 140.dp)
    val MEDIUM_EXTRA_TALL = DpSize(250.dp, 170.dp)
    val LARGE = DpSize(250.dp, 250.dp)
}

enum class MasjidlyWidgetFamily { SMALL, MEDIUM, LARGE }

abstract class MasjidlyPrayerWidget(
    private val family: MasjidlyWidgetFamily,
    sizes: Set<DpSize>,
) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(sizes)

    protected open val includeTomorrowFajr: Boolean = family != MasjidlyWidgetFamily.LARGE

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
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

class MasjidlyPrayerSmallWidget : MasjidlyPrayerWidget(
    MasjidlyWidgetFamily.SMALL,
    setOf(WidgetSizes.SMALL, WidgetSizes.SMALL_TALL, WidgetSizes.SMALL_EXTRA_TALL),
)
class MasjidlyPrayerMediumWidget : MasjidlyPrayerWidget(
    MasjidlyWidgetFamily.MEDIUM,
    setOf(WidgetSizes.MEDIUM, WidgetSizes.MEDIUM_TALL, WidgetSizes.MEDIUM_EXTRA_TALL),
)
class MasjidlyPrayerLargeWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.LARGE, setOf(WidgetSizes.LARGE))

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
