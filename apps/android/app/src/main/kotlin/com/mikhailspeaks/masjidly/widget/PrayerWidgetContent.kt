package com.mikhailspeaks.masjidly.widget

import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.LocalSize
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
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.mikhailspeaks.masjidly.MainActivity
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun PrayerWidgetContent(
    state: WidgetPrayerState,
    language: AppLanguage,
    family: MasjidlyWidgetFamily,
    now: Instant = Instant.now(),
) {
    val context = LocalContext.current
    val appearance = WidgetThemeResolver.resolvedAppearance(context, state.prayerId)
    val palette = WidgetPalette.from(appearance)
    val locale = language.resolvedLocale()
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
    )

    WidgetSkyBackground(appearance = appearance, family = family, onClick = openApp) {
        when (state.kind) {
            WidgetStateKind.MISSING, WidgetStateKind.STALE -> UnavailableWidget(language, palette)
            WidgetStateKind.CONTENT -> when (family) {
                MasjidlyWidgetFamily.SMALL -> SmallWidget(state, palette, language)
                MasjidlyWidgetFamily.MEDIUM -> MediumWidget(state, palette, appearance, locale, language, now)
                MasjidlyWidgetFamily.LARGE -> LargeWidget(state, palette, appearance, locale, language, now)
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
        fun from(appearance: ResolvedTheme): WidgetPalette {
            val text = appearance.textColor
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

/** 2×2 — compact 5-prayer timetable (adhan + iqamah). */
@Composable
private fun SmallWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    language: AppLanguage,
) {
    SmallTimetableSection(
        rows = state.rows.take(5),
        palette = palette,
        language = language,
        modifier = GlanceModifier.fillMaxSize(),
    )
}

@Composable
private fun SmallTimetableSection(
    rows: List<WidgetPrayerRow>,
    palette: WidgetPalette,
    language: AppLanguage,
    modifier: GlanceModifier = GlanceModifier,
) {
    val headerStyle = TextStyle(
        color = palette.faint,
        fontSize = smallTimetableHeaderSize(),
        fontWeight = FontWeight.Bold,
    )
    val rowFontSize = smallTimetableRowSize()
    Column(modifier = modifier) {
        TimetableHeaderRow(language, headerStyle, compact = true, uppercase = true, small = true)
        rows.forEach { row ->
            Box(
                modifier = GlanceModifier
                    .defaultWeight()
                    .fillMaxWidth(),
                contentAlignment = Alignment.CenterStart,
            ) {
                TimetableRow(
                    row = row,
                    palette = palette,
                    small = true,
                    smallFontSize = rowFontSize,
                )
            }
        }
    }
}

@Composable
private fun smallTimetableHeaderSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 7.sp
    LocalSize.current.height >= 130.dp -> 6.sp
    else -> 6.sp
}

@Composable
private fun smallTimetableRowSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 9.sp
    LocalSize.current.height >= 130.dp -> 8.sp
    else -> 8.sp
}

/** 4×2 — large-style vertical stack: header, hero, full-width timetable. */
@Composable
private fun MediumWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    appearance: ResolvedTheme,
    locale: Locale,
    language: AppLanguage,
    now: Instant,
) {
    val rows = state.rows.take(5)
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(
            title = state.mosqueDisplayName,
            subtitle = shortDateLabel(state.displayDateEpochMillis, locale),
            palette = palette,
            titleSize = mediumHeaderTitleSize(),
            subtitleSize = mediumHeaderSubtitleSize(),
            titleColor = palette.secondary,
            subtitleColor = palette.faint,
            titleDateGap = 6.dp,
        )
        WidgetHero(
            state = state,
            palette = palette,
            appearance = appearance,
            language = language,
            now = now,
            style = mediumHeroStyle(),
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(top = MEDIUM_WIDGET_SECTION_SPACING),
        )
        MediumTimetableSection(
            rows = rows,
            palette = palette,
            language = language,
            modifier = GlanceModifier
                .defaultWeight()
                .fillMaxWidth()
                .padding(top = MEDIUM_WIDGET_SECTION_SPACING),
        )
    }
}

private val MEDIUM_WIDGET_SECTION_SPACING = 4.dp

@Composable
private fun mediumHeaderTitleSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 13.sp
    LocalSize.current.height >= 130.dp -> 12.sp
    else -> 11.sp
}

@Composable
private fun mediumHeaderSubtitleSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 11.sp
    LocalSize.current.height >= 130.dp -> 10.sp
    else -> 9.sp
}

@Composable
private fun mediumHeroStyle(): WidgetHeroStyle = when {
    LocalSize.current.height >= 160.dp -> WidgetHeroStyle(
        headlineSize = 11.sp,
        countdownSize = 22.sp,
        staticTimeSize = 20.sp,
        verticalPadding = 4.dp,
        headlineGap = 3.dp,
    )
    LocalSize.current.height >= 130.dp -> WidgetHeroStyle(
        headlineSize = 10.sp,
        countdownSize = 20.sp,
        staticTimeSize = 18.sp,
        verticalPadding = 3.dp,
        headlineGap = 2.dp,
    )
    else -> WidgetHeroStyle(
        headlineSize = 10.sp,
        countdownSize = 18.sp,
        staticTimeSize = 16.sp,
        verticalPadding = 2.dp,
        headlineGap = 2.dp,
    )
}

@Composable
private fun mediumTimetableHeaderSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 9.sp
    LocalSize.current.height >= 130.dp -> 8.sp
    else -> 8.sp
}

@Composable
private fun mediumTimetableRowSize(): TextUnit = when {
    LocalSize.current.height >= 160.dp -> 12.sp
    LocalSize.current.height >= 130.dp -> 11.sp
    else -> 10.sp
}

/** 4×4 — hero + full timetable; compact spacing to fit 250dp and stay under RemoteViews limits. */
@Composable
private fun LargeWidget(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    appearance: ResolvedTheme,
    locale: Locale,
    language: AppLanguage,
    now: Instant,
) {
    val rows = state.rows.take(5)
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(
            title = state.mosqueDisplayName,
            subtitle = shortDateLabel(state.displayDateEpochMillis, locale),
            palette = palette,
            titleSize = 13.sp,
            subtitleSize = 11.sp,
            titleColor = palette.secondary,
            titleDateGap = 8.dp,
        )
        WidgetHero(
            state = state,
            palette = palette,
            appearance = appearance,
            language = language,
            now = now,
            style = LARGE_HERO_STYLE,
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(top = LARGE_WIDGET_SECTION_SPACING),
        )
        LargeTimetableSection(
            rows = rows,
            palette = palette,
            language = language,
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(top = LARGE_WIDGET_SECTION_SPACING),
        )
    }
}

private val LARGE_WIDGET_SECTION_SPACING = 8.dp
private val LARGE_WIDGET_ROW_SPACING = 6.dp
private val LARGE_HERO_STYLE = WidgetHeroStyle(
    headlineSize = 13.sp,
    countdownSize = 30.sp,
    staticTimeSize = 28.sp,
    verticalPadding = 8.dp,
    headlineGap = 4.dp,
)

@Composable
private fun MediumTimetableSection(
    rows: List<WidgetPrayerRow>,
    palette: WidgetPalette,
    language: AppLanguage,
    modifier: GlanceModifier = GlanceModifier,
) {
    val headerStyle = TextStyle(
        color = palette.faint,
        fontSize = mediumTimetableHeaderSize(),
        fontWeight = FontWeight.Bold,
    )
    val rowFontSize = mediumTimetableRowSize()
    Column(modifier = modifier) {
        TimetableHeaderRow(language, headerStyle, compact = false, uppercase = true)
        rows.forEach { row ->
            Box(
                modifier = GlanceModifier
                    .defaultWeight()
                    .fillMaxWidth(),
                contentAlignment = Alignment.CenterStart,
            ) {
                TimetableRow(
                    row = row,
                    palette = palette,
                    medium = true,
                    mediumFontSize = rowFontSize,
                )
            }
        }
    }
}

@Composable
private fun LargeTimetableSection(
    rows: List<WidgetPrayerRow>,
    palette: WidgetPalette,
    language: AppLanguage,
    modifier: GlanceModifier = GlanceModifier,
) {
    val headerStyle = TextStyle(
        color = palette.faint,
        fontSize = 10.sp,
        fontWeight = FontWeight.Bold,
    )
    Column(modifier = modifier) {
        TimetableHeaderRow(language, headerStyle, compact = false, uppercase = true)
        rows.getOrNull(0)?.let {
            TimetableRow(it, palette, large = true, topPadding = LARGE_WIDGET_SECTION_SPACING)
        }
        rows.getOrNull(1)?.let {
            TimetableRow(it, palette, large = true, topPadding = LARGE_WIDGET_ROW_SPACING)
        }
        rows.getOrNull(2)?.let {
            TimetableRow(it, palette, large = true, topPadding = LARGE_WIDGET_ROW_SPACING)
        }
        rows.getOrNull(3)?.let {
            TimetableRow(it, palette, large = true, topPadding = LARGE_WIDGET_ROW_SPACING)
        }
        rows.getOrNull(4)?.let {
            TimetableRow(it, palette, large = true, topPadding = LARGE_WIDGET_ROW_SPACING)
        }
    }
}

private data class WidgetHeroStyle(
    val headlineSize: TextUnit,
    val countdownSize: TextUnit,
    val staticTimeSize: TextUnit,
    val verticalPadding: Dp,
    val headlineGap: Dp,
    val headlineMaxLines: Int = 1,
)

@Composable
private fun WidgetHero(
    state: WidgetPrayerState,
    palette: WidgetPalette,
    appearance: ResolvedTheme,
    language: AppLanguage,
    now: Instant,
    style: WidgetHeroStyle,
    fillWidth: Boolean = true,
    modifier: GlanceModifier = GlanceModifier,
) {
    val countdown = widgetCountdownDisplay(state, now)
    val headline = WidgetStrings.countdownHeadline(language, state.prayerName, state.countdownLabelKind)
    val widthModifier = if (fillWidth) GlanceModifier.fillMaxWidth() else GlanceModifier

    Column(
        modifier = modifier
            .then(widthModifier)
            .padding(vertical = style.verticalPadding),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = headline,
            modifier = widthModifier,
            style = TextStyle(
                color = palette.secondary,
                fontSize = style.headlineSize,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
            maxLines = style.headlineMaxLines,
        )
        Spacer(modifier = GlanceModifier.height(style.headlineGap))
        if (countdown.showCountdown && countdown.targetEpochMillis != null) {
            WidgetCountdownChronometer(
                targetEpochMillis = countdown.targetEpochMillis,
                appearance = appearance,
                textSize = style.countdownSize,
                centered = true,
                modifier = widthModifier,
            )
        } else {
            Text(
                text = countdown.primaryTimeText,
                modifier = widthModifier,
                style = TextStyle(
                    color = palette.primary,
                    fontSize = style.staticTimeSize,
                    fontWeight = FontWeight.Normal,
                    textAlign = TextAlign.Center,
                ),
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun WidgetHeader(
    title: String,
    subtitle: String,
    palette: WidgetPalette,
    titleSize: TextUnit,
    subtitleSize: TextUnit,
    titleColor: ColorProvider = palette.faint,
    subtitleColor: ColorProvider = palette.faint,
    titleDateGap: Dp = 4.dp,
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = titleColor, fontSize = titleSize, fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.width(titleDateGap))
        Text(
            text = subtitle,
            style = TextStyle(color = subtitleColor, fontSize = subtitleSize),
            maxLines = 1,
        )
    }
}


@Composable
private fun TimetableHeaderRow(
    language: AppLanguage,
    style: TextStyle,
    compact: Boolean,
    uppercase: Boolean = false,
    small: Boolean = false,
) {
    fun label(text: String) = if (uppercase) text.uppercase() else text
    val prayerHeader = if (small) "" else WidgetStrings.prayer(language)
    val adhanHeader = if (small) WidgetStrings.adhanShort(language) else WidgetStrings.adhan(language)
    val iqamahHeader = if (small) WidgetStrings.iqamahShort(language) else WidgetStrings.iqamah(language)
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label(prayerHeader),
            modifier = GlanceModifier.defaultWeight(),
            style = style.copy(textAlign = TextAlign.Start),
            maxLines = 1,
        )
        Text(
            text = label(adhanHeader),
            modifier = GlanceModifier.defaultWeight(),
            style = style.copy(textAlign = TextAlign.Center),
            maxLines = 1,
        )
        Text(
            text = label(iqamahHeader),
            modifier = GlanceModifier.defaultWeight(),
            style = style.copy(textAlign = TextAlign.End),
            maxLines = 1,
        )
    }
}

@Composable
private fun TimetableRow(
    row: WidgetPrayerRow,
    palette: WidgetPalette,
    small: Boolean = false,
    smallFontSize: TextUnit = 8.sp,
    medium: Boolean = false,
    mediumFontSize: TextUnit = 11.sp,
    large: Boolean = false,
    topPadding: Dp = 0.dp,
) {
    val color = when {
        row.isNext -> palette.primary
        row.isPassed -> palette.faint
        else -> palette.secondary
    }
    val weight = if (row.isNext) FontWeight.Bold else FontWeight.Normal
    val adhanWeight = when {
        row.isNext -> FontWeight.Bold
        large || medium -> FontWeight.Medium
        else -> FontWeight.Normal
    }
    val iqamahColor = when {
        row.isNext -> palette.secondary
        row.isPassed -> palette.faint
        else -> palette.secondary
    }
    val iqamah = row.iqamahs.filter { it.isNotBlank() }.joinToString(", ").ifBlank { "—" }
    val fontSize = when {
        small -> smallFontSize
        medium -> mediumFontSize
        large -> 12.sp
        else -> 12.sp
    }
    val rowPadding = 0.dp
    val rowStyle = TextStyle(color = color, fontSize = fontSize, fontWeight = weight)
    val adhanStyle = TextStyle(color = color, fontSize = fontSize, fontWeight = adhanWeight)
    val iqamahStyle = TextStyle(
        color = iqamahColor,
        fontSize = fontSize,
        fontWeight = if (row.isNext) FontWeight.Bold else FontWeight.Normal,
    )

    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(top = topPadding)
            .padding(vertical = rowPadding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (small) compactPrayerLabel(row.name) else row.name,
            modifier = GlanceModifier.defaultWeight(),
            style = rowStyle.copy(textAlign = TextAlign.Start),
            maxLines = 1,
        )
        Text(
            text = row.adhan,
            modifier = GlanceModifier.defaultWeight(),
            style = adhanStyle.copy(textAlign = TextAlign.Center),
            maxLines = 1,
        )
        Text(
            text = if (small) compactIqamahLabel(iqamah) else iqamah,
            modifier = GlanceModifier.defaultWeight(),
            style = iqamahStyle.copy(textAlign = TextAlign.End),
            maxLines = 1,
        )
    }
}

private fun compactPrayerLabel(name: String): String = when (name.lowercase(Locale.ROOT)) {
    "jummah", "jumuah" -> "Jumu"
    "maghrib" -> "Magh"
    "dhuhr", "zuhr" -> "Dhuhr"
    else -> name
}

/** Short iqamah strings for the narrow small-widget column. */
private fun compactIqamahLabel(iqamah: String): String {
    if (iqamah == "—") return iqamah
    val afterPrefix = Regex("^After\\s+", RegexOption.IGNORE_CASE)
    if (afterPrefix.containsMatchIn(iqamah)) {
        val prayer = afterPrefix.replace(iqamah, "").trim()
        val shortPrayer = when (prayer.lowercase(Locale.ROOT)) {
            "maghrib" -> "Magh"
            "isha" -> "Isha"
            "asr" -> "Asr"
            "fajr" -> "Fajr"
            "dhuhr", "zuhr" -> "Dhuhr"
            else -> prayer.take(4)
        }
        return "Aft $shortPrayer"
    }
    return iqamah
}

private fun shortDateLabel(epochMillis: Long, locale: Locale): String {
    val instant = Instant.ofEpochMilli(epochMillis)
    return DateTimeFormatter.ofPattern("EEE d MMM", locale)
        .withZone(PrayerTimesEngine.sheffieldTimeZone)
        .format(instant)
}
