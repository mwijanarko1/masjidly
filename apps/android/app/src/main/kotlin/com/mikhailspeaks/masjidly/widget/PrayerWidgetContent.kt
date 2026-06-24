package com.mikhailspeaks.masjidly.widget

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.mikhailspeaks.masjidly.MainActivity
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun PrayerWidgetContent(
    state: WidgetPrayerState,
    language: AppLanguage,
    family: MasjidlyWidgetFamily,
) {
    val context = LocalContext.current
    val theme = WidgetThemeResolver.resolvedTheme(context, state.prayerId)
    val palette = WidgetPalette.from(theme)
    val locale = language.resolvedLocale()
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
    )

    WidgetSkyBackground(theme = theme, family = family, onClick = openApp) {
        when (state.kind) {
            WidgetStateKind.MISSING, WidgetStateKind.STALE -> UnavailableWidget(language, palette)
            WidgetStateKind.CONTENT -> when (family) {
                MasjidlyWidgetFamily.SMALL -> SmallWidget(state, palette, language)
                MasjidlyWidgetFamily.MEDIUM -> MediumWidget(state, palette, locale, language)
                MasjidlyWidgetFamily.LARGE -> LargeWidget(state, palette, locale, language)
            }
        }
    }
}

private data class WidgetPalette(
    val primary: ColorProvider,
    val secondary: ColorProvider,
    val faint: ColorProvider,
) {
    companion object {
        fun from(theme: TimeTheme): WidgetPalette {
            val text = theme.textColor
            return WidgetPalette(
                primary = ColorProvider(text),
                secondary = ColorProvider(text.copy(alpha = 0.85f)),
                faint = ColorProvider(text.copy(alpha = 0.55f)),
            )
        }
    }
}

@Composable
private fun UnavailableWidget(language: AppLanguage, palette: WidgetPalette) {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = WidgetStrings.unavailable(language),
            style = TextStyle(color = palette.primary, fontSize = 12.sp, fontWeight = FontWeight.Medium),
            maxLines = 2,
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = WidgetStrings.openApp(language),
            style = TextStyle(color = palette.faint, fontSize = 10.sp),
            maxLines = 1,
        )
    }
}

/** 2×2 — mirrors home hero: prayer name + large time + iqamah. */
@Composable
private fun SmallWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    language: AppLanguage,
) {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = state.prayerName,
            style = TextStyle(color = palette.secondary, fontSize = 14.sp, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = state.adhanTime,
            style = TextStyle(color = palette.primary, fontSize = 26.sp, fontWeight = FontWeight.Normal),
            maxLines = 1,
        )
        if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
            Spacer(modifier = GlanceModifier.height(3.dp))
            Text(
                text = iqamahLabel(language, state.iqamahTime),
                style = TextStyle(color = palette.faint, fontSize = 11.sp),
                maxLines = 1,
            )
        }
    }
}

/** 4×2 — current prayer banner + compact full-day timetable. */
@Composable
private fun MediumWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    locale: Locale,
    language: AppLanguage,
) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(state.mosqueDisplayName, shortDateLabel(state.displayDateEpochMillis, locale), palette, 9.sp, 8.sp)
        Spacer(modifier = GlanceModifier.height(3.dp))
        CurrentPrayerBanner(state, palette, language)
        Spacer(modifier = GlanceModifier.height(3.dp))
        TimetableSection(state.rows.take(5), palette, language, compact = true)
    }
}

@Composable
private fun CurrentPrayerBanner(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    language: AppLanguage,
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = WidgetStrings.next(language).uppercase(),
                style = TextStyle(color = palette.faint, fontSize = 8.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = state.prayerName,
                style = TextStyle(color = palette.primary, fontSize = 13.sp, fontWeight = FontWeight.Bold),
                maxLines = 1,
            )
        }
        Text(
            text = state.adhanTime,
            style = TextStyle(color = palette.primary, fontSize = 22.sp, fontWeight = FontWeight.Normal),
            maxLines = 1,
        )
        if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = compactIqamahLabel(language, state.iqamahTime),
                style = TextStyle(color = palette.faint, fontSize = 9.sp),
                maxLines = 1,
            )
        }
    }
}

/** 4×4 — compact hero + full timetable that fits without clipping. */
@Composable
private fun LargeWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    locale: Locale,
    language: AppLanguage,
) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(state.mosqueDisplayName, shortDateLabel(state.displayDateEpochMillis, locale), palette, 11.sp, 10.sp)
        Spacer(modifier = GlanceModifier.defaultWeight())
        Column(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = state.prayerName,
                style = TextStyle(color = palette.secondary, fontSize = 16.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Spacer(modifier = GlanceModifier.height(4.dp))
            Text(
                text = state.adhanTime,
                style = TextStyle(color = palette.primary, fontSize = 36.sp, fontWeight = FontWeight.Normal),
                maxLines = 1,
            )
            if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(
                    text = iqamahLabel(language, state.iqamahTime),
                    style = TextStyle(color = palette.faint, fontSize = 12.sp),
                    maxLines = 1,
                )
            }
        }
        Spacer(modifier = GlanceModifier.defaultWeight())
        TimetableSection(state.rows.take(5), palette, language)
    }
}

@Composable
private fun WidgetHeader(
    title: String,
    subtitle: String,
    palette: WidgetPalette,
    titleSize: TextUnit,
    subtitleSize: TextUnit,
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = palette.faint, fontSize = titleSize, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.width(4.dp))
        Text(
            text = subtitle,
            style = TextStyle(color = palette.faint, fontSize = subtitleSize),
            maxLines = 1,
        )
    }
}

@Composable
private fun TimetableSection(
    rows: List<WidgetPrayerRow>,
    palette: WidgetPalette,
    language: AppLanguage,
    compact: Boolean = false,
) {
    val headerSize = if (compact) 8.sp else 10.sp
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                text = WidgetStrings.prayer(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = headerSize, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = WidgetStrings.adhan(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = headerSize, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = WidgetStrings.iqamah(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = headerSize, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
        }
        rows.forEach { row ->
            TimetableRow(row, palette, compact = compact)
        }
    }
}

@Composable
private fun TimetableRow(row: WidgetPrayerRow, palette: WidgetPalette, compact: Boolean = false) {
    val color = when {
        row.isNext -> palette.primary
        row.isPassed -> palette.faint
        else -> palette.secondary
    }
    val weight = if (row.isNext) FontWeight.Bold else FontWeight.Normal
    val iqamah = row.iqamahs.firstOrNull().orEmpty().ifBlank { "—" }
    val fontSize = if (compact) 10.sp else 13.sp
    val rowPadding = if (compact) 1.dp else 4.dp

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = rowPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = row.name,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = fontSize, fontWeight = weight),
            maxLines = 1,
        )
        Text(
            text = row.adhan,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = fontSize, fontWeight = weight),
            maxLines = 1,
        )
        Text(
            text = iqamah,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = fontSize, fontWeight = weight),
            maxLines = 1,
        )
    }
}

private fun iqamahLabel(language: AppLanguage, time: String): String = when (language) {
    AppLanguage.ARABIC -> "الإقامة: $time"
    AppLanguage.URDU -> "اقامت: $time"
    AppLanguage.INDONESIAN -> "Iqamah: $time"
    AppLanguage.ENGLISH -> "Iqamah: $time"
}

private fun compactIqamahLabel(language: AppLanguage, time: String): String = when (language) {
    AppLanguage.ARABIC -> "إقامة $time"
    AppLanguage.URDU -> "اقامت $time"
    AppLanguage.INDONESIAN -> "Iq. $time"
    AppLanguage.ENGLISH -> "Iq. $time"
}

private fun shortDateLabel(epochMillis: Long, locale: Locale): String {
    val instant = Instant.ofEpochMilli(epochMillis)
    return DateTimeFormatter.ofPattern("EEE d MMM", locale)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(instant)
}
