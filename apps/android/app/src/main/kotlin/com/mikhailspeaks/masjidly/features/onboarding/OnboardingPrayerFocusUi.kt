package com.mikhailspeaks.masjidly.features.onboarding

import android.content.Context
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusController
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusPermissions
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusPrayer
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusSettings
import com.mikhailspeaks.masjidly.features.prayerfocus.PrayerFocusStart
import com.mikhailspeaks.masjidly.features.settings.OnboardingReminderMenuPickerRow
import com.mikhailspeaks.masjidly.features.settings.PrayerFocusAppPickerSheet
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerBottomSheet
import com.mikhailspeaks.masjidly.features.settings.SettingsPickerOption
import com.mikhailspeaks.masjidly.ui.haptic.HapticTextButton
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.haptic.performMasjidlyButtonTapHaptic
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

/** Step 1: opt in or skip Prayer Focus. Mirrors iOS `OnboardingPrayerFocusIntroView`. */
@Composable
fun OnboardingPrayerFocusIntroScreen(
    theme: ResolvedTheme,
    language: AppLanguage,
    onTurnOn: () -> Unit,
    onSkip: () -> Unit,
) {
    PrayerFocusCenteredCard(theme) {
        PrayerFocusCardHeader(
            title = LocaleStrings.t("onboarding.prayer_focus.intro.title", language),
            message = LocaleStrings.t("onboarding.prayer_focus.intro.message", language),
            theme = theme,
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            OnboardingPrimaryButton(
                text = LocaleStrings.t("onboarding.prayer_focus.intro.turn_on", language),
                theme = theme,
                onClick = onTurnOn,
            )
            PrayerFocusSkipButton(theme, language, onSkip)
        }
    }
}

/**
 * Step 2: Android grants first (in place of iOS Screen Time), then choose apps.
 * Mirrors iOS `OnboardingPrayerFocusAppsView`; Prayer Focus itself turns on at Finish.
 */
@Composable
fun OnboardingPrayerFocusAppsScreen(
    theme: ResolvedTheme,
    language: AppLanguage,
    settingsStore: SettingsStore,
    onContinue: () -> Unit,
    onSkip: () -> Unit,
) {
    val context = LocalContext.current
    val revision by settingsStore.revision.collectAsState()
    var resumeTick by remember { mutableIntStateOf(0) }
    var pickerOpen by remember { mutableStateOf(false) }
    /** Grant the person was last sent to Settings for, to explain if they return without it. */
    var requested by remember { mutableStateOf<PrayerFocusGrant?>(null) }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) resumeTick += 1
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val missing = remember(resumeTick) { PrayerFocusGrant.firstMissing(context) }
    val selectedCount = remember(revision) { settingsStore.prayerFocus.selectedPackages.size }
    val cardTextColor = onboardingCardTextColor(theme)
    val cardMutedColor = onboardingCardMutedColor(theme)

    PrayerFocusCenteredCard(theme) {
        PrayerFocusCardHeader(
            title = LocaleStrings.t(
                if (missing == null) "onboarding.prayer_focus.apps.title" else "onboarding.prayer_focus.access.title",
                language,
            ),
            message = LocaleStrings.t(
                if (missing == null) "onboarding.prayer_focus.apps.message" else "onboarding.prayer_focus.access.message",
                language,
            ),
            theme = theme,
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            when {
                missing != null -> {
                    // Prominent disclosure before every Settings handoff.
                    Text(
                        text = LocaleStrings.t("settings.prayer_focus.disclosure", language),
                        color = cardMutedColor,
                        style = rememberAppTextStyle(14f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    // Plain numbered steps: the system screen is unfamiliar to many people.
                    Text(
                        text = LocaleStrings.t(missing.howtoKey, language),
                        color = cardTextColor,
                        style = rememberAppTextStyle(15f, FontWeight.Medium),
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OnboardingPrimaryButton(
                        text = LocaleStrings.t(missing.buttonKey, language),
                        theme = theme,
                        onClick = {
                            requested = missing
                            missing.open(context)
                        },
                    )
                    if (requested == missing) {
                        // Returned from Settings without granting it.
                        Text(
                            text = LocaleStrings.t(missing.deniedKey, language),
                            color = cardMutedColor,
                            style = rememberAppTextStyle(14f, FontWeight.Medium),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                selectedCount > 0 -> {
                    val chooseLabel = LocaleStrings.t("settings.prayer_focus.choose_apps", language)
                    // Tapping the summary reopens the picker, so no separate "Choose apps" button (iOS parity).
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(cardTextColor.copy(alpha = 0.08f))
                            .border(1.dp, cardTextColor.copy(alpha = 0.14f), RoundedCornerShape(18.dp))
                            .semantics { contentDescription = chooseLabel }
                            .hapticClickable { pickerOpen = true }
                            .padding(horizontal = 18.dp, vertical = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = LocaleStrings.format("settings.prayer_focus.count.apps", language, selectedCount),
                            color = cardTextColor,
                            style = rememberAppTextStyle(16f, FontWeight.Medium),
                            modifier = Modifier.weight(1f),
                        )
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = cardTextColor.copy(alpha = 0.5f),
                            modifier = Modifier.size(20.dp),
                        )
                    }
                    OnboardingPrimaryButton(
                        text = LocaleStrings.t("onboarding.continue", language),
                        theme = theme,
                        onClick = onContinue,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                else -> OnboardingPrimaryButton(
                    text = LocaleStrings.t("settings.prayer_focus.choose_apps", language),
                    theme = theme,
                    onClick = { pickerOpen = true },
                )
            }
            PrayerFocusSkipButton(theme, language, onSkip)
        }
    }

    PrayerFocusAppPickerSheet(
        visible = pickerOpen,
        selectedPackages = remember(revision) { settingsStore.prayerFocus.selectedPackages },
        theme = theme,
        language = language,
        onDismiss = { pickerOpen = false },
        onToggle = { packageName, selected ->
            val current = settingsStore.prayerFocus
            val packages = if (selected) current.selectedPackages + packageName else current.selectedPackages - packageName
            settingsStore.prayerFocus = current.copy(selectedPackages = packages)
        },
    )
}

/** Step 3: start, duration, and prayers. Mirrors iOS `OnboardingPrayerFocusScheduleView`. */
@Composable
fun OnboardingPrayerFocusScheduleScreen(
    theme: ResolvedTheme,
    language: AppLanguage,
    settingsStore: SettingsStore,
    onFinish: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    // Draft locally; nothing is scheduled until Finish.
    var draft by remember { mutableStateOf(settingsStore.prayerFocus.copy(isEnabled = true)) }
    var scheduleFailed by remember { mutableStateOf(false) }
    var startSheet by remember { mutableStateOf(false) }
    var durationSheet by remember { mutableStateOf(false) }
    val cardTextColor = onboardingCardTextColor(theme)
    val cardMutedColor = onboardingCardMutedColor(theme)

    fun startLabel(start: PrayerFocusStart) = LocaleStrings.t(
        if (start == PrayerFocusStart.ADHAN) "notification.channel.adhan" else "notification.channel.iqamah",
        language,
    )
    fun durationLabel(minutes: Int) = LocaleStrings.format("settings.reminder.minutes_format", language, minutes)

    OnboardingFullScreenShell(theme) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(top = 80.dp, bottom = 24.dp, start = 24.dp, end = 24.dp),
            contentAlignment = Alignment.TopCenter,
        ) {
            val maxCardHeight = maxHeight
            OnboardingTutorialCard(
                theme = theme,
                modifier = Modifier
                    .widthIn(max = 400.dp)
                    .heightIn(max = maxCardHeight),
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = LocaleStrings.t("onboarding.prayer_focus.schedule.title", language),
                            color = cardTextColor,
                            style = rememberAppTextStyle(23f, FontWeight.SemiBold),
                            letterSpacing = (-0.5f).sp,
                        )
                        Text(
                            text = LocaleStrings.t("onboarding.prayer_focus.schedule.message", language),
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
                        OnboardingReminderMenuPickerRow(
                            label = LocaleStrings.t("settings.prayer_focus.start.title", language),
                            displayValue = startLabel(draft.start),
                            textColor = cardTextColor,
                            onClick = { startSheet = true },
                        )
                        OnboardingReminderMenuPickerRow(
                            label = LocaleStrings.t("settings.prayer_focus.duration.title", language),
                            displayValue = durationLabel(draft.durationMinutes),
                            textColor = cardTextColor,
                            onClick = { durationSheet = true },
                        )
                        Text(
                            text = LocaleStrings.t("settings.prayer_focus.prayers.title", language),
                            color = cardMutedColor,
                            style = rememberAppTextStyle(16f, FontWeight.SemiBold),
                            letterSpacing = 0.5.sp,
                        )
                        Column {
                            PrayerFocusPrayer.entries.forEachIndexed { index, prayer ->
                                if (index > 0) OnboardingPickerDivider(cardTextColor)
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .heightIn(min = 48.dp)
                                        .padding(vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = LocaleStrings.t(prayer.labelKey, language),
                                        color = cardTextColor,
                                        style = rememberAppTextStyle(16f, FontWeight.Medium),
                                        modifier = Modifier.weight(1f),
                                    )
                                    Switch(
                                        checked = prayer in draft.prayers,
                                        onCheckedChange = { on ->
                                            view.performMasjidlyButtonTapHaptic()
                                            draft = draft.copy(prayers = if (on) draft.prayers + prayer else draft.prayers - prayer)
                                        },
                                        colors = SwitchDefaults.colors(checkedTrackColor = OnboardingAccent),
                                    )
                                }
                            }
                        }
                    }
                    if (scheduleFailed) {
                        Text(
                            text = LocaleStrings.t("settings.prayer_focus.status.failed", language),
                            color = cardMutedColor,
                            style = rememberAppTextStyle(14f, FontWeight.Medium),
                        )
                    }
                    OnboardingPrimaryButton(
                        text = LocaleStrings.t("onboarding.finish", language),
                        theme = theme,
                        onClick = {
                            // First activation point in onboarding.
                            settingsStore.prayerFocus = draft.copy(isEnabled = true)
                            PrayerFocusController.reconcile(context)
                            if (PrayerFocusController.status(context, settingsStore.prayerFocus) == PrayerFocusController.Status.Failed) {
                                settingsStore.prayerFocus = settingsStore.prayerFocus.copy(isEnabled = false)
                                PrayerFocusController.reconcile(context)
                                scheduleFailed = true
                            } else {
                                onFinish()
                            }
                        },
                    )
                }
            }
        }
    }

    SettingsPickerBottomSheet(
        visible = startSheet,
        title = LocaleStrings.t("settings.prayer_focus.start.title", language),
        options = PrayerFocusStart.entries.map { SettingsPickerOption(it.name, startLabel(it)) },
        selectedKey = draft.start.name,
        theme = theme,
        language = language,
        onDismiss = { startSheet = false },
        onSelect = { key -> draft = draft.copy(start = PrayerFocusStart.valueOf(key)) },
    )
    SettingsPickerBottomSheet(
        visible = durationSheet,
        title = LocaleStrings.t("settings.prayer_focus.duration.title", language),
        options = PrayerFocusSettings.durationOptions.map { SettingsPickerOption(it.toString(), durationLabel(it)) },
        selectedKey = draft.durationMinutes.toString(),
        theme = theme,
        language = language,
        onDismiss = { durationSheet = false },
        onSelect = { key -> key.toIntOrNull()?.let { draft = draft.copy(durationMinutes = it) } },
    )
}

/** Android grants that stand in for the iOS Screen Time authorization, in request order. */
private enum class PrayerFocusGrant(val buttonKey: String, val deniedKey: String, val howtoKey: String) {
    USAGE("settings.prayer_focus.allow_usage_access", "settings.prayer_focus.status.needs_usage_access", "settings.prayer_focus.howto.usage"),
    OVERLAY("settings.prayer_focus.allow_overlay", "settings.prayer_focus.status.needs_overlay", "settings.prayer_focus.howto.overlay"),
    EXACT_ALARM("settings.prayer_focus.allow_exact_alarm", "settings.prayer_focus.status.needs_exact_alarm", "settings.prayer_focus.howto.exact_alarm"),
    ;

    fun open(context: Context) = when (this) {
        USAGE -> PrayerFocusPermissions.openUsageAccessSettings(context)
        OVERLAY -> PrayerFocusPermissions.openOverlaySettings(context)
        EXACT_ALARM -> PrayerFocusPermissions.openExactAlarmSettings(context)
    }

    companion object {
        fun firstMissing(context: Context): PrayerFocusGrant? = when {
            !PrayerFocusPermissions.hasUsageAccess(context) -> USAGE
            !PrayerFocusPermissions.canDrawOverlays(context) -> OVERLAY
            !PrayerFocusPermissions.canScheduleExactAlarms(context) -> EXACT_ALARM
            else -> null
        }
    }
}

@Composable
private fun PrayerFocusCenteredCard(theme: ResolvedTheme, content: @Composable () -> Unit) {
    OnboardingFullScreenShell(theme) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center,
        ) {
            OnboardingTutorialCard(theme = theme, modifier = Modifier.widthIn(max = 400.dp)) {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    content()
                }
            }
        }
    }
}

@Composable
private fun PrayerFocusCardHeader(title: String, message: String, theme: ResolvedTheme) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = title,
            color = onboardingCardTextColor(theme),
            style = rememberAppTextStyle(23f, FontWeight.SemiBold),
            textAlign = TextAlign.Center,
            letterSpacing = (-0.5f).sp,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = message,
            color = onboardingCardMutedColor(theme),
            style = rememberAppTextStyle(16f),
            textAlign = TextAlign.Center,
            lineHeight = 22.sp,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun PrayerFocusSkipButton(theme: ResolvedTheme, language: AppLanguage, onSkip: () -> Unit) {
    HapticTextButton(
        onClick = onSkip,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = LocaleStrings.t("onboarding.location.skip", language),
            color = onboardingCardMutedColor(theme),
            style = rememberAppTextStyle(16f, FontWeight.SemiBold),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
