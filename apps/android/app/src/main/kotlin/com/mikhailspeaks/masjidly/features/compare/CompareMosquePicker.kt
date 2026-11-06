package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.features.settings.rememberSettingsSheetColors
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.MasjidlyColors
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

/** Multi-select masjid picker for Compare. Masjids from every city, grouped by city, with search. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
internal fun CompareMosquePicker(
    mosques: List<Mosque>,
    homeMosqueId: String?,
    model: CompareViewModel,
    theme: ResolvedTheme,
    language: AppLanguage,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val colors = rememberSettingsSheetColors(theme)
    var search by remember { mutableStateOf("") }

    val visible = remember(mosques) { MosqueSelection.visibleMosques(mosques) }
    val query = search.trim()
    val filtered = if (query.isEmpty()) visible else visible.filter {
        it.name.contains(query, ignoreCase = true) || it.cityDisplayName.contains(query, ignoreCase = true)
    }
    val groups = MosqueSelection.cityOptions(filtered).map { (key, label) ->
        Triple(key, label, MosqueSelection.mosquesInCity(key, filtered))
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.background,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxHeight(0.85f).navigationBarsPadding()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = LocaleStrings.t("compare.add", language),
                    color = colors.primaryText,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = LocaleStrings.t("compare.done", language),
                    color = MasjidlyColors.accent,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    modifier = Modifier.hapticClickable {
                        scope.launch {
                            sheetState.hide()
                            onDismiss()
                        }
                    },
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(percent = 50))
                    .background(colors.rowBackground)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Default.Search, contentDescription = null, tint = colors.primaryText.copy(alpha = 0.5f), modifier = Modifier.size(20.dp))
                androidx.compose.foundation.layout.Box {
                    if (search.isEmpty()) {
                        Text(
                            LocaleStrings.t("compare.search", language),
                            color = colors.primaryText.copy(alpha = 0.4f),
                            style = rememberAppTextStyle(16f),
                        )
                    }
                    BasicTextField(
                        value = search,
                        onValueChange = { search = it },
                        singleLine = true,
                        textStyle = rememberAppTextStyle(16f).copy(color = colors.primaryText),
                        cursorBrush = SolidColor(colors.primaryText),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            if (!model.canAddMore) {
                Text(
                    text = LocaleStrings.t("compare.limit", language),
                    color = colors.primaryText.copy(alpha = 0.7f),
                    style = rememberAppTextStyle(13f, FontWeight.Medium),
                    modifier = Modifier.padding(start = 16.dp, top = 8.dp),
                )
            }
            LazyColumn(modifier = Modifier.weight(1f).padding(top = 8.dp)) {
                groups.forEach { (key, label, items) ->
                    stickyHeader(key = "h-$key") {
                        Text(
                            text = label,
                            color = colors.primaryText.copy(alpha = 0.65f),
                            style = rememberAppTextStyle(13f, FontWeight.SemiBold),
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(colors.background)
                                .padding(horizontal = 16.dp, vertical = 6.dp),
                        )
                    }
                    items(items.size, key = { "m-${items[it].id}" }) { index ->
                        PickerRow(items[index], homeMosqueId, model, colors.primaryText)
                    }
                }
            }
        }
    }
}

@Composable
private fun PickerRow(
    mosque: Mosque,
    homeMosqueId: String?,
    model: CompareViewModel,
    textColor: androidx.compose.ui.graphics.Color,
) {
    val listed = model.isListed(mosque)
    val isYours = model.isYours(mosque)
    val disabled = isYours || (!listed && !model.canAddMore)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(if (isYours) 0.6f else if (disabled) 0.4f else 1f)
            .hapticClickable(enabled = !disabled) {
                if (listed) model.remove(mosque) else model.add(mosque)
            }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = mosque.name,
            color = textColor,
            style = rememberAppTextStyle(16f, if (mosque.id == homeMosqueId) FontWeight.SemiBold else FontWeight.Normal),
            modifier = Modifier.weight(1f),
        )
        Icon(
            if (listed) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (listed) MasjidlyColors.accent else textColor.copy(alpha = 0.4f),
            modifier = Modifier.size(22.dp),
        )
    }
}
