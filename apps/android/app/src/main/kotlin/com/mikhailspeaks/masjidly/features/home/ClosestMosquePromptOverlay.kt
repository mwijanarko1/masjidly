package com.mikhailspeaks.masjidly.features.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingPrimaryButton
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingScrim
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingTutorialCard
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingTutorialCardStyle
import com.mikhailspeaks.masjidly.features.onboarding.onboardingCardMutedColor
import com.mikhailspeaks.masjidly.features.onboarding.onboardingCardTextColor
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.haptic.HapticTextButton
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

@Composable
fun ClosestMosquePromptOverlay(
    theme: ResolvedTheme,
    language: AppLanguage,
    closestMosqueName: String,
    selectedMosqueName: String,
    onUseClosest: () -> Unit,
    onKeepSelected: () -> Unit,
) {
    val cardStyle = OnboardingTutorialCardStyle.Light
    val cardTextColor = onboardingCardTextColor(theme, cardStyle)
    val cardMutedColor = onboardingCardMutedColor(theme, cardStyle)
    val title = LocaleStrings.t("home.closest_mosque_prompt.title", language)
    val message = LocaleStrings.t("home.closest_mosque_prompt.message", language)
    val useTitle = LocaleStrings.format("home.closest_mosque_prompt.use_format", language, closestMosqueName)
    val keepTitle = LocaleStrings.format("home.closest_mosque_prompt.keep_format", language, selectedMosqueName)

    Box(modifier = Modifier.fillMaxSize()) {
        OnboardingScrim(
            theme = theme,
            modifier = Modifier.hapticClickable(onClick = onKeepSelected),
        )

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            OnboardingTutorialCard(
                theme = theme,
                style = cardStyle,
                modifier = Modifier
                    .widthIn(max = 380.dp)
                    .fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(
                            text = title,
                            color = cardTextColor,
                            style = rememberAppTextStyle(26f, FontWeight.Bold),
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = message,
                            color = cardMutedColor,
                            style = rememberAppTextStyle(15f, FontWeight.Normal),
                            textAlign = TextAlign.Center,
                        )
                    }

                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        OnboardingPrimaryButton(
                            text = useTitle,
                            theme = theme,
                            onClick = onUseClosest,
                        )
                        HapticTextButton(onClick = onKeepSelected) {
                            Text(
                                text = keepTitle,
                                color = cardTextColor.copy(alpha = 0.7f),
                                style = rememberAppTextStyle(15f, FontWeight.Normal).copy(
                                    textDecoration = TextDecoration.Underline,
                                ),
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }
    }
}
