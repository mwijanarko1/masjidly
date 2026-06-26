package com.mikhailspeaks.masjidly.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SkyGradientColorPickerSheet(
    visible: Boolean,
    title: String,
    initialColor: Color,
    theme: ResolvedTheme,
    language: AppLanguage,
    onDismiss: () -> Unit,
    onConfirm: (Color) -> Unit,
) {
    if (!visible) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val sheetColors = rememberSettingsSheetColors(theme)
    val hsv = remember(initialColor) { colorToHsv(initialColor) }
    var hue by remember(initialColor) { mutableFloatStateOf(hsv[0]) }
    var saturation by remember(initialColor) { mutableFloatStateOf(hsv[1]) }
    var value by remember(initialColor) { mutableFloatStateOf(hsv[2]) }
    val previewColor = remember(hue, saturation, value) { hsvToColor(hue, saturation, value) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = sheetColors.background,
        dragHandle = null,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = title,
                    color = sheetColors.primaryText,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = LocaleStrings.t("settings.done", language),
                    color = Color(0xFF47A6FF),
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier.hapticClickable {
                        onConfirm(previewColor)
                        scope.launch {
                            sheetState.hide()
                            onDismiss()
                        }
                    },
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(72.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(previewColor)
                    .border(0.5.dp, sheetColors.divider, RoundedCornerShape(14.dp)),
            )

            ColorSliderRow(
                label = LocaleStrings.t("settings.theme.gradient.custom.hue", language),
                value = hue,
                valueRange = 0f..360f,
                textColor = sheetColors.primaryText,
                onValueChange = { hue = it },
            )
            ColorSliderRow(
                label = LocaleStrings.t("settings.theme.gradient.custom.saturation", language),
                value = saturation,
                valueRange = 0f..1f,
                textColor = sheetColors.primaryText,
                onValueChange = { saturation = it },
            )
            ColorSliderRow(
                label = LocaleStrings.t("settings.theme.gradient.custom.brightness", language),
                value = value,
                valueRange = 0f..1f,
                textColor = sheetColors.primaryText,
                onValueChange = { value = it },
            )
        }
    }
}

@Composable
fun CustomGradientColorButton(
    label: String,
    color: Color,
    textColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 44.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(textColor.copy(alpha = 0.12f))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(width = 46.dp, height = 32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color)
                .border(1.dp, textColor.copy(alpha = 0.25f), RoundedCornerShape(8.dp))
                .hapticClickable(onClick = onClick),
        )
        Text(
            text = label,
            color = textColor,
            style = rememberAppTextStyle(15f),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .hapticClickable(onClick = onClick),
        )
    }
}

@Composable
private fun ColorSliderRow(
    label: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    textColor: Color,
    onValueChange: (Float) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            color = textColor,
            style = rememberAppTextStyle(15f),
        )
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
        )
    }
}

private fun colorToHsv(color: Color): FloatArray {
    val red = color.red
    val green = color.green
    val blue = color.blue
    val max = max(red, max(green, blue))
    val min = min(red, min(green, blue))
    val delta = max - min

    val hue = when {
        delta == 0f -> 0f
        max == red -> ((green - blue) / delta) % 6f
        max == green -> ((blue - red) / delta) + 2f
        else -> ((red - green) / delta) + 4f
    } * 60f

    val saturation = if (max == 0f) 0f else delta / max
    return floatArrayOf((hue + 360f) % 360f, saturation, max)
}

private fun hsvToColor(hue: Float, saturation: Float, value: Float): Color {
    val chroma = value * saturation
    val huePrime = hue / 60f
    val x = chroma * (1f - kotlin.math.abs(huePrime % 2f - 1f))
    val (red1, green1, blue1) = when {
        huePrime < 1f -> Triple(chroma, x, 0f)
        huePrime < 2f -> Triple(x, chroma, 0f)
        huePrime < 3f -> Triple(0f, chroma, x)
        huePrime < 4f -> Triple(0f, x, chroma)
        huePrime < 5f -> Triple(x, 0f, chroma)
        else -> Triple(chroma, 0f, x)
    }
    val match = value - chroma
    return Color(red1 + match, green1 + match, blue1 + match)
}
