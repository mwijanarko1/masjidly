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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.action.clickable
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
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/** Everything the six designs read, derived once from the resolved widget state. */
internal class LockScreenModel(
    val state: WidgetPrayerState,
    val language: AppLanguage,
    val nowMillis: Long,
) {
    val isIqamah: Boolean = state.countdownLabelKind == HeroCountdownLabelKind.IQAMAH_IN
    val adhan: LockScreenTime = LockScreenTime.parse(state.adhanTime)
    val iqamah: LockScreenTime = LockScreenTime.parse(lockIqamahLabel(state.iqamahTime))

    val remainingMillis: Long? = state.targetDateEpochMillis
        ?.let { it - nowMillis }
        ?.takeIf { it > 0 }

    val progress: Float
        get() {
            val start = state.progressStartEpochMillis ?: return 0f
            val end = state.targetDateEpochMillis ?: return 0f
            if (end <= start) return 0f
            return ((nowMillis - start).toFloat() / (end - start).toFloat()).coerceIn(0f, 1f)
        }

    val minuteUnit: String get() = WidgetStrings.minuteUnit(language)

    /** "25m", "1h 05m" or "<1m". */
    val abbreviatedRemaining: String
        get() {
            val minutes = ((remainingMillis ?: 0L) / 60_000L).toInt()
            val hour = WidgetStrings.hourUnit(language)
            return when {
                minutes >= 60 -> "${minutes / 60}$hour ${"%02d".format(minutes % 60)}$minuteUnit"
                minutes > 0 -> "$minutes$minuteUnit"
                else -> "<1$minuteUnit"
            }
        }

    /** Short prayer code for the circular widgets. Arabic and Urdu keep the full name. */
    val code: String
        get() {
            if (language == AppLanguage.ARABIC || language == AppLanguage.URDU) return state.prayerName
            if (state.prayerName.lowercase().startsWith("jum")) return "JUM"
            return when (state.prayerId.lowercase()) {
                "fajr" -> "FJR"
                "dhuhr" -> "DHR"
                "asr" -> "ASR"
                "maghrib" -> "MGH"
                "isha" -> "ISH"
                else -> state.prayerName.take(3).uppercase()
            }
        }

    val iqamahCaption: String
        get() = (if (isIqamah) WidgetStrings.iqamah(language) else WidgetStrings.adhan(language)).uppercase()

    /** One row per prayer in the group. Friday Jummah rows stand in for Dhuhr. */
    fun listRows(group: LockListGroup): List<WidgetPrayerRow> {
        val all = state.rows + listOfNotNull(state.sunriseRow)
        return group.prayerIds.mapNotNull { id ->
            val matches = all.filter { it.id == id || (id == "dhuhr" && it.id.startsWith("jummah")) }
            matches.firstOrNull { it.isNext } ?: matches.firstOrNull()
        }
    }
}

internal enum class LockListGroup(val prayerIds: List<String>) {
    MORNING(listOf("fajr", "sunrise", "dhuhr")),
    EVENING(listOf("asr", "maghrib", "isha")),
}

/** A formatted time split into its clock digits and a trailing am/pm marker. */
internal data class LockScreenTime(val clock: String, val meridiem: String) {
    companion object {
        fun parse(raw: String): LockScreenTime {
            val trimmed = raw.trim()
            val clock = trimmed.takeWhile { it.isDigit() || it == ':' || it == '٫' }
            return if (clock.isEmpty()) {
                LockScreenTime(trimmed, "")
            } else {
                LockScreenTime(clock, trimmed.drop(clock.length).trim())
            }
        }
    }
}

/** Short iqamah labels for narrow columns: "After Maghrib" becomes "AM". */
internal fun lockIqamahLabel(iqamah: String): String {
    val trimmed = iqamah.trim()
    if (trimmed.equals("After Maghrib", ignoreCase = true)) return "AM"
    if (trimmed.lowercase().startsWith("after ")) {
        val first = trimmed.drop(6).trim().firstOrNull() ?: return trimmed
        return "A${first.uppercaseChar()}"
    }
    return trimmed
}

private val Ink = Color.White
private val InkSecondary = Color.White.copy(alpha = 0.72f)
private val Scrim = Color.Black.copy(alpha = 0.45f)
private val Highlight = Color.White.copy(alpha = 0.22f)

private fun ink(size: Float, weight: FontWeight = FontWeight.Medium, secondary: Boolean = false, align: TextAlign? = null) =
    TextStyle(
        color = ColorProvider(if (secondary) InkSecondary else Ink),
        fontSize = size.sp,
        fontWeight = weight,
        textAlign = align,
    )

@Composable
internal fun LockScreenWidgetContent(model: LockScreenModel, design: LockScreenDesign) {
    val context = LocalContext.current
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
    )
    val base = GlanceModifier.fillMaxSize().clickable(openApp)

    if (design.isCircular) {
        CircularFace(base, ringProgress = if (design == LockScreenDesign.CODE) model.progress else null) {
            if (model.state.kind != WidgetStateKind.CONTENT) {
                Text("!", style = ink(30f, FontWeight.Bold))
            } else if (design == LockScreenDesign.MINUTES) {
                MinutesDesign(model)
            } else {
                CodeDesign(model)
            }
        }
    } else {
        Box(
            modifier = base
                .cornerRadius(18.dp)
                .background(ColorProvider(Scrim))
                .padding(horizontal = 10.dp, vertical = 6.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            if (model.state.kind != WidgetStateKind.CONTENT) {
                Unavailable(model)
            } else {
                when (design) {
                    LockScreenDesign.PROGRESS -> ProgressDesign(model)
                    LockScreenDesign.STRIP -> StripDesign(model)
                    LockScreenDesign.LIST_MORNING -> ListDesign(model, LockListGroup.MORNING)
                    LockScreenDesign.LIST_EVENING -> ListDesign(model, LockListGroup.EVENING)
                    else -> Unit
                }
            }
        }
    }
}

@Composable
private fun Unavailable(model: LockScreenModel) {
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Text("Masjidly", style = ink(17f, FontWeight.Bold), maxLines = 1)
        Text(WidgetStrings.openApp(model.language), style = ink(12f, secondary = true), maxLines = 1)
    }
}

// Shared pieces

@Composable
private fun MasjidNameLabel(model: LockScreenModel, size: Float = 10f) {
    Text(
        text = model.state.mosqueDisplayName,
        style = ink(size, FontWeight.Medium, secondary = true, align = TextAlign.Center),
        maxLines = 1,
        modifier = GlanceModifier.fillMaxWidth(),
    )
}

/** "in 25m" under two hours, otherwise a live "in H:MM:SS" chronometer. */
@Composable
private fun CountdownLabel(model: LockScreenModel, size: Float = 12f, secondary: Boolean = false) {
    val remaining = model.remainingMillis ?: return
    val target = model.state.targetDateEpochMillis ?: return
    val template = WidgetStrings.inFormat(model.language)
    if (remaining < TWO_HOURS_MILLIS) {
        Text(template.format(model.abbreviatedRemaining), style = ink(size, secondary = secondary), maxLines = 1)
    } else {
        val prefix = template.substringBefore("%s").trim()
        val suffix = template.substringAfter("%s").trim()
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (prefix.isNotEmpty()) Text("$prefix ", style = ink(size, secondary = secondary), maxLines = 1)
            LockScreenChronometer(target, size, secondary)
            if (suffix.isNotEmpty()) Text(" $suffix", style = ink(size, secondary = secondary), maxLines = 1)
        }
    }
}

private const val TWO_HOURS_MILLIS = 7_200_000L

@Composable
private fun LockScreenChronometer(targetEpochMillis: Long, size: Float, secondary: Boolean = false) {
    val context = LocalContext.current
    val remainingMillis = (targetEpochMillis - System.currentTimeMillis()).coerceAtLeast(0L)
    val color = (if (secondary) InkSecondary else Ink).toArgb()
    val views = RemoteViews(context.packageName, R.layout.widget_lock_chronometer).apply {
        setChronometerCountDown(R.id.widget_lock_countdown, true)
        setChronometer(R.id.widget_lock_countdown, SystemClock.elapsedRealtime() + remainingMillis, null, remainingMillis > 0L)
        setTextColor(R.id.widget_lock_countdown, color)
        setTextViewTextSize(R.id.widget_lock_countdown, TypedValue.COMPLEX_UNIT_SP, size)
    }
    AndroidRemoteViews(remoteViews = views)
}

@Composable
private fun TimeText(time: LockScreenTime, clockSize: Float, weight: FontWeight, meridiemSize: Float = clockSize * 0.45f) {
    Row(verticalAlignment = Alignment.Bottom) {
        Text(time.clock, style = ink(clockSize, weight), maxLines = 1)
        if (time.meridiem.isNotEmpty()) {
            Text(time.meridiem, style = ink(meridiemSize, secondary = true), maxLines = 1)
        }
    }
}

// Rectangular designs

@Composable
private fun ProgressDesign(model: LockScreenModel) {
    val context = LocalContext.current
    val barWidth = LocalSize.current.width - 20.dp
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        MasjidNameLabel(model)
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(model.state.prayerName, style = ink(16f, FontWeight.Bold), maxLines = 1)
            Spacer(GlanceModifier.width(6.dp))
            CountdownLabel(model, size = 12f, secondary = true)
        }
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            TimeText(model.adhan, clockSize = 26f, weight = FontWeight.Normal)
            Spacer(GlanceModifier.defaultWeight())
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    WidgetStrings.iqamah(model.language).uppercase(),
                    style = ink(8f, FontWeight.Bold, secondary = true),
                    maxLines = 1,
                )
                Text(model.iqamah.clock, style = ink(15f, FontWeight.Bold), maxLines = 1)
            }
        }
        Spacer(GlanceModifier.height(3.dp))
        Image(
            provider = ImageProvider(progressBarBitmap(context, barWidth, 8.dp, model.progress)),
            contentDescription = null,
            contentScale = ContentScale.FillBounds,
            modifier = GlanceModifier.fillMaxWidth().height(8.dp),
        )
    }
}

@Composable
private fun StripDesign(model: LockScreenModel) {
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        MasjidNameLabel(model)
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(model.state.prayerName, style = ink(14f, FontWeight.Bold), maxLines = 1)
            Spacer(GlanceModifier.width(6.dp))
            CountdownLabel(model, size = 12f, secondary = true)
        }
        Spacer(GlanceModifier.height(3.dp))
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            model.state.rows.take(5).forEach { row ->
                val highlight = if (row.isNext) {
                    GlanceModifier.background(ColorProvider(Highlight)).cornerRadius(8.dp)
                } else {
                    GlanceModifier
                }
                Column(
                    modifier = highlight.defaultWeight().padding(vertical = 3.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        stripLabel(model, row),
                        style = ink(10f, FontWeight.Bold, secondary = true, align = TextAlign.Center),
                        maxLines = 1,
                    )
                    Text(
                        LockScreenTime.parse(row.adhan).clock,
                        style = ink(13f, if (row.isNext) FontWeight.Bold else FontWeight.Medium, align = TextAlign.Center),
                        maxLines = 1,
                    )
                    Text(
                        LockScreenTime.parse(lockIqamahLabel(row.iqamahs.firstOrNull().orEmpty())).clock,
                        style = ink(11f, secondary = true, align = TextAlign.Center),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

/** Latin languages use the three letter code. Arabic and Urdu keep the full prayer name. */
private fun stripLabel(model: LockScreenModel, row: WidgetPrayerRow): String {
    if (model.language == AppLanguage.ARABIC || model.language == AppLanguage.URDU) return row.name
    if (row.id.startsWith("jummah") || row.name.lowercase().startsWith("jum")) return "JUM"
    return when (row.id) {
        "fajr" -> "FJR"
        "dhuhr" -> "DHR"
        "asr" -> "ASR"
        "maghrib" -> "MGH"
        "isha" -> "ISH"
        else -> row.name.take(3).uppercase()
    }
}

@Composable
private fun ListDesign(model: LockScreenModel, group: LockListGroup) {
    val context = LocalContext.current
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        MasjidNameLabel(model, size = 11f)
        Spacer(GlanceModifier.height(2.dp))
        model.listRows(group).forEach { row ->
            Row(
                modifier = GlanceModifier.fillMaxWidth().padding(vertical = 1.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(
                    provider = ImageProvider(markerBitmap(context, row)),
                    contentDescription = null,
                    modifier = GlanceModifier.size(10.dp),
                )
                Spacer(GlanceModifier.width(6.dp))
                Row(modifier = GlanceModifier.defaultWeight(), verticalAlignment = Alignment.Bottom) {
                    Text(
                        row.name,
                        style = ink(16f, if (row.isNext) FontWeight.Bold else FontWeight.Medium),
                        maxLines = 1,
                    )
                    if (row.isTomorrow) {
                        Text(
                            " (${WidgetStrings.tomorrowShort(model.language)})",
                            style = ink(11f),
                            maxLines = 1,
                        )
                    }
                }
                ListTime(LockScreenTime.parse(row.adhan).clock, bold = row.isNext)
                ListTime(LockScreenTime.parse(lockIqamahLabel(row.iqamahs.firstOrNull().orEmpty())).clock, bold = false)
            }
        }
    }
}

@Composable
private fun ListTime(text: String, bold: Boolean) {
    Text(
        text,
        style = ink(15f, if (bold) FontWeight.Bold else FontWeight.Normal, align = TextAlign.End),
        maxLines = 1,
        modifier = GlanceModifier.width(46.dp),
    )
}

// Circular designs

@Composable
private fun CircularFace(
    modifier: GlanceModifier,
    ringProgress: Float?,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val size = min(LocalSize.current.width.value, LocalSize.current.height.value).dp
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Image(
            provider = ImageProvider(discBitmap(context, size, ringProgress)),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = GlanceModifier.size(size),
        )
        Box(modifier = GlanceModifier.size(size).padding(10.dp), contentAlignment = Alignment.Center) {
            content()
        }
    }
}

@Composable
private fun MinutesDesign(model: LockScreenModel) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            if (model.isIqamah) model.iqamahCaption else model.state.prayerName.uppercase(),
            style = ink(11f, FontWeight.Bold, secondary = true, align = TextAlign.Center),
            maxLines = 1,
        )
        val remaining = model.remainingMillis
        val target = model.state.targetDateEpochMillis
        if (remaining != null && target != null) {
            val minutes = ceil(remaining / 60_000.0).toInt()
            if (minutes < 100) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text("$minutes", style = ink(40f, FontWeight.Bold), maxLines = 1)
                    Text(model.minuteUnit, style = ink(14f, FontWeight.Medium), maxLines = 1)
                }
            } else {
                LockScreenChronometer(target, size = 15f)
            }
        } else {
            Text(model.adhan.clock, style = ink(26f, FontWeight.Bold), maxLines = 1)
        }
    }
}

@Composable
private fun CodeDesign(model: LockScreenModel) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(model.code, style = ink(18f, FontWeight.Bold, align = TextAlign.Center), maxLines = 1)
        Text(model.adhan.clock, style = ink(19f, FontWeight.Medium, align = TextAlign.Center), maxLines = 1)
    }
}

// Bitmaps. Glance has no determinate progress or stroked shapes, so these are drawn.

private fun Context.px(dp: Float): Float = dp * resources.displayMetrics.density

private fun paint(color: Color, stroke: Float? = null) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    this.color = color.toArgb()
    if (stroke != null) {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = Paint.Cap.ROUND
    }
}

private fun progressBarBitmap(context: Context, width: Dp, height: Dp, progress: Float): Bitmap {
    val w = max(1, context.px(width.value).toInt())
    val h = max(1, context.px(height.value).toInt())
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val knob = h.toFloat()
    val travel = max(0f, w - knob)
    val thickness = knob * 0.4f
    val top = (h - thickness) / 2f
    val radius = thickness / 2f
    canvas.drawRoundRect(RectF(0f, top, w.toFloat(), top + thickness), radius, radius, paint(Ink.copy(alpha = 0.3f)))
    canvas.drawRoundRect(RectF(0f, top, knob / 2f + travel * progress, top + thickness), radius, radius, paint(Ink))
    canvas.drawCircle(knob / 2f + travel * progress, h / 2f, knob / 2f, paint(Ink))
    return bitmap
}

private fun markerBitmap(context: Context, row: WidgetPrayerRow): Bitmap {
    val size = max(1, context.px(10f).toInt())
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val center = size / 2f
    if (row.isPassed) {
        canvas.drawCircle(center, center, center, paint(Ink).apply { style = Paint.Style.FILL })
    } else {
        val stroke = context.px(if (row.isNext) 2.5f else 1.5f)
        canvas.drawCircle(center, center, center - stroke / 2f, paint(Ink, stroke))
    }
    return bitmap
}

private fun discBitmap(context: Context, size: Dp, ringProgress: Float?): Bitmap {
    val side = max(1, context.px(size.value).toInt())
    val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val half = side / 2f
    canvas.drawCircle(half, half, half, paint(Scrim).apply { style = Paint.Style.FILL })
    if (ringProgress != null) {
        val stroke = context.px(4f)
        val inset = stroke / 2f + context.px(4f)
        val oval = RectF(inset, inset, side - inset, side - inset)
        canvas.drawArc(oval, 0f, 360f, false, paint(Ink.copy(alpha = 0.3f), stroke))
        canvas.drawArc(oval, -90f, 360f * ringProgress, false, paint(Ink, stroke))
    }
    return bitmap
}
