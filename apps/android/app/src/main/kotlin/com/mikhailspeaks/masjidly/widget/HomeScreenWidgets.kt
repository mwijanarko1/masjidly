package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.time.Instant

/** The three home screen designs, ported from the iOS `MasjidlyHomeScreenWidgets`. */
enum class HomeScreenDesign {
    /** 4x4: countdown ring, all five prayers with adhan and iqamah. */
    CARD,

    /** 4x2: all five prayers in a row with the next one highlighted. */
    ROW,

    /** 2x2: the next prayer with a progress ring, its adhan time and the iqamah time. */
    SMALL,
}

abstract class MasjidlyHomeScreenWidget(
    private val design: HomeScreenDesign,
) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    /** The card and row show a whole day, so they move to tomorrow after Isha, like iOS. */
    private val includeTomorrowFajr: Boolean = design == HomeScreenDesign.SMALL

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                val now = Instant.now()
                val snapshot = WidgetSnapshotStore(context).readSnapshot()
                val state = snapshot?.let {
                    WidgetResolver.resolve(snapshot = it, now = now, includeTomorrowFajr = includeTomorrowFajr)
                } ?: WidgetPrayerState.missing
                val language = snapshot?.let { AppLanguage.fromWire(it.appLanguageRawValue) } ?: AppLanguage.ENGLISH
                HomeScreenWidgetContent(
                    model = HomeScreenModel(state, language, now.toEpochMilli()),
                    design = design,
                )
            }
        }

        val snapshot = WidgetSnapshotStore(context).readSnapshot()
        val scheduleState = snapshot?.let {
            WidgetResolver.resolve(snapshot = it, now = Instant.now(), includeTomorrowFajr = includeTomorrowFajr)
        }
        if (scheduleState != null) WidgetCountdownRefresher.scheduleIfNeeded(context, scheduleState)
    }
}

class MasjidlyHomeCardWidget : MasjidlyHomeScreenWidget(HomeScreenDesign.CARD)
class MasjidlyHomeRowWidget : MasjidlyHomeScreenWidget(HomeScreenDesign.ROW)
class MasjidlyHomeSmallWidget : MasjidlyHomeScreenWidget(HomeScreenDesign.SMALL)

class MasjidlyHomeCardWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyHomeCardWidget())
class MasjidlyHomeRowWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyHomeRowWidget())
class MasjidlyHomeSmallWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyHomeSmallWidget())
