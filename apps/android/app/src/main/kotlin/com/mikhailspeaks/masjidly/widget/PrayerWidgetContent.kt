package com.mikhailspeaks.masjidly.widget

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
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
import com.mikhailspeaks.masjidly.widget.WidgetThemeResolver.toGlanceColorProvider
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun PrayerWidgetContent(state: WidgetPrayerState, language: AppLanguage) {
    val context = LocalContext.current
    val theme = WidgetThemeResolver.resolvedTheme(context, state.prayerId)
    val size = LocalSize.current
    val isLarge = size.height >= 200.dp
    val isSmall = size.width < 180.dp
    val textColor = theme.textColor.toGlanceColorProvider()
    val muted = ColorProvider(theme.textColor.copy(alpha = 0.75f).toArgb())
    val faint = ColorProvider(theme.textColor.copy(alpha = 0.35f).toArgb())
    val iqamahMuted = ColorProvider(theme.textColor.copy(alpha = 0.6f).toArgb())
    val background = theme.top.toGlanceColorProvider()
    val locale = language.resolvedLocale()
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
    )

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(22.dp)
            .background(background)
            .clickable(openApp)
            .padding(if (isLarge) 20.dp else if (isSmall) 16.dp else 20.dp),
        contentAlignment = Alignment.TopStart,
    ) {
        when (state.kind) {
            WidgetStateKind.MISSING, WidgetStateKind.STALE -> UnavailableWidget(
                language = language,
                textColor = textColor,
                muted = muted,
            )
            WidgetStateKind.CONTENT -> when {
                isSmall -> SmallWidget(state, textColor, muted, faint, language)
                isLarge -> LargeWidget(state, textColor, muted, faint, iqamahMuted, locale, language)
                else -> MediumWidget(state, textColor, muted, faint, iqamahMuted, locale, language)
            }
        }
    }
}

@Composable
private fun UnavailableWidget(
    language: AppLanguage,
    textColor: ColorProvider,
    muted: ColorProvider,
) {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = WidgetStrings.unavailable(language),
            style = TextStyle(color = textColor, fontSize = 14.sp, fontWeight = FontWeight.Medium),
        )
        Spacer(modifier = GlanceModifier.height(6.dp))
        Text(
            text = WidgetStrings.openApp(language),
            style = TextStyle(color = muted, fontSize = 12.sp),
        )
    }
}

@Composable
private fun SmallWidget(
    state: WidgetPrayerState,
    textColor: ColorProvider,
    muted: ColorProvider,
    faint: ColorProvider,
    language: AppLanguage,
) {
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Text(
            text = state.prayerName,
            style = TextStyle(color = muted, fontSize = 15.sp, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.height(8.dp))
        Text(
            text = state.adhanTime,
            style = TextStyle(color = textColor, fontSize = 36.sp, fontWeight = FontWeight.Normal),
            maxLines = 1,
        )
        if (state.iqamahTime.isNotBlank()) {
            Spacer(modifier = GlanceModifier.height(6.dp))
            Text(
                text = WidgetStrings.iqamahFormat(language, state.iqamahTime),
                style = TextStyle(color = faint, fontSize = 14.sp),
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun MediumWidget(
    state: WidgetPrayerState,
    textColor: ColorProvider,
    muted: ColorProvider,
    faint: ColorProvider,
    iqamahMuted: ColorProvider,
    locale: Locale,
    language: AppLanguage,
) {
    val dateLabel = mediumDateLabel(state.displayDateEpochMillis, locale)
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = state.mosqueDisplayName,
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = muted, fontSize = 13.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
            Spacer(modifier = GlanceModifier.width(4.dp))
            Text(
                text = dateLabel.uppercase(locale),
                style = TextStyle(color = faint, fontSize = 12.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(10.dp))
        PrayerTableHeader(language, faint)
        Spacer(modifier = GlanceModifier.height(6.dp))
        state.rows.take(6).forEach { row ->
            PrayerTableRow(row, textColor, faint, iqamahMuted)
            Spacer(modifier = GlanceModifier.height(6.dp))
        }
    }
}

@Composable
private fun LargeWidget(
    state: WidgetPrayerState,
    textColor: ColorProvider,
    muted: ColorProvider,
    faint: ColorProvider,
    iqamahMuted: ColorProvider,
    locale: Locale,
    language: AppLanguage,
) {
    val dateLabel = largeDateLabel(state.displayDateEpochMillis, locale)
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Text(
                text = state.mosqueDisplayName,
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(color = muted, fontSize = 16.sp, fontWeight = FontWeight.Medium),
                maxLines = 2,
            )
            Spacer(modifier = GlanceModifier.width(6.dp))
            Text(
                text = dateLabel.uppercase(locale),
                style = TextStyle(color = faint, fontSize = 13.sp, fontWeight = FontWeight.Medium),
                maxLines = 1,
            )
        }
        Spacer(modifier = GlanceModifier.height(12.dp))
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    text = state.prayerName,
                    style = TextStyle(color = muted, fontSize = 18.sp, fontWeight = FontWeight.Medium),
                    maxLines = 1,
                )
                Text(
                    text = state.adhanTime,
                    style = TextStyle(color = textColor, fontSize = 48.sp, fontWeight = FontWeight.Normal),
                    maxLines = 1,
                )
            }
            if (state.iqamahTime.isNotBlank()) {
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = WidgetStrings.iqamah(language).uppercase(locale),
                        style = TextStyle(color = faint, fontSize = 11.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1,
                    )
                    Text(
                        text = state.iqamahTime,
                        style = TextStyle(color = muted, fontSize = 22.sp),
                        maxLines = 1,
                    )
                }
            }
        }
        Spacer(modifier = GlanceModifier.height(12.dp))
        PrayerTableHeader(language, faint)
        Spacer(modifier = GlanceModifier.height(8.dp))
        state.rows.forEach { row ->
            PrayerTableRow(row, textColor, faint, iqamahMuted, large = true)
            Spacer(modifier = GlanceModifier.height(if (row == state.rows.last()) 0.dp else 14.dp))
        }
    }
}

@Composable
private fun PrayerTableHeader(language: AppLanguage, faint: ColorProvider) {
    Row(modifier = GlanceModifier.fillMaxWidth()) {
        Text(
            text = WidgetStrings.prayer(language).uppercase(),
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = faint, fontSize = 11.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        Text(
            text = WidgetStrings.adhan(language).uppercase(),
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = faint, fontSize = 11.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        Text(
            text = WidgetStrings.iqamah(language).uppercase(),
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = faint, fontSize = 11.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
    }
}

@Composable
private fun PrayerTableRow(
    row: WidgetPrayerRow,
    textColor: ColorProvider,
    faint: ColorProvider,
    iqamahMuted: ColorProvider,
    large: Boolean = false,
) {
    val nameColor = if (row.isPassed) faint else textColor
    val timeWeight = if (row.isNext) FontWeight.Bold else if (row.isPassed) FontWeight.Normal else FontWeight.Medium
    val fontSize = if (large) 24.sp else 20.sp
    Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = row.name,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = nameColor, fontSize = fontSize, fontWeight = timeWeight),
            maxLines = 1,
        )
        Text(
            text = row.adhan,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = nameColor, fontSize = fontSize, fontWeight = timeWeight),
            maxLines = 1,
        )
        Text(
            text = row.iqamahs.joinToString(", "),
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = if (row.isPassed) faint else iqamahMuted, fontSize = fontSize),
            maxLines = 1,
        )
    }
}

private fun mediumDateLabel(epochMillis: Long, locale: Locale): String {
    val instant = Instant.ofEpochMilli(epochMillis)
    return DateTimeFormatter.ofPattern("EEEE · d MMM", locale)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(instant)
}

private fun largeDateLabel(epochMillis: Long, locale: Locale): String {
    val instant = Instant.ofEpochMilli(epochMillis)
    return DateTimeFormatter.ofPattern("MMMM, EEEE d", locale)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(instant)
}
