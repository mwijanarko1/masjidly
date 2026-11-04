package com.mikhailspeaks.masjidly.features.home

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
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
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.haptic.performMasjidlyLongPressHaptic
import com.mikhailspeaks.masjidly.ui.haptic.rememberHapticOnClick
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlinx.coroutines.launch

private val TabSpacing = 6.dp

/**
 * Mirrors iOS `HomeView.mosqueTabs`:
 * horizontal ScrollView → HStack(spacing: 6) of capsule tabs, then the + button
 * in the same scroll content (not pinned to the screen edge). Soft trailing fade.
 * Long-press a tab, then drag it sideways to reorder; the new order is reported on release.
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
    onReorder: (List<String>) -> Unit,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tabs = remember(openMosqueIds, mosques) {
        openMosqueIds.mapNotNull { id -> mosques.firstOrNull { it.id == id } }
    }
    if (tabs.isEmpty()) return

    var order by remember(tabs) { mutableStateOf(tabs.map { it.id }) }
    val widths = remember { mutableStateMapOf<String, Float>() }
    var draggedId by remember { mutableStateOf<String?>(null) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val spacingPx = with(LocalDensity.current) { TabSpacing.toPx() }
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val onReorderLatest by rememberUpdatedState(onReorder)
    val committedIds by rememberUpdatedState(tabs.map { it.id })
    val ordered = order.mapNotNull { id -> tabs.firstOrNull { it.id == id } }

    fun leftOf(id: String): Float {
        var x = 0f
        for (other in order) {
            if (other == id) return x
            x += (widths[other] ?: 0f) + spacingPx
        }
        return x
    }

    fun swapWithNeighbourIfCrossed() {
        val id = draggedId ?: return
        val index = order.indexOf(id)
        val width = widths[id] ?: return
        val leading = leftOf(id) + dragOffset
        val trailing = leading + width
        val next = order.getOrNull(index + 1)
        val previous = order.getOrNull(index - 1)
        if (next != null && trailing > leftOf(next) + (widths[next] ?: 0f) / 2f) {
            order = order.toMutableList().also { it[index] = next; it[index + 1] = id }
            dragOffset -= (widths[next] ?: 0f) + spacingPx
        } else if (previous != null && leading < leftOf(previous) + (widths[previous] ?: 0f) / 2f) {
            order = order.toMutableList().also { it[index] = previous; it[index - 1] = id }
            dragOffset += (widths[previous] ?: 0f) + spacingPx
        }
    }

    fun finishDrag() {
        if (draggedId == null) return
        if (order != committedIds) onReorderLatest(order)
        scope.launch {
            Animatable(dragOffset).animateTo(0f, tween(150, easing = FastOutSlowInEasing)) {
                dragOffset = value
            }
            draggedId = null
        }
    }

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
        horizontalArrangement = Arrangement.spacedBy(TabSpacing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ordered.forEach { mosque ->
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
                val isDragged = draggedId == mosque.id
                val left = leftOf(mosque.id)
                val slide = remember { Animatable(0f) }
                var previousLeft by remember { mutableFloatStateOf(left) }
                LaunchedEffect(left) {
                    if (draggedId != null && !isDragged && previousLeft != left) {
                        slide.snapTo(previousLeft - left)
                        slide.animateTo(0f, tween(180, easing = FastOutSlowInEasing))
                    }
                    previousLeft = left
                }
                // Match iOS: separate name button + close button inside one capsule.
                Row(
                    modifier = Modifier
                        .bringIntoViewRequester(bringIntoView)
                        .onSizeChanged { widths[mosque.id] = it.width.toFloat() }
                        .zIndex(if (isDragged) 1f else 0f)
                        .graphicsLayer {
                            translationX = if (isDragged) dragOffset else slide.value
                            val scale = if (isDragged) 1.06f else 1f
                            scaleX = scale
                            scaleY = scale
                        }
                        .clip(pill)
                        .background(bg)
                        .semantics { if (isSelected) selected = true }
                        .pointerInput(mosque.id) {
                            detectDragGesturesAfterLongPress(
                                onDragStart = {
                                    draggedId = mosque.id
                                    dragOffset = 0f
                                    view.performMasjidlyLongPressHaptic()
                                },
                                onDrag = { change, amount ->
                                    change.consume()
                                    dragOffset += amount.x
                                    swapWithNeighbourIfCrossed()
                                },
                                onDragEnd = { finishDrag() },
                                onDragCancel = { finishDrag() },
                            )
                        }
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
