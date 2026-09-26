package com.mikhailspeaks.masjidly.features.home

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.haptic.rememberHapticOnClick
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

/**
 * Mirrors iOS `HomeView.mosqueTabs`:
 * horizontal ScrollView → HStack(spacing: 6) of capsule tabs, then the + button
 * in the same scroll content (not pinned to the screen edge). Soft trailing fade.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MosqueTabsBar(
    openMosqueIds: List<String>,
    mosques: List<Mosque>,
    selectedMosqueId: String?,
    textColor: Color,
    usesLightForeground: Boolean,
    showAdd: Boolean,
    onSelect: (Mosque) -> Unit,
    onClose: (mosqueId: String) -> Unit,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tabs = remember(openMosqueIds, mosques) {
        openMosqueIds.mapNotNull { id -> mosques.firstOrNull { it.id == id } }
    }
    if (tabs.isEmpty()) return

    val scroll = rememberScrollState()
    val layoutAnim = tween<androidx.compose.ui.unit.Dp>(200, easing = FastOutSlowInEasing)
    val colorAnim = tween<Color>(200, easing = FastOutSlowInEasing)
    val selectedFg = if (usesLightForeground) Color.Black else Color.White
    val unselectedFg = textColor.copy(alpha = 0.72f)
    val pill = RoundedCornerShape(50)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(scroll)
            .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
            .drawWithContent {
                drawContent()
                // iOS mask: solid until ~0.96, then fade on the trailing edge.
                val fadeStart = size.width * 0.96f
                drawRect(
                    Brush.horizontalGradient(
                        0f to Color.Black,
                        1f to Color.Black.copy(alpha = 0.25f),
                        startX = fadeStart,
                        endX = size.width,
                    ),
                    blendMode = BlendMode.DstIn,
                )
            },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tabs.forEach { mosque ->
            key(mosque.id) {
                val isSelected = mosque.id == selectedMosqueId
                val bringIntoView = remember { BringIntoViewRequester() }
                LaunchedEffect(isSelected) {
                    if (isSelected) bringIntoView.bringIntoView()
                }
                val fg by animateColorAsState(
                    if (isSelected) selectedFg else unselectedFg,
                    colorAnim,
                    label = "mosqueTabFg",
                )
                val bg by animateColorAsState(
                    textColor.copy(alpha = if (isSelected) 0.92f else 0.12f),
                    colorAnim,
                    label = "mosqueTabBg",
                )
                val textMax by animateDpAsState(
                    if (isSelected) 168.dp else 88.dp,
                    layoutAnim,
                    label = "mosqueTabTextMax",
                )
                val hPad by animateDpAsState(
                    if (isSelected) 12.dp else 10.dp,
                    layoutAnim,
                    label = "mosqueTabHPad",
                )
                val onSelectTab = rememberHapticOnClick { onSelect(mosque) }
                // Match iOS: separate name button + close button inside one capsule.
                Row(
                    modifier = Modifier
                        .bringIntoViewRequester(bringIntoView)
                        .clip(pill)
                        .background(bg)
                        .semantics { if (isSelected) selected = true }
                        .padding(horizontal = hPad, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = mosque.name,
                        color = fg,
                        style = rememberAppTextStyle(
                            13f,
                            if (isSelected) FontWeight.Bold else FontWeight.SemiBold,
                        ),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .widthIn(max = textMax)
                            .hapticClickable(onClick = onSelectTab),
                    )
                    if (tabs.size > 1) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close ${mosque.name} tab",
                            tint = fg,
                            // iOS xmark ~10pt.
                            modifier = Modifier
                                .size(18.dp)
                                .hapticClickable { onClose(mosque.id) }
                                .padding(3.dp),
                        )
                    }
                }
            }
        }

        if (showAdd) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "Add mosque tab",
                tint = textColor,
                // iOS: plus + padding(10) inside Circle fill 0.12 — sits after tabs in the scroll row.
                modifier = Modifier
                    .clip(CircleShape)
                    .background(textColor.copy(alpha = 0.12f))
                    .hapticClickable(onClick = onAdd)
                    .padding(10.dp)
                    .size(14.dp),
            )
        }
    }
}
