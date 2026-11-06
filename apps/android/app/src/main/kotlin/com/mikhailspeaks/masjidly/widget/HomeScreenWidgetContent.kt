package com.mikhailspeaks.masjidly.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Canvas as ComposeCanvas
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.mikhailspeaks.masjidly.MainActivity
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.home.drawPrayerSunPhase
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max

/** One prayer line for the home designs. Friday Jummah rows fold back into Dhuhr, like iOS. */
internal data class HomeScreenRow(
    val prayerId: String,
    val name: String,
    val adhan: String,
    val iqamah: String,
    val isNext: Boolean,
)

internal class HomeScreenModel(
    val state: WidgetPrayerState,
    val language: AppLanguage,
    val nowMillis: Long,
) {
    val rows: List<HomeScreenRow> = buildList {
        for (row in state.rows) {
            val isJummah = row.id.startsWith("jummah")
            val iqamah = row.iqamahs.joinToString(", ")
            val last = lastOrNull()
            if (isJummah && last != null && last.prayerId == "dhuhr") {
                set(lastIndex, last.copy(iqamah = last.iqamah + ", " + iqamah, isNext = last.isNext || row.isNext))
                continue
            }
            add(
                HomeScreenRow(
                    prayerId = if (isJummah) "dhuhr" else row.id,
                    name = if (isJummah) row.name.replace(Regex("""\s*\d+$"""), "") else row.name,
                    adhan = row.adhan,
                    iqamah = iqamah,
                    isNext = row.isNext,
                ),
            )
        }
    }

    val isIqamah: Boolean = state.countdownLabelKind == HeroCountdownLabelKind.IQAMAH_IN

    val remainingMillis: Long? = state.targetDateEpochMillis?.let { it - nowMillis }?.takeIf { it > 0 }

    val progress: Float
        get() {
            val start = state.progressStartEpochMillis ?: return 0f
            val end = state.targetDateEpochMillis ?: return 0f
            if (end <= start) return 0f
            return ((nowMillis - start).toFloat() / (end - start).toFloat()).coerceIn(0f, 1f)
        }

    val timeTheme: TimeTheme get() = TimeTheme.fromWire(state.prayerId)

    /** "25m", "1h 05m" or "<1m". */
    val abbreviatedRemaining: String
        get() {
            val minutes = ((remainingMillis ?: 0L) / 60_000L).toInt()
            val minute = WidgetStrings.minuteUnit(language)
            val hour = WidgetStrings.hourUnit(language)
            return when {
                minutes >= 60 -> "${minutes / 60}$hour ${"%02d".format(minutes % 60)}$minute"
                minutes > 0 -> "$minutes$minute"
                else -> "<1$minute"
            }
        }

    /** "adhan in 5m" or "iqamah in 5m". */
    val countdownPhrase: String
        get() {
            val event = (if (isIqamah) WidgetStrings.iqamah(language) else WidgetStrings.adhan(language)).lowercase()
            return "$event " + WidgetStrings.inFormat(language).format(abbreviatedRemaining)
        }

    val dateText: String
        get() = DateTimeFormatter.ofPattern("EEEE · d MMM", language.resolvedLocale())
            .withZone(ZoneId.of("Europe/London"))
            .format(Instant.ofEpochMilli(state.displayDateEpochMillis))
            .uppercase()
}

/** Splits "5:40AM" into ("5:40", "AM"). Only the first of several comma separated times is used. */
internal fun homeTimeParts(raw: String): LockScreenTime =
    LockScreenTime.parse(raw.substringBefore(",").trim())

private class HomePalette(appearance: ResolvedTheme) {
    val ink = appearance.textColor
    val primary = ColorProvider(ink)
    val secondary = ColorProvider(ink.copy(alpha = 0.7f))
    val faint = ColorProvider(ink.copy(alpha = 0.55f))
    val highlight = ColorProvider(ink.copy(alpha = 0.16f))
}

private fun style(color: ColorProvider, size: Float, weight: FontWeight = FontWeight.Normal, align: TextAlign? = null) =
    TextStyle(color = color, fontSize = size.sp, fontWeight = weight, textAlign = align)

@Composable
internal fun HomeScreenWidgetContent(model: HomeScreenModel, design: HomeScreenDesign) {
    val context = LocalContext.current
    val appearance = WidgetThemeResolver.resolvedAppearance(context, model.state.prayerId)
    val palette = HomePalette(appearance)
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
    )
    val padding = when (design) {
        HomeScreenDesign.CARD -> GlanceModifier.padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 12.dp)
        HomeScreenDesign.ROW -> GlanceModifier.padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 8.dp)
        HomeScreenDesign.SMALL -> GlanceModifier.padding(start = 14.dp, end = 14.dp, top = 14.dp, bottom = 12.dp)
    }
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(if (design == HomeScreenDesign.SMALL) 16.dp else 20.dp)
            .background(skyBackgroundImageProvider(appearance))
            .clickable(openApp)
            .then(padding),
    ) {
        if (model.state.kind != WidgetStateKind.CONTENT) {
            Unavailable(model, palette)
        } else {
            when (design) {
                HomeScreenDesign.CARD -> CardDesign(model, palette, appearance)
                HomeScreenDesign.ROW -> RowDesign(model, palette, appearance)
                HomeScreenDesign.SMALL -> SmallDesign(model, palette, appearance)
            }
        }
    }
}

@Composable
private fun Unavailable(model: HomeScreenModel, palette: HomePalette) {
    Column(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(WidgetStrings.unavailable(model.language), style = style(palette.primary, 14f, FontWeight.Medium), maxLines = 2)
        Spacer(GlanceModifier.height(4.dp))
        Text(WidgetStrings.openApp(model.language), style = style(palette.faint, 11f), maxLines = 1)
    }
}

// Shared pieces

/** A time with a small AM/PM beside it when the app uses 12 hour time. */
@Composable
private fun HomeTime(
    raw: String,
    clockSize: Float,
    meridiemSize: Float,
    color: ColorProvider,
    weight: FontWeight = FontWeight.Normal,
    modifier: GlanceModifier = GlanceModifier,
    allTimes: Boolean = false,
) {
    if (allTimes && raw.contains(',')) {
        // Several congregations (Friday Jummah): keep every time, in a smaller size so the column fits.
        Text(raw, style = style(color, clockSize * 0.72f, weight, TextAlign.End), maxLines = 2, modifier = modifier)
        return
    }
    val parts = homeTimeParts(raw)
    Row(modifier = modifier, verticalAlignment = Alignment.Bottom) {
        Text(parts.clock, style = style(color, clockSize, weight), maxLines = 1)
        if (parts.meridiem.isNotEmpty()) {
            Text(" " + parts.meridiem, style = style(color, meridiemSize), maxLines = 1)
        }
    }
}

/** Live countdown as a native chronometer so it ticks without widget updates. */
@Composable
private fun HomeCountdown(model: HomeScreenModel, color: Color, sizeSp: Float) {
    val context = LocalContext.current
    val target = model.state.targetDateEpochMillis
    val remaining = model.remainingMillis
    if (target == null || remaining == null) {
        val parts = homeTimeParts(model.state.adhanTime)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(parts.clock, style = style(ColorProvider(color), sizeSp, FontWeight.Normal), maxLines = 1)
            if (parts.meridiem.isNotEmpty()) {
                Text(" " + parts.meridiem, style = style(ColorProvider(color), sizeSp * 0.34f), maxLines = 1)
            }
        }
        return
    }
    val views = RemoteViews(context.packageName, R.layout.widget_home_chronometer).apply {
        setChronometerCountDown(R.id.widget_home_countdown, true)
        setChronometer(R.id.widget_home_countdown, SystemClock.elapsedRealtime() + remaining, null, true)
        setTextColor(R.id.widget_home_countdown, color.toArgb())
        setTextViewTextSize(R.id.widget_home_countdown, TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }
    AndroidRemoteViews(remoteViews = views)
}

@Composable
private fun RingImage(
    model: HomeScreenModel,
    appearance: ResolvedTheme,
    size: Dp,
    lineWidth: Dp,
    prayerTheme: TimeTheme = model.timeTheme,
    showsIcon: Boolean = true,
    showsRing: Boolean = true,
) {
    val context = LocalContext.current
    Image(
        provider = ImageProvider(
            ringBitmap(context, size, lineWidth, model.progress, appearance.textColor, prayerTheme, showsIcon, showsRing),
        ),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = GlanceModifier.size(size),
    )
}

// Large card

@Composable
private fun CardDesign(model: HomeScreenModel, palette: HomePalette, appearance: ResolvedTheme) {
    val language = model.language
    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                model.state.mosqueDisplayName,
                style = style(palette.primary, 17f, FontWeight.Medium),
                maxLines = 1,
                modifier = GlanceModifier.defaultWeight(),
            )
            Text(model.dateText, style = style(palette.faint, 11f, FontWeight.Medium), maxLines = 1)
        }
        Spacer(GlanceModifier.height(8.dp))
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            RingImage(model, appearance, size = 72.dp, lineWidth = 3.dp)
            Spacer(GlanceModifier.width(12.dp))
            Column {
                Text(
                    WidgetStrings.countdownHeadline(language, model.state.prayerName, model.state.countdownLabelKind),
                    style = style(palette.secondary, 14f),
                    maxLines = 1,
                )
                HomeCountdown(model, palette.ink, sizeSp = 46f)
            }
        }
        Spacer(GlanceModifier.height(8.dp))
        Box(modifier = GlanceModifier.fillMaxWidth().height(1.dp).background(ColorProvider(palette.ink.copy(alpha = 0.18f)))) {}
        Spacer(GlanceModifier.height(6.dp))
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Spacer(GlanceModifier.defaultWeight())
            Text(
                WidgetStrings.adhan(language).uppercase(),
                style = style(palette.secondary, 10f, FontWeight.Medium, TextAlign.End),
                maxLines = 1,
                modifier = GlanceModifier.width(ADHAN_COLUMN),
            )
            Text(
                WidgetStrings.iqamah(language).uppercase(),
                style = style(palette.secondary, 10f, FontWeight.Medium, TextAlign.End),
                maxLines = 1,
                modifier = GlanceModifier.width(IQAMAH_COLUMN),
            )
        }
        Column(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            model.rows.forEach { row -> CardPrayerRow(row, model, palette, appearance) }
        }
    }
}

private val ADHAN_COLUMN = 88.dp
private val IQAMAH_COLUMN = 82.dp

@Composable
private fun androidx.glance.layout.ColumnScope.CardPrayerRow(
    row: HomeScreenRow,
    model: HomeScreenModel,
    palette: HomePalette,
    appearance: ResolvedTheme,
) {
    // The time being counted down to is the strong one: iqamah once the adhan has passed.
    val iqamahDue = row.isNext && model.isIqamah
    val highlight = if (row.isNext) {
        GlanceModifier.background(palette.highlight).cornerRadius(14.dp)
    } else {
        GlanceModifier
    }
    Row(
        modifier = GlanceModifier.fillMaxWidth().defaultWeight().then(highlight).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RowIcon(row.prayerId, appearance, size = 28.dp)
        Spacer(GlanceModifier.width(10.dp))
        Text(
            row.name,
            style = style(palette.primary, 17f, if (row.isNext) FontWeight.Bold else FontWeight.Normal),
            maxLines = 1,
            modifier = GlanceModifier.defaultWeight(),
        )
        Box(modifier = GlanceModifier.width(ADHAN_COLUMN), contentAlignment = Alignment.CenterEnd) {
            HomeTime(
                row.adhan, 17f, 10f,
                color = if (iqamahDue) ColorProvider(palette.ink.copy(alpha = 0.85f)) else palette.primary,
                weight = if (row.isNext && !iqamahDue) FontWeight.Bold else FontWeight.Normal,
            )
        }
        Box(modifier = GlanceModifier.width(IQAMAH_COLUMN), contentAlignment = Alignment.CenterEnd) {
            HomeTime(
                row.iqamah, 15f, 9f,
                color = if (iqamahDue) palette.primary else ColorProvider(palette.ink.copy(alpha = 0.85f)),
                weight = if (iqamahDue) FontWeight.Bold else FontWeight.Normal,
                allTimes = true,
            )
        }
    }
}

@Composable
private fun RowIcon(prayerId: String, appearance: ResolvedTheme, size: Dp) {
    val context = LocalContext.current
    Image(
        provider = ImageProvider(
            ringBitmap(context, size, 0.dp, 0f, appearance.textColor, TimeTheme.fromWire(prayerId), showsIcon = true, showsRing = false),
        ),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = GlanceModifier.size(size),
    )
}

// Medium row

@Composable
private fun RowDesign(model: HomeScreenModel, palette: HomePalette, appearance: ResolvedTheme) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = GlanceModifier.size(8.dp).cornerRadius(4.dp).background(palette.primary)) {}
            Spacer(GlanceModifier.width(6.dp))
            Text(model.state.prayerName, style = style(palette.primary, 17f, FontWeight.Bold), maxLines = 1)
            if (model.remainingMillis != null) {
                Spacer(GlanceModifier.width(6.dp))
                Text(model.countdownPhrase, style = style(palette.secondary, 14f), maxLines = 1, modifier = GlanceModifier.defaultWeight())
            } else {
                Spacer(GlanceModifier.defaultWeight())
            }
            Text(model.state.mosqueDisplayName, style = style(palette.faint, 12f, FontWeight.Medium), maxLines = 1)
        }
        Spacer(GlanceModifier.height(6.dp))
        Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
            model.rows.take(5).forEach { row ->
                RowColumn(row, model, palette, appearance)
            }
        }
    }
}

@Composable
private fun androidx.glance.layout.RowScope.RowColumn(
    row: HomeScreenRow,
    model: HomeScreenModel,
    palette: HomePalette,
    appearance: ResolvedTheme,
) {
    val iqamahDue = row.isNext && model.isIqamah
    val highlight = if (row.isNext) GlanceModifier.background(palette.highlight).cornerRadius(14.dp) else GlanceModifier
    val isCurrent = row.prayerId == model.state.prayerId
    Column(
        modifier = GlanceModifier.defaultWeight().then(highlight).padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (isCurrent) {
            RingImage(model, appearance, size = 46.dp, lineWidth = 2.5.dp, prayerTheme = TimeTheme.fromWire(row.prayerId))
        } else {
            RowIcon(row.prayerId, appearance, size = 46.dp)
        }
        Spacer(GlanceModifier.height(3.dp))
        Text(
            row.name,
            style = style(palette.primary, 14f, if (row.isNext) FontWeight.Bold else FontWeight.Normal, TextAlign.Center),
            maxLines = 1,
        )
        HomeTime(
            row.adhan, 18f, 9f,
            color = if (iqamahDue) ColorProvider(palette.ink.copy(alpha = 0.65f)) else palette.primary,
            weight = if (row.isNext && !iqamahDue) FontWeight.Bold else FontWeight.Normal,
        )
        HomeTime(
            row.iqamah, 14f, 8f,
            color = if (iqamahDue) palette.primary else ColorProvider(palette.ink.copy(alpha = 0.65f)),
            weight = if (iqamahDue) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

// Small card

@Composable
private fun SmallDesign(model: HomeScreenModel, palette: HomePalette, appearance: ResolvedTheme) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            RingImage(model, appearance, size = 38.dp, lineWidth = 2.5.dp)
            Spacer(GlanceModifier.width(8.dp))
            Column {
                Text(model.state.prayerName, style = style(palette.primary, 17f), maxLines = 1)
                if (model.remainingMillis != null) {
                    Text(
                        WidgetStrings.inFormat(model.language).format(model.abbreviatedRemaining),
                        style = style(palette.secondary, 12f),
                        maxLines = 1,
                    )
                }
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        Box(modifier = GlanceModifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            HomeTime(model.state.adhanTime, 36f, 11f, palette.primary)
        }
        Spacer(GlanceModifier.defaultWeight())
        if (model.state.iqamahTime.isNotEmpty()) {
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(palette.highlight)
                    .cornerRadius(12.dp)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(WidgetStrings.iqamah(model.language), style = style(palette.secondary, 12f), maxLines = 1)
                Spacer(GlanceModifier.defaultWeight())
                HomeTime(model.state.iqamahTime, 14f, 9f, palette.primary)
            }
        }
    }
}

// Bitmaps. Glance has no stroked shapes, so the ring and the sun phase art are drawn.

private fun Context.px(dp: Float): Float = dp * resources.displayMetrics.density

/** Ring plus the sun phase icon centred inside, or either on its own. */
private fun ringBitmap(
    context: Context,
    size: Dp,
    lineWidth: Dp,
    progress: Float,
    ink: Color,
    theme: TimeTheme,
    showsIcon: Boolean,
    showsRing: Boolean,
): Bitmap {
    val side = max(1, context.px(size.value).toInt())
    val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val stroke = context.px(lineWidth.value)
    if (showsRing) {
        val inset = stroke / 2f
        val oval = RectF(inset, inset, side - inset, side - inset)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = stroke; color = ink.copy(alpha = 0.18f).toArgb()
        }
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND; color = ink.toArgb()
        }
        canvas.drawArc(oval, 0f, 360f, false, track)
        canvas.drawArc(oval, -90f, 360f * max(0.02f, progress), false, arc)
    }
    if (showsIcon) {
        val icon = sunPhaseBitmap(context, theme, ink)
        val inner = side - stroke * 2f
        val width = inner * 0.92f
        val height = width * 88f / 100f
        val left = (side - width) / 2f
        val top = (side - height) / 2f
        canvas.drawBitmap(icon, null, RectF(left, top, left + width, top + height), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
    }
    return bitmap
}

/** The app's sun phase line art rendered on its 100x88 dp reference canvas. */
private fun sunPhaseBitmap(context: Context, theme: TimeTheme, ink: Color): Bitmap {
    val density = context.resources.displayMetrics.density
    val width = (100f * density).toInt()
    val height = (88f * density).toInt()
    val image = ImageBitmap(width, height)
    CanvasDrawScope().draw(Density(density), LayoutDirection.Ltr, ComposeCanvas(image), Size(width.toFloat(), height.toFloat())) {
        drawPrayerSunPhase(theme, ink)
    }
    return image.asAndroidBitmap()
}
