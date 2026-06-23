package com.mikhailspeaks.masjidly.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.MasjidlyColors
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

/**
 * Frosted card chrome for onboarding-style modals — mirrors iOS `OnboardingTutorialChrome`.
 */
object OnboardingTutorialChrome {
    val cornerRadius = 24.dp

    @Composable
    fun Card(
        timeTheme: TimeTheme,
        modifier: Modifier = Modifier,
        content: @Composable () -> Unit,
    ) {
        val shape = RoundedCornerShape(cornerRadius)
        val borderBrush = if (timeTheme.usesLightForeground) {
            Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.18f),
                    Color.White.copy(alpha = 0.06f),
                ),
            )
        } else {
            Brush.linearGradient(
                colors = listOf(
                    Color(0xFFF0F0F0).copy(alpha = 0.8f),
                    Color(0xFFF0F0F0).copy(alpha = 0.3f),
                ),
            )
        }
        val fillBrush = if (timeTheme.usesLightForeground) {
            Brush.linearGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.08f),
                    Color.White.copy(alpha = 0.02f),
                ),
            )
        } else {
            Brush.verticalGradient(
                colors = listOf(
                    Color.White.copy(alpha = 0.88f),
                    Color.White.copy(alpha = 0.64f),
                ),
            )
        }
        val shadowColor = if (timeTheme.usesLightForeground) {
            Color.Black.copy(alpha = 0.24f)
        } else {
            Color.Black.copy(alpha = 0.04f)
        }

        Box(
            modifier = modifier
                .shadow(
                    elevation = if (timeTheme.usesLightForeground) 12.dp else 8.dp,
                    shape = shape,
                    spotColor = shadowColor,
                    ambientColor = shadowColor,
                )
                .clip(shape)
                .background(fillBrush)
                .border(width = 1.dp, brush = borderBrush, shape = shape),
        ) {
            content()
        }
    }
}

@Composable
fun OnboardingPrimaryCapsule(
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(percent = 50)
    Box(
        modifier = modifier
            .shadow(
                elevation = 8.dp,
                shape = shape,
                spotColor = MasjidlyColors.accent.copy(alpha = 0.35f),
                ambientColor = MasjidlyColors.accent.copy(alpha = 0.35f),
            )
            .clip(shape)
            .background(MasjidlyColors.activeGradientBrush)
            .border(1.dp, Color.White.copy(alpha = 0.25f), shape)
            .padding(vertical = 16.dp)
            .hapticClickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            style = rememberAppTextStyle(16f, FontWeight.SemiBold),
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
    }
}
