package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.time.Instant

/** iOS-aligned widget size breakpoints: small (2×2), medium (4×2), large (4×4). */
object WidgetSizes {
    val SMALL = DpSize(110.dp, 110.dp)
    val MEDIUM = DpSize(250.dp, 110.dp)
    val LARGE = DpSize(250.dp, 250.dp)
}

class MasjidlyPrayerWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(WidgetSizes.SMALL, WidgetSizes.MEDIUM, WidgetSizes.LARGE),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val snapshot = WidgetSnapshotStore(context).readSnapshot()
            val size = LocalSize.current
            val includeTomorrowFajr = size.width < 180.dp
            val state = snapshot?.let {
                WidgetResolver.resolve(
                    snapshot = it,
                    now = Instant.now(),
                    includeTomorrowFajr = includeTomorrowFajr,
                )
            } ?: WidgetPrayerState.missing
            val language = snapshot?.let { AppLanguage.fromWire(it.appLanguageRawValue) } ?: AppLanguage.ENGLISH
            PrayerWidgetContent(state = state, language = language)
        }
    }
}

class MasjidlyPrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MasjidlyPrayerWidget()
}
