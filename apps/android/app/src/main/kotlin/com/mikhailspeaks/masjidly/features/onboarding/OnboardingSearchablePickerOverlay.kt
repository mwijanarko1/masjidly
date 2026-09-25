package com.mikhailspeaks.masjidly.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerOption
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

/**
 * Compact glass-select dropdown panel: search + options under a picker row.
 */
@Composable
fun SearchableDropdownPanel(
    options: List<SettingsPickerOption>,
    selectedKey: String,
    theme: ResolvedTheme,
    searchPlaceholder: String = "Search…",
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val cardStyle = OnboardingTutorialCardStyle.Themed
    val textColor = onboardingCardTextColor(theme, cardStyle)
    val muted = onboardingCardMutedColor(theme, cardStyle)
    var query by remember { mutableStateOf("") }
    val filtered = remember(options, query) {
        val q = query.trim().lowercase()
        if (q.isEmpty()) options
        else options.filter { it.label.lowercase().contains(q) || it.key.lowercase().contains(q) }
    }
    val shape = RoundedCornerShape(14.dp)
    val panelFill = if (theme.usesLightForeground) {
        Brush.linearGradient(listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.03f)))
    } else {
        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.92f), Color.White.copy(alpha = 0.78f)))
    }
    val borderColor = textColor.copy(alpha = if (theme.usesLightForeground) 0.18f else 0.12f)
    val selectedBg = Color(0xFF47A6FF).copy(alpha = if (theme.usesLightForeground) 0.32f else 0.16f)
    val listHeight = minOf(260.dp, ((maxOf(filtered.size, 1) * 44) + 8).dp)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(12.dp, shape, ambientColor = Color.Black.copy(alpha = 0.18f), spotColor = Color.Black.copy(alpha = 0.22f))
            .clip(shape)
            .background(brush = panelFill, shape = shape)
            .border(1.dp, borderColor, shape),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = muted.copy(alpha = 0.7f),
                modifier = Modifier.size(16.dp),
            )
            BasicTextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                cursorBrush = SolidColor(textColor),
                textStyle = rememberAppTextStyle(14f).copy(color = textColor),
                modifier = Modifier.weight(1f),
                decorationBox = { inner ->
                    if (query.isEmpty()) {
                        Text(
                            text = searchPlaceholder,
                            color = muted.copy(alpha = 0.7f),
                            style = rememberAppTextStyle(14f),
                        )
                    }
                    inner()
                },
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(textColor.copy(alpha = if (theme.usesLightForeground) 0.18f else 0.12f)),
        )
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .height(listHeight)
                .padding(4.dp),
        ) {
            if (filtered.isEmpty()) {
                item {
                    Text(
                        text = "No matches.",
                        color = muted,
                        style = rememberAppTextStyle(13f),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 20.dp),
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                items(filtered, key = { it.key }) { option ->
                    val selected = option.key == selectedKey
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                if (selected) selectedBg else Color.Transparent,
                                RoundedCornerShape(10.dp),
                            )
                            .hapticClickable { onSelect(option.key) }
                            .padding(horizontal = 10.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = textColor.copy(alpha = if (selected) 1f else 0f),
                            modifier = Modifier.size(16.dp),
                        )
                        Text(
                            text = option.label,
                            color = textColor,
                            style = rememberAppTextStyle(14f, FontWeight.Medium),
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}
