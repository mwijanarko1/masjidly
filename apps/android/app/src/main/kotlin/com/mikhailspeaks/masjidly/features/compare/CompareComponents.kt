package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

private val meridiemRegex = Regex("""(?<=\d)\s*(AM|PM|am|pm|ص|م)(?![\p{L}])""")

/** Text whose AM or PM is drawn smaller, like the Home hero clock. */
@Composable
internal fun MeridiemText(
    text: String,
    sizeSp: Float,
    color: Color,
    modifier: Modifier = Modifier,
    weight: FontWeight = FontWeight.Normal,
    meridiemScale: Float = 0.6f,
    maxLines: Int = 1,
) {
    val base = rememberAppTextStyle(sizeSp, weight, tabularDigits = true)
    val annotated = buildAnnotatedString {
        var cursor = 0
        for (match in meridiemRegex.findAll(text)) {
            append(text.substring(cursor, match.range.first))
            withStyle(SpanStyle(fontSize = (sizeSp * meridiemScale).sp)) { append(" " + match.groupValues[1]) }
            cursor = match.range.last + 1
        }
        append(text.substring(cursor))
    }
    Text(
        text = annotated,
        style = base,
        color = color,
        modifier = modifier,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}

/** Plain text tabs. The chosen option is solid with an underline, the rest are dimmed. */
@Composable
internal fun <T> CompareTextTabs(
    options: List<Pair<T, String>>,
    selection: T,
    theme: ResolvedTheme,
    sizeSp: Float,
    equalWidth: Boolean,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = if (equalWidth) Arrangement.Start else Arrangement.spacedBy(16.dp),
    ) {
        options.forEach { (value, label) ->
            val selected = value == selection
            Column(
                modifier = (if (equalWidth) Modifier.weight(1f) else Modifier.width(IntrinsicSize.Max))
                    .hapticClickable { onSelect(value) }
                    .padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = label,
                    style = rememberAppTextStyle(sizeSp, if (selected) FontWeight.SemiBold else FontWeight.Normal),
                    color = theme.textColor.copy(alpha = if (selected) 1f else 0.55f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Box(
                    Modifier
                        .height(2.dp)
                        .fillMaxWidth()
                        .background(if (selected) theme.textColor else Color.Transparent, RoundedCornerShape(1.dp)),
                )
            }
        }
    }
}

/** Solid capsule button used for primary actions (Done, Add masjid, Next day). */
@Composable
internal fun CompareCapsuleButton(
    text: String,
    theme: ResolvedTheme,
    modifier: Modifier = Modifier,
    sizeSp: Float = 16f,
    horizontal: Int = 22,
    vertical: Int = 12,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(percent = 50))
            .background(theme.textColor.copy(alpha = 0.92f))
            .hapticClickable(onClick = onClick)
            .padding(horizontal = horizontal.dp, vertical = vertical.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = rememberAppTextStyle(sizeSp, FontWeight.SemiBold),
            color = if (theme.usesLightForeground) Color.Black else Color.White,
            maxLines = 1,
        )
    }
}

/**
 * Reads a store revision inside a composable. The Compose compiler ignores a parameter the body never
 * reads when it decides whether to skip, so a revision that only exists to force recomposition must be used.
 */
internal fun readRevision(revision: Int): Int = revision
