package com.mikhailspeaks.masjidly.widget

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.time.Instant

/** The six lock screen designs, ported from the iOS accessory widgets. */
enum class LockScreenDesign(val isCircular: Boolean) {
    PROGRESS(isCircular = false),
    STRIP(isCircular = false),
    LIST_MORNING(isCircular = false),
    LIST_EVENING(isCircular = false),
    MINUTES(isCircular = true),
    CODE(isCircular = true),
}

abstract class MasjidlyLockScreenWidget(
    private val design: LockScreenDesign,
) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetSnapshotStore(context).readSnapshot()
        val now = Instant.now()
        val state = snapshot?.let { WidgetResolver.resolve(snapshot = it, now = now) }
            ?: WidgetPrayerState.missing
        val language = snapshot?.let { AppLanguage.fromWire(it.appLanguageRawValue) } ?: AppLanguage.ENGLISH

        provideContent {
            GlanceTheme {
                LockScreenWidgetContent(
                    model = LockScreenModel(state, language, now.toEpochMilli()),
                    design = design,
                )
            }
        }

        WidgetCountdownRefresher.scheduleIfNeeded(context, state)
    }
}

class MasjidlyLockProgressWidget : MasjidlyLockScreenWidget(LockScreenDesign.PROGRESS)
class MasjidlyLockStripWidget : MasjidlyLockScreenWidget(LockScreenDesign.STRIP)
class MasjidlyLockListMorningWidget : MasjidlyLockScreenWidget(LockScreenDesign.LIST_MORNING)
class MasjidlyLockListEveningWidget : MasjidlyLockScreenWidget(LockScreenDesign.LIST_EVENING)
class MasjidlyLockMinutesWidget : MasjidlyLockScreenWidget(LockScreenDesign.MINUTES)
class MasjidlyLockCodeWidget : MasjidlyLockScreenWidget(LockScreenDesign.CODE)

class MasjidlyLockProgressWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockProgressWidget())
class MasjidlyLockStripWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockStripWidget())
class MasjidlyLockListMorningWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockListMorningWidget())
class MasjidlyLockListEveningWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockListEveningWidget())
class MasjidlyLockMinutesWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockMinutesWidget())
class MasjidlyLockCodeWidgetReceiver : MasjidlyPrayerWidgetReceiver(MasjidlyLockCodeWidget())
