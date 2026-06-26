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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

data class SettingsPickerOption(
    val key: String,
    val label: String,
)

internal enum class MenuPickerRowAlignment {
    FirstTextBaseline,
    Top,
    Center,
}

internal data class MenuPickerRowMetrics(
    val fontSize: Float,
    val labelValueSpacing: Dp,
    val valueChevronSpacing: Dp,
    val chevronSize: Dp,
    val chevronTopPadding: Dp,
    val chevronWeight: FontWeight,
    val minRowHeight: Dp,
    val horizontalPadding: Dp,
    val verticalPadding: Dp,
    val multilineValue: Boolean,
    val alignment: MenuPickerRowAlignment,
    val valueExpands: Boolean,
    val labelExpands: Boolean,
    val labelMaxLines: Int = 1,
)

internal object MenuPickerMetrics {
    val SettingsStandard = MenuPickerRowMetrics(
        fontSize = 17f,
        labelValueSpacing = 12.dp,
        valueChevronSpacing = 6.dp,
        chevronSize = 13.dp,
        chevronTopPadding = 0.dp,
        chevronWeight = FontWeight.SemiBold,
        minRowHeight = 44.dp,
        horizontalPadding = 0.dp,
        verticalPadding = 12.dp,
        multilineValue = false,
        alignment = MenuPickerRowAlignment.FirstTextBaseline,
        valueExpands = true,
        labelExpands = false,
    )

    val SettingsMosque = SettingsStandard.copy(
        multilineValue = true,
        alignment = MenuPickerRowAlignment.Top,
        chevronTopPadding = 2.dp,
    )

    val SettingsReminder = SettingsStandard.copy(
        labelValueSpacing = 16.dp,
        alignment = MenuPickerRowAlignment.Center,
        valueExpands = false,
        labelExpands = true,
    )

    val SettingsGradient = SettingsStandard.copy(
        verticalPadding = 0.dp,
        labelMaxLines = 2,
    )

    val Onboarding = MenuPickerRowMetrics(
        fontSize = 18f,
        labelValueSpacing = 14.dp,
        valueChevronSpacing = 7.dp,
        chevronSize = 14.dp,
        chevronTopPadding = 3.dp,
        chevronWeight = FontWeight.SemiBold,
        minRowHeight = 52.dp,
        horizontalPadding = 24.dp,
        verticalPadding = 0.dp,
        multilineValue = false,
        alignment = MenuPickerRowAlignment.FirstTextBaseline,
        valueExpands = true,
        labelExpands = false,
    )

    val OnboardingMosque = Onboarding.copy(
        multilineValue = true,
    )

    val OnboardingReminder = MenuPickerRowMetrics(
        fontSize = 16f,
        labelValueSpacing = 0.dp,
        valueChevronSpacing = 6.dp,
        chevronSize = 13.dp,
        chevronTopPadding = 0.dp,
        chevronWeight = FontWeight.SemiBold,
        minRowHeight = 0.dp,
        horizontalPadding = 0.dp,
        verticalPadding = 0.dp,
        multilineValue = false,
        alignment = MenuPickerRowAlignment.Center,
        valueExpands = false,
        labelExpands = true,
    )
}

@Composable
internal fun MenuPickerRowContent(
    label: String,
    displayValue: String,
    textColor: Color,
    onClick: () -> Unit,
    metrics: MenuPickerRowMetrics,
    modifier: Modifier = Modifier,
) {
    val rowVerticalAlignment = when (metrics.alignment) {
        MenuPickerRowAlignment.FirstTextBaseline,
        MenuPickerRowAlignment.Top,
        -> Alignment.Top

        MenuPickerRowAlignment.Center -> Alignment.CenterVertically
    }
    val useBaseline = metrics.alignment == MenuPickerRowAlignment.FirstTextBaseline
    val valueVerticalAlignment = when {
        metrics.multilineValue -> Alignment.Top
        metrics.alignment == MenuPickerRowAlignment.Center -> Alignment.CenterVertically
        else -> Alignment.Top
    }
    val chevronTopPadding = when {
        metrics.multilineValue -> metrics.chevronTopPadding
        metrics.chevronTopPadding > 0.dp -> metrics.chevronTopPadding
        else -> 0.dp
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .hapticClickable(onClick = onClick)
            .then(
                if (metrics.horizontalPadding > 0.dp) {
                    Modifier.padding(horizontal = metrics.horizontalPadding)
                } else {
                    Modifier
                },
            )
            .then(
                if (metrics.verticalPadding > 0.dp) {
                    Modifier.padding(vertical = metrics.verticalPadding)
                } else {
                    Modifier
                },
            )
            .then(
                if (metrics.minRowHeight > 0.dp) {
                    Modifier.heightIn(min = metrics.minRowHeight)
                } else {
                    Modifier
                },
            ),
        verticalAlignment = rowVerticalAlignment,
    ) {
        Text(
            text = label,
            color = textColor,
            style = rememberAppTextStyle(metrics.fontSize),
            maxLines = metrics.labelMaxLines,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .then(
                    if (metrics.labelExpands) {
                        Modifier.weight(1f)
                    } else {
                        Modifier
                    },
                )
                .then(if (useBaseline) Modifier.alignByBaseline() else Modifier),
        )

        if (metrics.labelValueSpacing > 0.dp) {
            Spacer(modifier = Modifier.width(metrics.labelValueSpacing))
        }

        Row(
            modifier = Modifier.then(
                if (metrics.valueExpands) {
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                } else {
                    Modifier
                },
            ),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = valueVerticalAlignment,
        ) {
            Text(
                text = displayValue,
                color = textColor,
                style = rememberAppTextStyle(metrics.fontSize),
                textAlign = TextAlign.End,
                maxLines = if (metrics.multilineValue) Int.MAX_VALUE else 1,
                overflow = if (metrics.multilineValue) TextOverflow.Clip else TextOverflow.Ellipsis,
                modifier = Modifier
                    .then(
                        if (metrics.valueExpands && metrics.multilineValue) {
                            Modifier.weight(1f, fill = false)
                        } else {
                            Modifier
                        },
                    )
                    .then(if (useBaseline) Modifier.alignByBaseline() else Modifier),
            )
            Icon(
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = textColor.copy(alpha = 0.7f),
                modifier = Modifier
                    .padding(start = metrics.valueChevronSpacing, top = chevronTopPadding)
                    .size(metrics.chevronSize),
            )
        }
    }
}

/**
 * iOS-style settings picker: label + value + chevron row; opens a bottom sheet list.
 */
@Composable
fun SettingsMenuPickerRow(
    label: String,
    displayValue: String,
    sheetTitle: String = label,
    theme: ResolvedTheme,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    multilineValue: Boolean = false,
) {
    MenuPickerRowContent(
        label = label,
        displayValue = displayValue,
        textColor = theme.textColor,
        onClick = onClick,
        metrics = if (multilineValue) {
            MenuPickerMetrics.SettingsMosque
        } else {
            MenuPickerMetrics.SettingsStandard
        },
        modifier = modifier,
    )
}

@Composable
fun SettingsReminderMenuPickerRow(
    label: String,
    displayValue: String,
    theme: ResolvedTheme,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MenuPickerRowContent(
        label = label,
        displayValue = displayValue,
        textColor = theme.textColor,
        onClick = onClick,
        metrics = MenuPickerMetrics.SettingsReminder,
        modifier = modifier,
    )
}

@Composable
fun OnboardingMenuPickerRow(
    label: String,
    displayValue: String,
    textColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    multilineValue: Boolean = false,
) {
    MenuPickerRowContent(
        label = label,
        displayValue = displayValue,
        textColor = textColor,
        onClick = onClick,
        metrics = if (multilineValue) {
            MenuPickerMetrics.OnboardingMosque
        } else {
            MenuPickerMetrics.Onboarding
        },
        modifier = modifier,
    )
}

@Composable
fun OnboardingReminderMenuPickerRow(
    label: String,
    displayValue: String,
    textColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    MenuPickerRowContent(
        label = label,
        displayValue = displayValue,
        textColor = textColor,
        onClick = onClick,
        metrics = MenuPickerMetrics.OnboardingReminder,
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsPickerBottomSheet(
    visible: Boolean,
    title: String,
    options: List<SettingsPickerOption>,
    selectedKey: String,
    theme: ResolvedTheme,
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
                    .heightIn(max = maxListHeight),
            ) {
                items(options, key = { it.key }) { option ->
                    val selected = option.key == selectedKey
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp)
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

internal data class SettingsSheetColors(
    val background: Color,
    val primaryText: Color,
    val rowBackground: Color,
    val divider: Color,
)

@Composable
internal fun rememberSettingsSheetColors(theme: ResolvedTheme): SettingsSheetColors {
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
