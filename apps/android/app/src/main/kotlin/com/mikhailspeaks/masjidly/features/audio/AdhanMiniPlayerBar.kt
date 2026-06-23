package com.mikhailspeaks.masjidly.features.audio

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.ui.home.MasjidlyColors
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.onboarding.OnboardingTutorialChrome
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import kotlin.math.roundToInt

/** Bottom chrome for in-app adhan playback — mirrors iOS `AdhanMiniPlayerBar`. */
@Composable
fun AdhanMiniPlayerBar(
    timeTheme: TimeTheme,
    language: AppLanguage,
    modifier: Modifier = Modifier,
) {
    val playback by AdhanSoundPreviewPlayer.state.collectAsState()

    AnimatedVisibility(
        visible = playback.showsMiniPlayer,
        modifier = modifier,
        enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
        exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
    ) {
        OnboardingTutorialChrome.Card(
            timeTheme = timeTheme,
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .padding(bottom = 12.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                AdhanProgressTrack(
                    fraction = playback.playbackFraction.toFloat(),
                    textColor = timeTheme.textColor,
                    language = language,
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = LocaleStrings.t("notification.channel.adhan", language),
                            style = rememberAppTextStyle(19f, FontWeight.SemiBold),
                            color = timeTheme.textColor,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            text = timeRemainingLabel(
                                current = playback.displayedCurrentTimeSec,
                                duration = playback.displayedDurationSec,
                                language = language,
                            ),
                            style = rememberAppTextStyle(14f, FontWeight.Normal),
                            color = timeTheme.textColor.copy(alpha = 0.82f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }

                    val playPauseLabel = if (playback.isPlayingForUI) {
                        LocaleStrings.t("audio.adhan.pause_a11y", language)
                    } else {
                        LocaleStrings.t("audio.adhan.play_a11y", language)
                    }
                    Box(
                        modifier = Modifier
                            .shadow(
                                elevation = 15.dp,
                                shape = CircleShape,
                                spotColor = MasjidlyColors.accent.copy(alpha = 0.35f),
                                ambientColor = MasjidlyColors.accent.copy(alpha = 0.35f),
                            )
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(MasjidlyColors.activeGradientBrush)
                            .border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape)
                            .hapticClickable { AdhanSoundPreviewPlayer.togglePlayPauseFromChrome() }
                            .semantics { contentDescription = playPauseLabel },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = if (playback.isPlayingForUI) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(20.dp),
                        )
                    }

                    Box(
                        modifier = Modifier
                            .size(width = 40.dp, height = 44.dp)
                            .hapticClickable { AdhanSoundPreviewPlayer.dismissMiniPlayer() }
                            .semantics {
                                contentDescription = LocaleStrings.t("audio.adhan.stop_a11y", language)
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = null,
                            tint = timeTheme.textColor.copy(alpha = 0.55f),
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AdhanProgressTrack(
    fraction: Float,
    textColor: Color,
    language: AppLanguage,
) {
    val progressLabel = LocaleStrings.t("audio.adhan.progress_a11y", language)
    val progressValue = LocaleStrings.format(
        "audio.adhan.progress_value_format",
        language,
        ((fraction * 100f).roundToInt()).toString(),
    )
    val clamped = fraction.coerceIn(0f, 1f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(4.dp)
            .clip(RoundedCornerShape(50))
            .background(textColor.copy(alpha = 0.18f))
            .semantics {
                contentDescription = "$progressLabel, $progressValue"
            },
    ) {
        if (clamped > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(clamped.coerceAtLeast(0.01f))
                    .height(4.dp)
                    .clip(RoundedCornerShape(50))
                    .background(MasjidlyColors.activeGradientBrush),
            )
        }
    }
}

private fun timeRemainingLabel(current: Double, duration: Double, language: AppLanguage): String {
    if (duration <= 0) return "—"
    val left = (duration - current).coerceAtLeast(0.0)
    return LocaleStrings.format(
        "audio.adhan.time_remaining_format",
        language,
        formatMmSs(current),
        formatMmSs(duration),
        formatMmSs(left),
    )
}

private fun formatMmSs(seconds: Double): String {
    val total = seconds.coerceAtLeast(0.0).toInt()
    val minutes = total / 60
    val remainder = total % 60
    return "$minutes:${remainder.toString().padStart(2, '0')}"
}
