package com.mikhailspeaks.masjidly.features.settings

import androidx.compose.foundation.background
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

data class SettingsPickerOption(
    val key: String,
    val label: String,
)

/**
 * iOS / Expo-style settings picker: label + value + chevron row; opens a native bottom sheet list.
 */
@Composable
fun SettingsMenuPickerRow(
    label: String,
    displayValue: String,
    sheetTitle: String = label,
    theme: TimeTheme,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    multilineValue: Boolean = false,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .hapticClickable(onClick = onClick)
            .padding(vertical = 12.dp)
            .heightIn(min = 44.dp),
        verticalAlignment = if (multilineValue) Alignment.Top else Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = theme.textColor,
            style = rememberAppTextStyle(17f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(modifier = Modifier.width(12.dp))
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = if (multilineValue) Alignment.Top else Alignment.CenterVertically,
            horizontalArrangement = Arrangement.End,
        ) {
            Text(
                text = displayValue,
                color = theme.textColor,
                style = rememberAppTextStyle(17f),
                textAlign = TextAlign.End,
                maxLines = if (multilineValue) Int.MAX_VALUE else 1,
                overflow = if (multilineValue) TextOverflow.Clip else TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Icon(
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = theme.textColor.copy(alpha = 0.7f),
                modifier = Modifier
                    .padding(start = 6.dp, top = if (multilineValue) 2.dp else 0.dp)
                    .size(18.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsPickerBottomSheet(
    visible: Boolean,
    title: String,
    options: List<SettingsPickerOption>,
    selectedKey: String,
    theme: TimeTheme,
    language: AppLanguage,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    if (!visible) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val sheetColors = rememberSettingsSheetColors(theme)
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    val maxSheetHeight = screenHeight * 0.72f
    val headerHeight = 49.dp
    val maxListHeight = (maxSheetHeight - headerHeight - 24.dp).coerceAtLeast(160.dp)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = sheetColors.background,
        dragHandle = null,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = maxSheetHeight)
                .navigationBarsPadding(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = title,
                    color = sheetColors.primaryText,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = LocaleStrings.t("settings.done", language),
                    color = Color(0xFF47A6FF),
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier
                        .padding(start = 12.dp)
                        .hapticClickable {
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
                    .height(0.5.dp)
                    .background(sheetColors.divider),
            )
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxListHeight)
                    .padding(vertical = 8.dp),
            ) {
                items(options, key = { it.key }) { option ->
                    val selected = option.key == selectedKey
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(sheetColors.rowBackground)
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                            .hapticClickable {
                                onSelect(option.key)
                                scope.launch {
                                    sheetState.hide()
                                    onDismiss()
                                }
                            },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = option.label,
                            color = sheetColors.primaryText,
                            style = rememberAppTextStyle(
                                17f,
                                if (selected) FontWeight.SemiBold else FontWeight.Normal,
                            ),
                            modifier = Modifier.weight(1f),
                        )
                        if (selected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = Color(0xFF47A6FF),
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

private data class SettingsSheetColors(
    val background: Color,
    val primaryText: Color,
    val rowBackground: Color,
    val divider: Color,
)

@Composable
private fun rememberSettingsSheetColors(theme: TimeTheme): SettingsSheetColors {
    return if (theme.usesLightForeground) {
        SettingsSheetColors(
            background = Color(0xFF1C1C1E),
            primaryText = Color.White,
            rowBackground = Color(0xFF2C2C2E),
            divider = Color.White.copy(alpha = 0.12f),
        )
    } else {
        SettingsSheetColors(
            background = Color(0xFFF2F2F7),
            primaryText = Color.Black,
            rowBackground = Color.White,
            divider = Color.Black.copy(alpha = 0.12f),
        )
    }
}
