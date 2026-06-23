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
            style = TextStyle(color = palette.secondary, fontSize = 13.sp, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.height(2.dp))
        Text(
            text = state.adhanTime,
            style = TextStyle(color = palette.primary, fontSize = 26.sp, fontWeight = FontWeight.Normal),
            maxLines = 1,
        )
        if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
            Text(
                text = iqamahLabel(language, state.iqamahTime),
                style = TextStyle(color = palette.faint, fontSize = 11.sp),
                maxLines = 1,
            )
        }
    }
}

/** 4×2 — header, hero row, home-style prayer strip. */
@Composable
private fun MediumWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    locale: Locale,
    language: AppLanguage,
) {
    val rows = state.rows.take(5)
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(state.mosqueDisplayName, shortDateLabel(state.displayDateEpochMillis, locale), palette, 11.sp, 10.sp)
        Spacer(modifier = GlanceModifier.defaultWeight())
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Bottom,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = state.prayerName,
                    style = TextStyle(color = palette.secondary, fontSize = 14.sp, fontWeight = FontWeight.Medium),
                    maxLines = 1,
                )
                if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
                    Text(
                        text = iqamahLabel(language, state.iqamahTime),
                        style = TextStyle(color = palette.faint, fontSize = 10.sp),
                        maxLines = 1,
                    )
                }
            }
            Text(
                text = state.adhanTime,
                style = TextStyle(color = palette.primary, fontSize = 28.sp, fontWeight = FontWeight.Normal),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(8.dp))
        PrayerStrip(rows, palette)
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
        Spacer(modifier = GlanceModifier.height(6.dp))
        Column(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = state.prayerName,
                style = TextStyle(color = palette.secondary, fontSize = 15.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = state.adhanTime,
                style = TextStyle(color = palette.primary, fontSize = 34.sp, fontWeight = FontWeight.Normal),
                maxLines = 1,
            )
            if (state.iqamahTime.isNotBlank() && state.iqamahTime != state.adhanTime) {
                Text(
                    text = iqamahLabel(language, state.iqamahTime),
                    style = TextStyle(color = palette.faint, fontSize = 11.sp),
                    maxLines = 1,
                )
            }
        }
        Spacer(modifier = GlanceModifier.height(8.dp))
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

/** Home-style F D A M I strip with adhan times below. */
@Composable
private fun PrayerStrip(rows: List<WidgetPrayerRow>, palette: WidgetPalette) {
    Row(modifier = GlanceModifier.fillMaxWidth()) {
        rows.forEach { row ->
            Column(
                modifier = GlanceModifier.defaultWeight(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = prayerInitial(row.name),
                    style = TextStyle(
                        color = if (row.isNext) palette.primary else palette.faint,
                        fontSize = if (row.isNext) 13.sp else 11.sp,
                        fontWeight = if (row.isNext) FontWeight.Bold else FontWeight.Normal,
                    ),
                    maxLines = 1,
                )
                Text(
                    text = row.adhan,
                    style = TextStyle(
                        color = if (row.isNext) palette.primary else palette.faint,
                        fontSize = 10.sp,
                        fontWeight = if (row.isNext) FontWeight.Medium else FontWeight.Normal,
                    ),
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun TimetableSection(
    rows: List<WidgetPrayerRow>,
    palette: WidgetPalette,
    language: AppLanguage,
) {
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                text = WidgetStrings.prayer(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = 10.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = WidgetStrings.adhan(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = 10.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Text(
                text = WidgetStrings.iqamah(language),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = palette.faint, fontSize = 10.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
        }
        rows.forEach { row ->
            TimetableRow(row, palette)
        }
    }
}

@Composable
private fun TimetableRow(row: WidgetPrayerRow, palette: WidgetPalette) {
    val color = when {
        row.isNext -> palette.primary
        row.isPassed -> palette.faint
        else -> palette.secondary
    }
    val weight = if (row.isNext) FontWeight.Bold else FontWeight.Normal
    val iqamah = row.iqamahs.firstOrNull().orEmpty().ifBlank { "—" }

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = row.name,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = 13.sp, fontWeight = weight),
            maxLines = 1,
        )
        Text(
            text = row.adhan,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = 13.sp, fontWeight = weight),
            maxLines = 1,
        )
        Text(
            text = iqamah,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = color, fontSize = 13.sp, fontWeight = weight),
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

private fun prayerInitial(name: String): String {
    val trimmed = name.trim()
    if (trimmed.isEmpty()) return "?"
    return when {
        trimmed.startsWith("Jummah", ignoreCase = true) || trimmed.startsWith("Jumat", ignoreCase = true) -> "J"
        trimmed.length == 1 -> trimmed
        else -> trimmed.first().uppercaseChar().toString()
    }
}

private fun shortDateLabel(epochMillis: Long, locale: Locale): String {
    val instant = Instant.ofEpochMilli(epochMillis)
    return DateTimeFormatter.ofPattern("EEE d MMM", locale)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(instant)
}
