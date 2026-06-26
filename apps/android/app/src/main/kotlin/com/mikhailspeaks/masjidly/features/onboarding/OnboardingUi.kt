package com.mikhailspeaks.masjidly.features.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.features.settings.OnboardingMenuPickerRow
import com.mikhailspeaks.masjidly.features.settings.OnboardingReminderMenuPickerRow
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerBottomSheet
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerOption
import com.mikhailspeaks.masjidly.ui.haptic.HapticTextButton
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.haptic.performMasjidlyButtonTapHaptic
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

private val Accent = Color(0xFF47A6FF)
private val AccentDark = Color(0xFF2E8DFF)

enum class OnboardingTutorialCardStyle {
    /** Dark card at night, light card by day — follows [ResolvedTheme.usesLightForeground]. */
    Themed,
    /** Always the light `#FAFAFA` card with dark text. */
    Light,
}

private fun usesLightTutorialCard(theme: ResolvedTheme, style: OnboardingTutorialCardStyle): Boolean =
    when (style) {
        OnboardingTutorialCardStyle.Themed -> !theme.usesLightForeground
        OnboardingTutorialCardStyle.Light -> true
    }

@Composable
fun onboardingCardTextColor(
    theme: ResolvedTheme,
    style: OnboardingTutorialCardStyle = OnboardingTutorialCardStyle.Themed,
): Color = if (usesLightTutorialCard(theme, style)) Color(0xFF1A1A1A) else Color.White

@Composable
fun onboardingCardMutedColor(
    theme: ResolvedTheme,
    style: OnboardingTutorialCardStyle = OnboardingTutorialCardStyle.Themed,
): Color = onboardingCardTextColor(theme, style).copy(alpha = 0.75f)

enum class CoachMarkVariant {
    BelowTopChrome,
    AboveShortcutRow,
    BelowQiblaIconLower,
    FloatingBottom,
}

@Composable
fun OnboardingScrim(theme: ResolvedTheme, modifier: Modifier = Modifier) {
    val scrimColor = if (theme.usesLightForeground) {
        Color(0xFF050814).copy(alpha = 0.72f)
    } else {
        Color(0xFF0A0A0A).copy(alpha = 0.55f)
    }
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(scrimColor),
    )
}

@Composable
private fun OnboardingFullScreenShell(
    theme: ResolvedTheme,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(modifier = modifier.fillMaxSize()) {
        OnboardingScrim(theme)
        content()
    }
}

@Composable
fun OnboardingTutorialCard(
    theme: ResolvedTheme,
    modifier: Modifier = Modifier,
    style: OnboardingTutorialCardStyle = OnboardingTutorialCardStyle.Themed,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(24.dp)
    val usesLightCard = usesLightTutorialCard(theme, style)
    val cardColor = if (usesLightCard) {
        Color(0xFFFAFAFA)
    } else {
        Color(0xFF1C2033)
    }
    val borderColor = if (usesLightCard) {
        Color(0xFFE8E8E8)
    } else {
        Color.White.copy(alpha = 0.14f)
    }
    Box(
        modifier = modifier
            .clip(shape)
            .background(cardColor)
            .border(1.dp, borderColor, shape),
    ) {
        content()
    }
}

@Composable
fun OnboardingPrimaryButton(
    text: String,
    theme: ResolvedTheme,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    val capsule = RoundedCornerShape(percent = 50)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clip(capsule)
            .background(Brush.verticalGradient(listOf(Accent, AccentDark)), capsule)
            .border(1.dp, Color.White.copy(0.25f), capsule)
            .padding(vertical = 16.dp)
            .hapticClickable(enabled = enabled && !loading, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = Color.White,
                strokeWidth = 2.dp,
            )
        } else {
            Text(
                text = text,
                color = Color.White,
                style = rememberAppTextStyle(16f, FontWeight.SemiBold),
            )
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun OnboardingCoachMarkView(
    title: String,
    message: String,
    theme: ResolvedTheme,
    variant: CoachMarkVariant,
    primaryButtonTitle: String? = null,
    onPrimaryButton: (() -> Unit)? = null,
    secondaryButtonTitle: String? = null,
    onSecondaryButton: (() -> Unit)? = null,
    blocksBackgroundInteractions: Boolean = true,
) {
    val hasButtons = primaryButtonTitle != null && onPrimaryButton != null
    val blocksBackground = variant != CoachMarkVariant.FloatingBottom &&
        blocksBackgroundInteractions &&
        hasButtons
    val showsDimming = variant != CoachMarkVariant.FloatingBottom
    val scrimColor = if (theme.usesLightForeground) {
        Color.Black.copy(alpha = 0.12f)
    } else {
        Color.Black.copy(alpha = 0.08f)
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        if (showsDimming) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (blocksBackground) {
                            Modifier
                        } else {
                            Modifier.pointerInteropFilter { false }
                        },
                    ),
            ) {
                drawRect(scrimColor)
            }
        }

        val cardTextColor = onboardingCardTextColor(theme)
        val cardMutedColor = onboardingCardMutedColor(theme)
        val card = @Composable {
            OnboardingTutorialCard(theme = theme, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = title,
                        color = cardTextColor,
                        style = rememberAppTextStyle(19f, FontWeight.SemiBold),
                        letterSpacing = (-0.2f).sp,
                    )
                    Text(
                        text = message,
                        color = cardMutedColor,
                        style = rememberAppTextStyle(16f),
                        lineHeight = 22.sp,
                    )
                    if (primaryButtonTitle != null && onPrimaryButton != null) {
                        Spacer(modifier = Modifier.height(6.dp))
                        OnboardingPrimaryButton(
                            text = primaryButtonTitle,
                            theme = theme,
                            onClick = onPrimaryButton,
                        )
                    }
                    if (secondaryButtonTitle != null && onSecondaryButton != null) {
                        HapticTextButton(
                            onClick = onSecondaryButton,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                text = secondaryButtonTitle,
                                color = cardMutedColor,
                                style = rememberAppTextStyle(15f),
                                textDecoration = TextDecoration.Underline,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInteropFilter { false },
        ) {
            when (variant) {
                CoachMarkVariant.FloatingBottom -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .navigationBarsPadding()
                            .padding(horizontal = 24.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.Bottom,
                    ) {
                        card()
                    }
                }
                CoachMarkVariant.BelowTopChrome -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .statusBarsPadding()
                            .padding(top = 120.dp, start = 24.dp, end = 24.dp),
                    ) {
                        card()
                    }
                }
                CoachMarkVariant.AboveShortcutRow -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 24.dp),
                        verticalArrangement = Arrangement.Bottom,
                    ) {
                        card()
                        Spacer(modifier = Modifier.height(this@BoxWithConstraints.maxHeight * 0.31f))
                    }
                }
                CoachMarkVariant.BelowQiblaIconLower -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 24.dp),
                    ) {
                        Spacer(modifier = Modifier.height(this@BoxWithConstraints.maxHeight * 0.40f))
                        card()
                    }
                }
            }
        }
    }
}

/** Compose-safe equivalent of iOS negative padding — expands beyond measured bounds. */
private fun Modifier.expandOutward(amount: Dp): Modifier = layout { measurable, constraints ->
    val extra = amount.roundToPx()
    val width = constraints.maxWidth
    val height = constraints.maxHeight
    val placeable = measurable.measure(Constraints.fixed(width + extra * 2, height + extra * 2))
    layout(width, height) {
        placeable.place(-extra, -extra)
    }
}

/** iOS uses Capsule everywhere; on square targets that reads as a circle. */
private val OnboardingHighlightCapsule = RoundedCornerShape(percent = 50)

/**
 * Mirrors iOS `OnboardingHighlightModifier` — stroke overlay (-6dp), glow shadow, 1.08× scale.
 * Use [CircleShape] for square icon buttons; [OnboardingHighlightCapsule] for wide rows.
 */
@Composable
fun OnboardingHighlight(
    highlighted: Boolean,
    theme: ResolvedTheme,
    modifier: Modifier = Modifier,
    shape: Shape = CircleShape,
    content: @Composable () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (highlighted) 1.08f else 1f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = 320f),
        label = "onboardingHighlightScale",
    )
    val borderColor = theme.textColor.copy(alpha = 0.8f)
    val glowColor = theme.textColor.copy(alpha = 0.3f)

    Box(
        modifier = modifier.graphicsLayer {
            scaleX = scale
            scaleY = scale
            clip = false
        },
        contentAlignment = Alignment.Center,
    ) {
        content()
        if (highlighted) {
            Spacer(
                modifier = Modifier
                    .matchParentSize()
                    .graphicsLayer { clip = false }
                    .expandOutward(6.dp)
                    .shadow(
                        elevation = 8.dp,
                        shape = shape,
                        ambientColor = glowColor,
                        spotColor = glowColor,
                    )
                    .border(1.5.dp, borderColor, shape),
            )
        }
    }
}

@Composable
fun LanguageSelectionOnboardingScreen(
    theme: ResolvedTheme,
    selectedLanguage: AppLanguage,
    onSelectLanguage: (AppLanguage) -> Unit,
    onContinue: (AppLanguage) -> Unit,
) {
    var draft by remember(selectedLanguage) { mutableStateOf(selectedLanguage) }
    val cardTextColor = onboardingCardTextColor(theme)
    val cardMutedColor = onboardingCardMutedColor(theme)
    OnboardingFullScreenShell(theme) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            contentAlignment = Alignment.Center,
        ) {
            OnboardingTutorialCard(
                theme = theme,
                modifier = Modifier.widthIn(max = 400.dp),
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        AppLanguage.entries.forEach { lang ->
                            Text(
                                text = LocaleStrings.t("onboarding.language.title", lang),
                                color = cardTextColor,
                                style = rememberAppTextStyle(22f, FontWeight.SemiBold),
                                textAlign = TextAlign.Center,
                                letterSpacing = (-0.4f).sp,
                            )
                        }
                    }
                    Text(
                        text = LocaleStrings.t("onboarding.change_later", draft),
                        color = cardMutedColor,
                        style = rememberAppTextStyle(15f),
                        textAlign = TextAlign.Center,
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        AppLanguage.entries.forEach { language ->
                            val selected = draft == language
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(
                                        if (selected) cardTextColor.copy(0.14f) else cardTextColor.copy(0.06f),
                                    )
                                    .padding(horizontal = 16.dp, vertical = 14.dp)
                                    .hapticClickable { draft = language; onSelectLanguage(language) },
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = language.displayName,
                                    color = cardTextColor,
                                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                                    modifier = Modifier.weight(1f),
                                )
                                if (selected) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Accent)
                                }
                            }
                        }
                    }
                    OnboardingPrimaryButton(
                        text = LocaleStrings.t("onboarding.continue", draft),
                        theme = theme,
                        onClick = { onContinue(draft) },
                    )
                }
            }
        }
    }
}

@Composable
fun MosqueSelectionOnboardingScreen(
    mosques: List<Mosque>,
    theme: ResolvedTheme,
    language: AppLanguage,
    selectedMosqueId: String,
    isContinuing: Boolean,
    onSelectedMosqueIdChange: (String) -> Unit,
    onContinue: (Mosque) -> Unit,
) {
    val visible = remember(mosques) { MosqueSelection.visibleMosques(mosques) }
    val preselected = remember(visible, selectedMosqueId) {
        visible.firstOrNull { it.id == selectedMosqueId }
            ?: visible.firstOrNull { it.slug == com.mikhailspeaks.masjidly.domain.MosqueDefaults.DEFAULT_MOSQUE_SLUG }
            ?: visible.firstOrNull()
    }
    var countryKey by remember(preselected) {
        mutableStateOf(preselected?.let { MosqueSelection.countryGroupingKey(it) }.orEmpty())
    }
    var cityKey by remember(preselected) {
        mutableStateOf(preselected?.cityGroupingKey.orEmpty())
    }
    var mosqueId by remember(preselected, selectedMosqueId) {
        mutableStateOf(
            selectedMosqueId.ifEmpty { preselected?.id.orEmpty() },
        )
    }
    var countrySheet by remember { mutableStateOf(false) }
    var citySheet by remember { mutableStateOf(false) }
    var mosqueSheet by remember { mutableStateOf(false) }

    val countryOptions = remember(mosques) { MosqueSelection.countryOptions(mosques) }
    val cityOptions = remember(mosques, countryKey) { MosqueSelection.cityOptions(mosques, countryKey) }
    val mosquesInCity = remember(mosques, countryKey, cityKey) {
        MosqueSelection.mosquesInSelectedCity(mosques, countryKey, cityKey)
    }

    fun syncMosqueToCity(key: String) {
        val countryMosques = if (countryKey.isEmpty()) visible else MosqueSelection.mosquesInCountry(countryKey, mosques)
        val list = if (key.isEmpty()) countryMosques else MosqueSelection.mosquesInCity(key, countryMosques)
        val first = list.firstOrNull() ?: return
        if (list.none { it.id == mosqueId }) {
            mosqueId = first.id
            onSelectedMosqueIdChange(first.id)
        }
    }

    OnboardingFullScreenShell(theme) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center,
        ) {
            val cardTextColor = onboardingCardTextColor(theme)
            val cardMutedColor = onboardingCardMutedColor(theme)
            OnboardingTutorialCard(
                theme = theme,
                modifier = Modifier.widthIn(max = 420.dp),
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = LocaleStrings.t("onboarding.mosque.title", language),
                            color = cardTextColor,
                            style = rememberAppTextStyle(23f, FontWeight.SemiBold),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth(),
                            letterSpacing = (-0.5f).sp,
                        )
                        Text(
                            text = LocaleStrings.t("onboarding.mosque.message", language),
                            color = cardMutedColor,
                            style = rememberAppTextStyle(16f),
                            textAlign = TextAlign.Center,
                            lineHeight = 22.sp,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    Column {
                        OnboardingMenuPickerRow(
                            label = LocaleStrings.t("settings.country.picker", language),
                            displayValue = countryOptions.firstOrNull { it.first == countryKey }?.second.orEmpty(),
                            textColor = cardTextColor,
                            onClick = { countrySheet = true },
                        )
                        OnboardingPickerDivider(cardTextColor)
                        OnboardingMenuPickerRow(
                            label = LocaleStrings.t("settings.city.picker", language),
                            displayValue = cityOptions.firstOrNull { it.first == cityKey }?.second.orEmpty(),
                            textColor = cardTextColor,
                            onClick = { citySheet = true },
                        )
                        OnboardingPickerDivider(cardTextColor)
                        OnboardingMenuPickerRow(
                            label = LocaleStrings.t("settings.mosque.picker", language),
                            displayValue = mosquesInCity.firstOrNull { it.id == mosqueId }?.name.orEmpty(),
                            textColor = cardTextColor,
                            onClick = { mosqueSheet = true },
                            multilineValue = true,
                        )
                    }
                    OnboardingPrimaryButton(
                        text = LocaleStrings.t("onboarding.continue", language),
                        theme = theme,
                        onClick = {
                            val mosque = mosquesInCity.firstOrNull { it.id == mosqueId } ?: mosquesInCity.firstOrNull()
                            if (mosque != null) onContinue(mosque)
                        },
                        enabled = mosquesInCity.isNotEmpty() && !isContinuing,
                        loading = isContinuing,
                    )
                }
            }
        }
    }

    SettingsPickerBottomSheet(
        visible = countrySheet,
        title = LocaleStrings.t("settings.country.picker", language),
        options = countryOptions.map { SettingsPickerOption(it.first, it.second) },
        selectedKey = countryKey,
        theme = theme,
        language = language,
        onDismiss = { countrySheet = false },
        onSelect = { key ->
            countryKey = key
            val inCountryOpts = MosqueSelection.cityOptions(mosques, key)
            cityKey = inCountryOpts.firstOrNull()?.first.orEmpty()
            syncMosqueToCity(cityKey)
        },
    )
    SettingsPickerBottomSheet(
        visible = citySheet,
        title = LocaleStrings.t("settings.city.picker", language),
        options = cityOptions.map { SettingsPickerOption(it.first, it.second) },
        selectedKey = cityKey,
        theme = theme,
        language = language,
        onDismiss = { citySheet = false },
        onSelect = { key ->
            cityKey = key
            syncMosqueToCity(key)
        },
    )
    SettingsPickerBottomSheet(
        visible = mosqueSheet,
        title = LocaleStrings.t("settings.mosque.picker", language),
        options = mosquesInCity.map { SettingsPickerOption(it.id, it.name) },
        selectedKey = mosqueId,
        theme = theme,
        language = language,
        onDismiss = { mosqueSheet = false },
        onSelect = { id ->
            mosqueId = id
            onSelectedMosqueIdChange(id)
            mosques.firstOrNull { it.id == id }?.let { mosque ->
                countryKey = MosqueSelection.countryGroupingKey(mosque)
                cityKey = mosque.cityGroupingKey
            }
        },
    )
}

@Composable
private fun OnboardingPickerDivider(textColor: Color) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .height(0.5.dp)
            .background(textColor.copy(0.12f)),
    )
}

@Composable
fun OnboardingNotificationSetupScreen(
    theme: ResolvedTheme,
    language: AppLanguage,
    draft: OnboardingNotificationDraft,
    isSaving: Boolean,
    onDraftChange: (OnboardingNotificationDraft) -> Unit,
    onContinue: () -> Unit,
) {
    var adhanExpanded by remember { mutableStateOf(true) }
    var iqamahExpanded by remember { mutableStateOf(true) }
    var adhanReminderSheet by remember { mutableStateOf(false) }
    var iqamahReminderSheet by remember { mutableStateOf(false) }
    val reminderOptions = listOf<Int?>(null, 5, 10, 15, 30)

    val willEnableNotifications = draft.adhanEnabled ||
        draft.iqamahEnabled ||
        draft.preAdhanReminderMinutes != null ||
        draft.preIqamahReminderMinutes != null

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { _ -> onContinue() }

    fun finishNotificationSetup() {
        if (willEnableNotifications && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            onContinue()
        }
    }

    fun reminderLabel(minutes: Int?): String =
        if (minutes == null) {
            LocaleStrings.t("settings.reminder.off", language)
        } else {
            LocaleStrings.format("settings.reminder.minutes_format", language, minutes.toString())
        }

    OnboardingFullScreenShell(theme) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(top = 80.dp, bottom = 24.dp, start = 24.dp, end = 24.dp),
            contentAlignment = Alignment.TopCenter,
        ) {
            val maxCardHeight = maxHeight
            val cardTextColor = onboardingCardTextColor(theme)
            val cardMutedColor = onboardingCardMutedColor(theme)
            OnboardingTutorialCard(
                theme = theme,
                modifier = Modifier
                    .widthIn(max = 400.dp)
                    .heightIn(max = maxCardHeight),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = LocaleStrings.t("onboarding.notifications.title", language),
                            color = cardTextColor,
                            style = rememberAppTextStyle(23f, FontWeight.SemiBold),
                            letterSpacing = (-0.5f).sp,
                        )
                        Text(
                            text = LocaleStrings.t("onboarding.notifications.message", language),
                            color = cardMutedColor,
                            style = rememberAppTextStyle(16f),
                            lineHeight = 22.sp,
                        )
                    }
                    Column(
                        modifier = Modifier
                            .weight(1f, fill = false)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        CollapsiblePrayerSection(
                            title = LocaleStrings.t("onboarding.notifications.prayers_adhan", language),
                            expanded = adhanExpanded,
                            onToggle = { adhanExpanded = !adhanExpanded },
                            textColor = cardTextColor,
                            language = language,
                        prayers = listOf(
                            "fajr" to "settings.notification.fajr",
                            "dhuhrJummah" to "settings.notification.dhuhr_jummah",
                            "asr" to "settings.notification.asr",
                            "maghrib" to "settings.notification.maghrib",
                            "isha" to "settings.notification.isha",
                        ),
                        isEnabled = { key ->
                            when (key) {
                                "fajr" -> draft.adhanFajr
                                "dhuhrJummah" -> draft.adhanDhuhrJummah
                                "asr" -> draft.adhanAsr
                                "maghrib" -> draft.adhanMaghrib
                                "isha" -> draft.adhanIsha
                                else -> true
                            }
                        },
                        onTogglePrayer = { key, enabled ->
                            onDraftChange(
                                when (key) {
                                    "fajr" -> draft.copy(adhanFajr = enabled)
                                    "dhuhrJummah" -> draft.copy(adhanDhuhrJummah = enabled)
                                    "asr" -> draft.copy(adhanAsr = enabled)
                                    "maghrib" -> draft.copy(adhanMaghrib = enabled)
                                    "isha" -> draft.copy(adhanIsha = enabled)
                                    else -> draft
                                },
                            )
                        },
                    )
                    OnboardingPickerDivider(cardTextColor)
                    CollapsiblePrayerSection(
                        title = LocaleStrings.t("onboarding.notifications.prayers_iqamah", language),
                        expanded = iqamahExpanded,
                        onToggle = { iqamahExpanded = !iqamahExpanded },
                        textColor = cardTextColor,
                        language = language,
                        prayers = listOf(
                            "fajr" to "settings.notification.fajr",
                            "dhuhrJummah" to "settings.notification.dhuhr_jummah",
                            "asr" to "settings.notification.asr",
                            "maghrib" to "settings.notification.maghrib",
                            "isha" to "settings.notification.isha",
                        ),
                        isEnabled = { key ->
                            when (key) {
                                "fajr" -> draft.iqamahFajr
                                "dhuhrJummah" -> draft.iqamahDhuhrJummah
                                "asr" -> draft.iqamahAsr
                                "maghrib" -> draft.iqamahMaghrib
                                "isha" -> draft.iqamahIsha
                                else -> true
                            }
                        },
                        onTogglePrayer = { key, enabled ->
                            onDraftChange(
                                when (key) {
                                    "fajr" -> draft.copy(iqamahFajr = enabled)
                                    "dhuhrJummah" -> draft.copy(iqamahDhuhrJummah = enabled)
                                    "asr" -> draft.copy(iqamahAsr = enabled)
                                    "maghrib" -> draft.copy(iqamahMaghrib = enabled)
                                    "isha" -> draft.copy(iqamahIsha = enabled)
                                    else -> draft
                                },
                            )
                        },
                    )
                    OnboardingPickerDivider(cardTextColor)
                    Text(
                        text = LocaleStrings.t("settings.reminders.title", language),
                        color = cardMutedColor,
                        style = rememberAppTextStyle(16f, FontWeight.SemiBold),
                        letterSpacing = 0.5.sp,
                    )
                    OnboardingReminderMenuPickerRow(
                        label = LocaleStrings.t("settings.reminder.before_adhan", language),
                        displayValue = reminderLabel(draft.preAdhanReminderMinutes),
                        textColor = cardTextColor,
                        onClick = { adhanReminderSheet = true },
                    )
                    OnboardingReminderMenuPickerRow(
                        label = LocaleStrings.t("settings.reminder.before_iqamah", language),
                        displayValue = reminderLabel(draft.preIqamahReminderMinutes),
                        textColor = cardTextColor,
                        onClick = { iqamahReminderSheet = true },
                    )
                }
                OnboardingPrimaryButton(
                    text = LocaleStrings.t("onboarding.finish", language),
                    theme = theme,
                    onClick = ::finishNotificationSetup,
                    loading = isSaving,
                    enabled = !isSaving,
                )
            }
        }
    }
    }

    SettingsPickerBottomSheet(
        visible = adhanReminderSheet,
        title = LocaleStrings.t("settings.reminder.before_adhan", language),
        options = reminderOptions.map { SettingsPickerOption(it?.toString() ?: "off", reminderLabel(it)) },
        selectedKey = draft.preAdhanReminderMinutes?.toString() ?: "off",
        theme = theme,
        language = language,
        onDismiss = { adhanReminderSheet = false },
        onSelect = { key ->
            onDraftChange(draft.copy(preAdhanReminderMinutes = if (key == "off") null else key.toIntOrNull()))
        },
    )
    SettingsPickerBottomSheet(
        visible = iqamahReminderSheet,
        title = LocaleStrings.t("settings.reminder.before_iqamah", language),
        options = reminderOptions.map { SettingsPickerOption(it?.toString() ?: "off", reminderLabel(it)) },
        selectedKey = draft.preIqamahReminderMinutes?.toString() ?: "off",
        theme = theme,
        language = language,
        onDismiss = { iqamahReminderSheet = false },
        onSelect = { key ->
            onDraftChange(draft.copy(preIqamahReminderMinutes = if (key == "off") null else key.toIntOrNull()))
        },
    )
}

@Composable
private fun CollapsiblePrayerSection(
    title: String,
    expanded: Boolean,
    onToggle: () -> Unit,
    textColor: Color,
    language: AppLanguage,
    prayers: List<Pair<String, String>>,
    isEnabled: (String) -> Boolean,
    onTogglePrayer: (String, Boolean) -> Unit,
) {
    val view = LocalView.current
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp)
                .hapticClickable(onClick = onToggle),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = if (expanded) Icons.Default.KeyboardArrowDown else Icons.Default.KeyboardArrowRight,
                contentDescription = null,
                tint = textColor,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = title,
                color = textColor,
                style = rememberAppTextStyle(18f, FontWeight.SemiBold),
            )
        }
        if (expanded) {
            prayers.forEachIndexed { index, (key, labelKey) ->
                if (index > 0) OnboardingPickerDivider(textColor)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 8.dp, top = 4.dp, bottom = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = LocaleStrings.t(labelKey, language),
                        color = textColor,
                        style = rememberAppTextStyle(16f, FontWeight.Medium),
                        modifier = Modifier.weight(1f),
                    )
                    Switch(
                        checked = isEnabled(key),
                        onCheckedChange = { enabled ->
                            view.performMasjidlyButtonTapHaptic()
                            onTogglePrayer(key, enabled)
                        },
                        colors = SwitchDefaults.colors(checkedTrackColor = Accent),
                    )
                }
            }
        }
    }
}

@Composable
fun HomeOnboardingOverlay(
    step: OnboardingStep,
    theme: ResolvedTheme,
    language: AppLanguage,
    mosques: List<Mosque>,
    onboarding: OnboardingFlowViewModel,
    onboardingState: OnboardingFlowViewModel.UiState,
    onRequestLocation: () -> Unit,
) {
    when (step) {
        OnboardingStep.ChooseLanguage -> LanguageSelectionOnboardingScreen(
            theme = theme,
            selectedLanguage = onboardingState.selectedLanguage,
            onSelectLanguage = { /* local draft only */ },
            onContinue = onboarding::selectLanguage,
        )
        OnboardingStep.ChooseMosque -> MosqueSelectionOnboardingScreen(
            mosques = mosques,
            theme = theme,
            language = language,
            selectedMosqueId = onboardingState.selectedMosqueId,
            isContinuing = onboardingState.isSelectingMosque,
            onSelectedMosqueIdChange = onboarding::updateSelectedMosqueId,
            onContinue = onboarding::selectMosque,
        )
        is OnboardingStep.PrayerShortcut -> Box(modifier = Modifier.fillMaxSize()) {
            OnboardingCoachMarkView(
                title = LocaleStrings.t("onboarding.shortcut.title", language),
                message = LocaleStrings.t("onboarding.shortcut.message_format", language),
                theme = theme,
                variant = CoachMarkVariant.AboveShortcutRow,
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .navigationBarsPadding()
                    .padding(bottom = 24.dp),
                contentAlignment = Alignment.BottomCenter,
            ) {
                HapticTextButton(
                    onClick = onboarding::skipToTutorialEnd,
                    modifier = Modifier
                        .clip(CircleShape)
                        .border(1.dp, theme.textColor.copy(0.27f), CircleShape)
                        .padding(horizontal = 28.dp, vertical = 12.dp),
                ) {
                    Text(
                        text = LocaleStrings.t("onboarding.skip_tutorial", language),
                        color = theme.textColor.copy(0.72f),
                        style = rememberAppTextStyle(15f, FontWeight.SemiBold),
                    )
                }
            }
        }
        OnboardingStep.QiblaCountdown -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.qibla_countdown.title", language),
            message = LocaleStrings.t("onboarding.qibla_countdown.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowQiblaIconLower,
            primaryButtonTitle = LocaleStrings.t("onboarding.continue", language),
            onPrimaryButton = onboarding::completeQiblaCountdownStep,
            blocksBackgroundInteractions = false,
        )
        OnboardingStep.Qibla -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.qibla.title", language),
            message = LocaleStrings.t("onboarding.qibla.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowQiblaIconLower,
            primaryButtonTitle = LocaleStrings.t("onboarding.qibla.allow_location", language),
            onPrimaryButton = {
                onRequestLocation()
                onboarding.completeQiblaOnboardingAllowingLocationRequest()
            },
            secondaryButtonTitle = LocaleStrings.t("onboarding.qibla.later", language),
            onSecondaryButton = onboarding::completeQiblaOnboardingDeferringLocation,
        )
        OnboardingStep.OpenTimetable -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.timetable.title", language),
            message = LocaleStrings.t("onboarding.timetable.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowTopChrome,
            blocksBackgroundInteractions = false,
        )
        OnboardingStep.OpenSettings -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.settings.title", language),
            message = LocaleStrings.t("onboarding.settings.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowTopChrome,
            blocksBackgroundInteractions = false,
        )
        OnboardingStep.Notifications -> OnboardingNotificationSetupScreen(
            theme = theme,
            language = language,
            draft = onboardingState.notificationDraft,
            isSaving = onboardingState.isCompletingNotifications,
            onDraftChange = { draft -> onboarding.updateNotificationDraft { draft } },
            onContinue = onboarding::completeNotificationSetup,
        )
        OnboardingStep.ExploreTimetable,
        OnboardingStep.CloseTimetable,
        OnboardingStep.ExploreSettings,
        OnboardingStep.CloseSettings,
        -> Unit
    }
}

@Composable
fun TimetableOnboardingOverlay(
    step: OnboardingStep,
    theme: ResolvedTheme,
    language: AppLanguage,
    onboarding: OnboardingFlowViewModel,
) {
    when (step) {
        OnboardingStep.ExploreTimetable -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.explore_timetable.title", language),
            message = LocaleStrings.t("onboarding.explore_timetable.message", language),
            theme = theme,
            variant = CoachMarkVariant.FloatingBottom,
            primaryButtonTitle = LocaleStrings.t("onboarding.continue", language),
            onPrimaryButton = onboarding::acknowledgeTimetableExplore,
        )
        OnboardingStep.CloseTimetable -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.close_timetable.title", language),
            message = LocaleStrings.t("onboarding.close_timetable.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowTopChrome,
            blocksBackgroundInteractions = false,
        )
        else -> Unit
    }
}

@Composable
fun SettingsOnboardingOverlay(
    step: OnboardingStep,
    theme: ResolvedTheme,
    language: AppLanguage,
    onboarding: OnboardingFlowViewModel,
) {
    when (step) {
        OnboardingStep.ExploreSettings -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.explore_settings.title", language),
            message = LocaleStrings.t("onboarding.explore_settings.message", language),
            theme = theme,
            variant = CoachMarkVariant.FloatingBottom,
            primaryButtonTitle = LocaleStrings.t("onboarding.continue", language),
            onPrimaryButton = onboarding::acknowledgeSettingsExplore,
        )
        OnboardingStep.CloseSettings -> OnboardingCoachMarkView(
            title = LocaleStrings.t("onboarding.close_settings.title", language),
            message = LocaleStrings.t("onboarding.close_settings.message", language),
            theme = theme,
            variant = CoachMarkVariant.BelowTopChrome,
            blocksBackgroundInteractions = false,
        )
        else -> Unit
    }
}

@Composable
fun rememberOnboardingLocationRequester(onGranted: () -> Unit = {}): () -> Unit {
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        val granted = results[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            results[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) onGranted()
    }
    return {
        launcher.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
        )
    }
}
