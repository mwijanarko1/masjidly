package com.mikhailspeaks.masjidly.widget

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

/** Android cell sizes: 2×2, 4×2, 4×4. */
object WidgetSizes {
    val SMALL = DpSize(110.dp, 110.dp)
    val MEDIUM = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)
}

enum class MasjidlyWidgetFamily { SMALL, MEDIUM, LARGE }

abstract class MasjidlyPrayerWidget(
    private val family: MasjidlyWidgetFamily,
    size: DpSize,
) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(size))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val snapshot = WidgetSnapshotStore(context).readSnapshot()
            val includeTomorrowFajr = family != MasjidlyWidgetFamily.LARGE
            val state = snapshot?.let {
                WidgetResolver.resolve(
                    snapshot = it,
                    now = Instant.now(),
                    includeTomorrowFajr = includeTomorrowFajr,
                )
            } ?: WidgetPrayerState.missing
            val language = snapshot?.let { AppLanguage.fromWire(it.appLanguageRawValue) } ?: AppLanguage.ENGLISH
            PrayerWidgetContent(state = state, language = language, family = family)
        }
    }
}

class MasjidlyPrayerSmallWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.SMALL, WidgetSizes.SMALL)
class MasjidlyPrayerMediumWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.MEDIUM, WidgetSizes.MEDIUM)
class MasjidlyPrayerLargeWidget : MasjidlyPrayerWidget(MasjidlyWidgetFamily.LARGE, WidgetSizes.LARGE)

class MasjidlyPrayerSmallWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MasjidlyPrayerSmallWidget()
}

class MasjidlyPrayerMediumWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MasjidlyPrayerMediumWidget()
}

class MasjidlyPrayerLargeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MasjidlyPrayerLargeWidget()
}
