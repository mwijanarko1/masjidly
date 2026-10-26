package com.mikhailspeaks.masjidly.features.settings

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusAppOption
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusApps
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Multi-select list of launchable apps for Prayer Focus. Styled like [SettingsPickerBottomSheet]. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrayerFocusAppPickerSheet(
    visible: Boolean,
    selectedPackages: Set<String>,
    theme: ResolvedTheme,
    language: AppLanguage,
    onDismiss: () -> Unit,
    onToggle: (packageName: String, selected: Boolean) -> Unit,
) {
    if (!visible) return

    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val sheetColors = rememberSettingsSheetColors(theme)
    val maxSheetHeight = LocalConfiguration.current.screenHeightDp.dp * 0.8f
    var apps by remember { mutableStateOf<List<PrayerFocusAppOption>?>(null) }

    LaunchedEffect(Unit) {
        // Label loading touches every package; keep it off the main thread.
        apps = withContext(Dispatchers.Default) { PrayerFocusApps.launchableApps(context) }
    }

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
                    text = LocaleStrings.t("settings.prayer_focus.choose_apps", language),
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
            val loaded = apps
            if (loaded == null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = sheetColors.primaryText, modifier = Modifier.size(28.dp))
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxWidth()) {
                    items(loaded, key = { it.packageName }) { app ->
                        val isSelected = app.packageName in selectedPackages
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .semantics { selected = isSelected }
                                .hapticClickable(role = Role.Checkbox) { onToggle(app.packageName, !isSelected) }
                                .padding(horizontal = 16.dp, vertical = 12.dp)
                                .heightIn(min = 24.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = app.label,
                                color = sheetColors.primaryText,
                                style = rememberAppTextStyle(
                                    17f,
                                    if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                ),
                                modifier = Modifier.weight(1f),
                            )
                            if (isSelected) {
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
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}
