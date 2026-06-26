package com.mikhailspeaks.masjidly.features.updates

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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingPrimaryButton
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingScrim
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingTutorialCard
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingTutorialCardStyle
import com.mikhailspeaks.masjidly.features.onboarding.onboardingCardMutedColor
import com.mikhailspeaks.masjidly.features.onboarding.onboardingCardTextColor
import com.mikhailspeaks.masjidly.ui.home.MasjidlyColors
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import java.util.Locale

/**
 * "What's New" overlay — uses the same opaque tutorial card + scrim as onboarding modals.
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
    val cardStyle = OnboardingTutorialCardStyle.Light
    val cardTextColor = onboardingCardTextColor(theme, cardStyle)
    val cardMutedColor = onboardingCardMutedColor(theme, cardStyle)

    Box(modifier = Modifier.fillMaxSize()) {
        OnboardingScrim(
            theme = theme,
            modifier = Modifier.hapticClickable(onClick = onDismiss),
        )

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            val maxCardHeight = minOf(580.dp, maxHeight - 80.dp)

            OnboardingTutorialCard(
                theme = theme,
                style = cardStyle,
                modifier = Modifier
                    .widthIn(max = 400.dp)
                    .heightIn(max = maxCardHeight),
            ) {
                WhatsNewModalContent(
                    version = WhatsNew.currentVersion,
                    items = items,
                    copy = copy,
                    theme = theme,
                    cardTextColor = cardTextColor,
                    cardMutedColor = cardMutedColor,
                    onDismiss = onDismiss,
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
    cardTextColor: Color,
    cardMutedColor: Color,
    onDismiss: () -> Unit,
) {
    val shouldScrollItems = items.size > 3

    Column(
        modifier = Modifier.padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = copy.title,
                style = rememberAppTextStyle(23f, FontWeight.SemiBold),
                color = cardTextColor,
                textAlign = TextAlign.Center,
                letterSpacing = (-0.5f).sp,
            )
            Text(
                text = copy.versionLabel(version),
                style = rememberAppTextStyle(14f, FontWeight.Medium),
                color = cardMutedColor,
                modifier = Modifier
                    .clip(RoundedCornerShape(percent = 50))
                    .background(cardTextColor.copy(alpha = 0.1f))
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
                        color = cardMutedColor.copy(alpha = 0.6f),
                    )
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = null,
                        tint = cardMutedColor.copy(alpha = 0.6f),
                        modifier = Modifier.size(12.dp),
                    )
                }
            }
        }

        val itemsModifier = Modifier
            .fillMaxWidth()
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
                WhatsNewItemRow(
                    item = item,
                    cardTextColor = cardTextColor,
                    cardMutedColor = cardMutedColor,
                )
            }
        }

        OnboardingPrimaryButton(
            text = copy.continueLabel,
            theme = theme,
            onClick = onDismiss,
        )
    }
}

@Composable
private fun WhatsNewItemRow(
    item: WhatsNewItem,
    cardTextColor: Color,
    cardMutedColor: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = when (item.icon) {
                WhatsNewIcon.WIDGET -> Icons.Default.Widgets
                WhatsNewIcon.PALETTE -> Icons.Default.Palette
            },
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
                style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                color = cardTextColor,
            )
            Text(
                text = item.description,
                style = rememberAppTextStyle(16f),
                color = cardMutedColor,
                lineHeight = 22.sp,
            )
        }
    }
}
