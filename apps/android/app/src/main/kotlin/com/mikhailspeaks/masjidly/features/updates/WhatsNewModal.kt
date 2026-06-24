package com.mikhailspeaks.masjidly.features.updates

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.ui.home.MasjidlyColors
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.onboarding.OnboardingPrimaryCapsule
import com.mikhailspeaks.masjidly.ui.onboarding.OnboardingTutorialChrome
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import java.util.Locale

/**
 * "What's New" overlay — mirrors iOS `WhatsNewModalView` + `HomeView.whatsNewOverlay`.
 */
@Composable
fun WhatsNewOverlay(
    theme: ResolvedTheme,
    language: AppLanguage,
    onDismiss: () -> Unit,
) {
    val locale = language.resolvedLocale()
    val copy = WhatsNewModalCopy.forLocale(locale)
    val items = WhatsNew.localizedUpdates(locale)

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val maxCardHeight = minOf(580.dp, maxHeight - 80.dp)
        val cardMaxWidth = minOf(380.dp, maxWidth - 48.dp)

        Box(modifier = Modifier.fillMaxSize()) {
            WhatsNewBackdrop(theme = theme, onDismiss = onDismiss)

            OnboardingTutorialChrome.Card(
                appearance = theme,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 24.dp)
                    .width(cardMaxWidth)
                    .heightIn(max = maxCardHeight),
            ) {
                WhatsNewModalContent(
                    version = WhatsNew.currentVersion,
                    items = items,
                    copy = copy,
                    theme = theme,
                    onDismiss = onDismiss,
                )
            }
        }
    }
}

@Composable
private fun WhatsNewBackdrop(
    theme: ResolvedTheme,
    onDismiss: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .hapticClickable(onClick = onDismiss),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        theme.sky.baseColors.map { it.copy(alpha = 0.55f) },
                    ),
                ),
        )
        theme.sky.glowColor?.let { glow ->
            Canvas(modifier = Modifier.fillMaxSize()) {
                val center = androidx.compose.ui.geometry.Offset(size.width * 0.5f, size.height * 0.82f)
                val radius = 500f
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            glow.copy(alpha = 0.4f * theme.sky.glowBaseAlpha),
                            glow.copy(alpha = 0.15f * theme.sky.glowBaseAlpha),
                            Color.Transparent,
                        ),
                        center = center,
                        radius = radius,
                    ),
                    radius = radius,
                    center = center,
                    blendMode = BlendMode.Screen,
                )
            }
        }
    }
}

@Composable
private fun WhatsNewModalContent(
    version: String,
    items: List<WhatsNewItem>,
    copy: WhatsNewModalCopy,
    theme: ResolvedTheme,
    onDismiss: () -> Unit,
) {
    val shouldScrollItems = items.size > 3
    val textColor = theme.textColor

    Column(
        modifier = Modifier.padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = copy.title,
                style = rememberAppTextStyle(26f, FontWeight.Bold),
                color = textColor,
            )
            Text(
                text = copy.versionLabel(version),
                style = rememberAppTextStyle(14f, FontWeight.Medium),
                color = textColor.copy(alpha = 0.62f),
                modifier = Modifier
                    .clip(RoundedCornerShape(percent = 50))
                    .background(textColor.copy(alpha = 0.1f))
                    .padding(horizontal = 16.dp, vertical = 6.dp),
            )
            if (shouldScrollItems) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 2.dp),
                ) {
                    Text(
                        text = copy.swipeHint,
                        style = rememberAppTextStyle(12f, FontWeight.Medium),
                        color = textColor.copy(alpha = 0.45f),
                    )
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = null,
                        tint = textColor.copy(alpha = 0.45f),
                        modifier = Modifier.size(12.dp),
                    )
                }
            }
        }

        val itemsModifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 2.dp)
            .then(
                if (shouldScrollItems) {
                    Modifier
                        .heightIn(max = 240.dp)
                        .verticalScroll(rememberScrollState())
                } else {
                    Modifier
                },
            )

        Column(
            modifier = itemsModifier,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            items.forEach { item ->
                WhatsNewItemRow(item = item, textColor = textColor)
            }
        }

        OnboardingPrimaryCapsule(
            label = copy.continueLabel,
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp),
            onClick = onDismiss,
        )
    }
}

@Composable
private fun WhatsNewItemRow(
    item: WhatsNewItem,
    textColor: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = Icons.Default.BugReport,
            contentDescription = null,
            tint = MasjidlyColors.accent,
            modifier = Modifier
                .width(32.dp)
                .padding(top = 2.dp),
        )
        Column(
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = item.title,
                style = rememberAppTextStyle(17f, FontWeight.Bold),
                color = textColor,
            )
            Text(
                text = item.description,
                style = rememberAppTextStyle(14f, FontWeight.Normal),
                color = textColor.copy(alpha = 0.72f),
                lineHeight = 20.sp,
            )
        }
    }
}
