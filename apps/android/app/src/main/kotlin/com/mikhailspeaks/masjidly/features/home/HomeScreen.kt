package com.mikhailspeaks.masjidly.features.home

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import com.mikhailspeaks.masjidly.ui.haptic.HapticTextButton
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.DailyPrayerTimes
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.PrayerLocalization
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.features.settings.AppReviewPromptCoordinator
import com.mikhailspeaks.masjidly.features.settings.MasjidlySupportMail
import com.mikhailspeaks.masjidly.features.onboarding.HomeOnboardingOverlay
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingFlowViewModel
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingHighlight
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingStep
import com.mikhailspeaks.masjidly.features.onboarding.rememberOnboardingLocationRequester
import com.mikhailspeaks.masjidly.features.qibla.rememberQiblaRotation
import com.mikhailspeaks.masjidly.ui.home.HomeDateFormatting
import com.mikhailspeaks.masjidly.ui.home.QiblaPrayerIcon
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.home.heroCountdownLabel
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoField
import java.util.Locale

private fun Context.hasLocationPermission(): Boolean {
    val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
    val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
    return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
}

@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    settingsStore: SettingsStore,
    onboardingViewModel: OnboardingFlowViewModel,
    onOpenTimetable: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val settingsRevision by settingsStore.revision.collectAsState()
    val state by viewModel.uiState.collectAsState()
    val onboardingState by onboardingViewModel.uiState.collectAsState()
    val locale = settingsStore.resolvedLocale()
    val language = settingsStore.appLanguage
    val uses24Hour = settingsStore.uses24HourTime
    val hideQibla = settingsStore.hideQiblaCompass
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var hasLocationPermission by remember { mutableStateOf(context.hasLocationPermission()) }
    var showReviewPrompt by remember { mutableStateOf(false) }
    var showReviewFeedbackPrompt by remember { mutableStateOf(false) }
    val requestOnboardingLocation = rememberOnboardingLocationRequester {
        settingsStore.hideQiblaCompass = false
        hasLocationPermission = true
    }

    LaunchedEffect(state.mosques) {
        onboardingViewModel.startIfNeeded(state.mosques)
    }

    val onboardingStep = onboardingState.currentStep
    LaunchedEffect(settingsStore.hasCompletedOnboarding, onboardingStep, state.loadState, settingsRevision) {
        AppReviewPromptCoordinator.recordLaunchIfNeeded(settingsStore)
        if (AppReviewPromptCoordinator.shouldShowEnjoymentPrompt(settingsStore, onboardingStep != null)) {
            showReviewPrompt = true
        }
    }

    val highlightPrayerShortcuts = onboardingStep is OnboardingStep.PrayerShortcut
    val highlightQibla = false
    val highlightTimetable = onboardingStep == OnboardingStep.OpenTimetable
    val highlightSettings = onboardingStep == OnboardingStep.OpenSettings

    // Mirrors iOS `handleQiblaAuthorizationStatusChange` — re-enable compass when location is granted.
    DisposableEffect(lifecycleOwner, settingsRevision) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                val granted = context.hasLocationPermission()
                hasLocationPermission = granted
                if (granted && settingsStore.hideQiblaCompass) {
                    settingsStore.hideQiblaCompass = false
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val dynamicTheme = TimeTheme.homeHeroTheme(state.displayedPrayerTimes, state.selectedPrayerIndex)
    val theme = settingsStore.resolvedTheme(dynamicTheme)

  @Suppress("UNUSED_VARIABLE")
    val _settingsTick = settingsRevision

    Box(
        modifier = Modifier
            .fillMaxSize(),
    ) {
        // Multi-layer atmospheric background matching iOS
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(theme.sky.baseColors))
        )
        // Horizon glow approximating iOS RadialGradient
        theme.sky.glowColor?.let { glow ->
            Canvas(modifier = Modifier.fillMaxSize()) {
                val center = androidx.compose.ui.geometry.Offset(size.width * 0.5f, size.height * 0.82f)
                val maxRadius = size.width * 0.7f
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            glow.copy(alpha = 0.6f * theme.sky.glowBaseAlpha),
                            glow.copy(alpha = 0.3f * theme.sky.glowBaseAlpha),
                            Color.Transparent,
                        ),
                        center = center,
                        radius = maxRadius,
                    ),
                    radius = maxRadius,
                    center = center,
                    blendMode = BlendMode.Screen,
                )
            }
        }
        when {
            state.displayedPrayerTimes != null && state.selectedMosque != null -> {
                HomePrayerContent(
                    mosque = state.selectedMosque!!,
                    prayerTimes = state.displayedPrayerTimes!!,
                    iqamahTimes = state.iqamahTimes,
                    displayedDate = state.displayedDate,
                    monthData = state.monthData,
                    selectedPrayerIndex = state.selectedPrayerIndex,
                    nextCountdown = state.nextCountdown,
                    uses24HourTime = uses24Hour,
                    asrPreference = settingsStore.asrIqamahPreference,
                    locale = locale,
                    language = language,
                    theme = theme,
                    hideQibla = hideQibla,
                    locationPermissionGranted = hasLocationPermission,
                    onSelectPrayer = { index ->
                        viewModel.selectPrayerIndex(index)
                        onboardingViewModel.handlePrayerShortcutTap(index)
                    },
                    highlightPrayerShortcuts = highlightPrayerShortcuts,
                    highlightQibla = highlightQibla,
                )
            }
            state.selectedMosque != null &&
                (state.loadState == HomeViewModel.LoadState.LOADED ||
                    state.loadState == HomeViewModel.LoadState.EMPTY) -> {
                MissingMonthState(
                    theme = theme,
                    language = language,
                    displayedDate = state.displayedDate,
                    locale = locale,
                    mosqueName = state.selectedMosque!!.name,
                    hasFallback = state.hasAvailablePrayerTimesFallback,
                    onGoToAvailable = viewModel::goToLastAvailablePrayerDate,
                )
            }
            state.loadState == HomeViewModel.LoadState.LOADING ||
                state.loadState == HomeViewModel.LoadState.IDLE -> {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = theme.textColor,
                )
            }
            else -> {
                HomeErrorState(
                    theme = theme,
                    language = language,
                    onRetry = {
                        if (state.selectedMosque != null) viewModel.manualRefresh() else viewModel.load()
                    },
                )
            }
        }

        HomeTopChrome(
            theme = theme,
            language = language,
            displayedDate = state.displayedDate,
            locale = locale,
            highlightTimetable = highlightTimetable,
            highlightSettings = highlightSettings,
            onOpenTimetable = {
                onboardingViewModel.handleTimetableOpened()
                onOpenTimetable()
            },
            onOpenSettings = {
                onboardingViewModel.handleSettingsOpened()
                onOpenSettings()
            },
            onPreviousDay = viewModel::goToPreviousDay,
            onNextDay = viewModel::goToNextDay,
        )

        onboardingStep?.let { step ->
            Box(modifier = Modifier.fillMaxSize()) {
                HomeOnboardingOverlay(
                step = step,
                theme = theme,
                language = language,
                mosques = state.mosques,
                onboarding = onboardingViewModel,
                onboardingState = onboardingState,
                onRequestLocation = requestOnboardingLocation,
                )
            }
        }
    }

    if (showReviewPrompt) {
        val copy = ReviewPromptCopy.forLanguage(language)
        AlertDialog(
            onDismissRequest = { showReviewPrompt = false },
            title = { Text(copy.enjoymentTitle, style = rememberAppTextStyle(18f, FontWeight.SemiBold)) },
            text = { Text(copy.enjoymentMessage, style = rememberAppTextStyle(15f)) },
            confirmButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    AppReviewPromptCoordinator.completePositive(context, settingsStore)
                }) { Text(copy.loveIt) }
            },
            dismissButton = {
                TextButton(onClick = {
                    showReviewPrompt = false
                    AppReviewPromptCoordinator.completeNegative(settingsStore)
                    showReviewFeedbackPrompt = true
                }) { Text(copy.notReally) }
            },
        )
    }

    if (showReviewFeedbackPrompt) {
        val copy = ReviewPromptCopy.forLanguage(language)
        AlertDialog(
            onDismissRequest = { showReviewFeedbackPrompt = false },
            title = { Text(copy.feedbackTitle, style = rememberAppTextStyle(18f, FontWeight.SemiBold)) },
            text = { Text(copy.feedbackMessage, style = rememberAppTextStyle(15f)) },
            confirmButton = {
                TextButton(onClick = {
                    showReviewFeedbackPrompt = false
                    MasjidlySupportMail.open(context, MasjidlySupportMail.Category.FEEDBACK, state.selectedMosque?.name)
                }) { Text(copy.feedbackSend) }
            },
            dismissButton = {
                TextButton(onClick = { showReviewFeedbackPrompt = false }) { Text(copy.feedbackLater) }
            },
        )
    }
}

private data class ReviewPromptCopy(
    val enjoymentTitle: String,
    val enjoymentMessage: String,
    val loveIt: String,
    val notReally: String,
    val feedbackTitle: String,
    val feedbackMessage: String,
    val feedbackSend: String,
    val feedbackLater: String,
) {
    companion object {
        fun forLanguage(language: AppLanguage): ReviewPromptCopy = when (language) {
            AppLanguage.ARABIC -> ReviewPromptCopy("هل تستمتع بمسجدلي؟", "إذا كان مسجدلي يساعدك، يسعدنا تقييمك.", "أحبه", "ليس كثيراً", "كيف يمكننا التحسين؟", "أخبرنا بما يمكن تحسينه.", "إرسال ملاحظات", "لاحقاً")
            AppLanguage.URDU -> ReviewPromptCopy("کیا آپ مسجدلی سے لطف اندوز ہو رہے ہیں؟", "اگر مسجدلی مددگار ہے تو ہمیں آپ کی ریٹنگ خوش کرے گی۔", "پسند ہے", "زیادہ نہیں", "ہم کیسے بہتر بنا سکتے ہیں؟", "ہمیں بتائیں کیا بہتر ہو سکتا ہے۔", "فیڈبیک بھیجیں", "بعد میں")
            AppLanguage.INDONESIAN -> ReviewPromptCopy("Menikmati Masjidly?", "Jika Masjidly membantu, kami senang menerima rating Anda.", "Suka", "Belum", "Bagaimana kami bisa lebih baik?", "Beri tahu kami apa yang bisa ditingkatkan.", "Kirim masukan", "Nanti")
            AppLanguage.ENGLISH -> ReviewPromptCopy("Enjoying Masjidly?", "If Masjidly is helping, we’d really appreciate a rating.", "Love it", "Not really", "How can we improve?", "Tell us what could be better.", "Send feedback", "Later")
        }
    }
}

@Composable
private fun HomeTopChrome(
    theme: TimeTheme,
    language: AppLanguage,
    displayedDate: Instant,
    locale: Locale,
    highlightTimetable: Boolean,
    highlightSettings: Boolean,
    onOpenTimetable: () -> Unit,
    onOpenSettings: () -> Unit,
    onPreviousDay: () -> Unit,
    onNextDay: () -> Unit,
) {
    val gregorian = HomeDateFormatting.gregorianDateString(displayedDate, locale)
    val hijrah = HomeDateFormatting.hijriDateString(displayedDate, locale)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(top = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Calendar button (leading) — mirrors iOS `calendarButton` + `leadingChromeInset`
            Box(modifier = Modifier.padding(start = 20.dp)) {
                OnboardingHighlight(
                    highlighted = highlightTimetable,
                    theme = theme,
                    shape = CircleShape,
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.18f))
                            .hapticClickable(onClick = onOpenTimetable),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.CalendarMonth,
                            contentDescription = LocaleStrings.t("accessibility.timetable", language),
                            tint = theme.textColor,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }
            }

            // Date navigator (center) — mirrors iOS `dateDisplay` HStack spacing 12
            Row(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DateChevronButton(
                    onClick = onPreviousDay,
                    contentDescription = LocaleStrings.t("accessibility.previous_day", language),
                ) {
                    Icon(
                        Icons.Default.ChevronLeft,
                        contentDescription = null,
                        tint = theme.textColor.copy(alpha = 0.5f),
                        modifier = Modifier.size(18.dp),
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = gregorian,
                        color = theme.textColor.copy(alpha = 0.6f),
                        style = rememberAppTextStyle(13f, FontWeight.SemiBold),
                        textAlign = TextAlign.Center,
                        letterSpacing = 1.sp,
                        maxLines = 1,
                    )
                    Text(
                        text = hijrah,
                        color = theme.textColor.copy(alpha = 0.4f),
                        textAlign = TextAlign.Center,
                        style = rememberAppTextStyle(10f, FontWeight.Medium),
                        letterSpacing = 0.8.sp,
                        maxLines = 1,
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                DateChevronButton(
                    onClick = onNextDay,
                    contentDescription = LocaleStrings.t("accessibility.next_day", language),
                ) {
                    Icon(
                        Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = theme.textColor.copy(alpha = 0.5f),
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            // Settings button (trailing) — mirrors iOS `settingsButton` + `trailingChromeInset`
            Box(modifier = Modifier.padding(end = 20.dp)) {
                OnboardingHighlight(
                    highlighted = highlightSettings,
                    theme = theme,
                    shape = CircleShape,
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.18f))
                            .hapticClickable(onClick = onOpenSettings),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = LocaleStrings.t("accessibility.settings", language),
                            tint = theme.textColor,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DateChevronButton(
    onClick: () -> Unit,
    contentDescription: String,
    icon: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .semantics { this.contentDescription = contentDescription }
            .hapticClickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        icon()
    }
}

@Composable
private fun HomePrayerContent(
    mosque: com.mikhailspeaks.masjidly.domain.Mosque,
    prayerTimes: DailyPrayerTimes,
    iqamahTimes: DailyIqamahTimes?,
    displayedDate: Instant,
    monthData: com.mikhailspeaks.masjidly.domain.MonthPrayerData?,
    selectedPrayerIndex: Int,
    nextCountdown: com.mikhailspeaks.masjidly.domain.NextPrayerCountdownResult?,
    uses24HourTime: Boolean,
    asrPreference: com.mikhailspeaks.masjidly.domain.AsrIqamahPreference,
    locale: Locale,
    language: AppLanguage,
    theme: TimeTheme,
    hideQibla: Boolean,
    locationPermissionGranted: Boolean,
    onSelectPrayer: (Int) -> Unit,
    highlightPrayerShortcuts: Boolean = false,
    highlightQibla: Boolean = false,
) {
    val context = LocalContext.current
    val showQiblaPointer = !hideQibla
    val qiblaRotation = rememberQiblaRotation(
        context,
        mosque = mosque,
        enabled = showQiblaPointer,
        locationPermissionGranted = locationPermissionGranted,
    )
    val mosqueSlug = mosque.slug

    val heroCountdownEnabled = mosqueSlug.isNotEmpty() && iqamahTimes != null
    var heroCountdownVisible by remember { mutableStateOf(false) }
    var heroCountdownLocked by remember { mutableStateOf(false) }
    val showHeroCountdown = heroCountdownVisible || heroCountdownLocked
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(heroCountdownEnabled) {
        if (!heroCountdownEnabled) return@LaunchedEffect
        while (true) {
            delay(1000)
            now = Instant.now()
        }
    }
    val heroPresentation = if (heroCountdownEnabled) {
        PrayerTimesEngine.heroCountdownPresentation(
            prayerTimes = prayerTimes,
            iqamahTimes = iqamahTimes!!,
            mosqueSlug = mosqueSlug,
            now = now,
            asrIqamahPreference = asrPreference,
        )
    } else {
        null
    }

    val isFriday = isFridayInSheffield(displayedDate)
    val jummahSlots = PrayerTimesEngine.splitJummahIqamahTimes(iqamahTimes?.jummah)
    val prayerEntries = buildPrayerEntries(prayerTimes, isFriday, jummahSlots, iqamahTimes?.jummah, language)

    val index = selectedPrayerIndex.coerceIn(0, prayerEntries.lastIndex)
    val entry = prayerEntries[index]
    val heroParts = PrayerTimesEngine.formatPrayerTimeHeroParts(entry.adhan, uses24HourTime, locale)
    val iqamahSubtitle = iqamahSubtitleLine(
        canonical = entry.canonical,
        adhanRaw = entry.adhan,
        daily = prayerTimes,
        iq = iqamahTimes,
        mosqueSlug = mosqueSlug,
        displayedDate = displayedDate,
        uses24Hour = uses24HourTime,
        asrPreference = asrPreference,
        locale = locale,
        jummahSlots = jummahSlots,
        language = language,
    )

    val quickInfo = computeQuickInfo(prayerTimes, monthData, displayedDate, uses24HourTime, locale)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .padding(top = 140.dp, start = 20.dp, end = 20.dp, bottom = 160.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Qibla orb always visible; pointer hidden when user deferred location (matches iOS).
        val countdownLabel = heroPresentation?.let { heroCountdownLabel(it.labelKind, language) }.orEmpty()
        val countdownSecs = heroPresentation?.let { PrayerTimesEngine.heroRemainingSeconds(it, now) } ?: 0
        val countdownTime = PrayerTimesEngine.formatHeroCountdownClock(countdownSecs)
        val countdownProgress = heroPresentation?.let { PrayerTimesEngine.heroProgress01(it, now) } ?: 0.0

        OnboardingHighlight(
            highlighted = highlightQibla,
            theme = theme,
            shape = CircleShape,
        ) {
            QiblaPrayerIcon(
                theme = theme,
                rotationDegrees = if (showQiblaPointer) qiblaRotation else null,
                showCountdown = showHeroCountdown && heroPresentation != null,
                countdownLabel = countdownLabel,
                countdownTime = countdownTime,
                countdownProgress = countdownProgress,
                onTap = if (heroPresentation != null) {
                    {
                        when {
                            heroCountdownLocked -> {
                                heroCountdownLocked = false
                                heroCountdownVisible = false
                            }
                            heroCountdownVisible -> heroCountdownVisible = false
                            else -> heroCountdownVisible = true
                        }
                    }
                } else {
                    null
                },
                onLongPress = if (heroCountdownEnabled) {
                    {
                        heroCountdownLocked = true
                        heroCountdownVisible = true
                    }
                } else {
                    null
                },
            )
        }
        Spacer(modifier = Modifier.height(60.dp))

        // Hero time (88pt, light weight, matching iOS) — clock + meridiem in one uniform Text
        Text(
            text = heroParts.meridiem?.let { "${heroParts.clock}\u2009${it}" } ?: heroParts.clock,
            style = rememberAppTextStyle(88f, FontWeight.Light),
            color = theme.textColor,
            letterSpacing = (-1.76f).sp,
            maxLines = 1,
            softWrap = false,
        )

        // Iqamah subtitle (26pt, matching iOS)
        iqamahSubtitle?.let {
            Text(
                text = it,
                style = rememberAppTextStyle(26f),
                color = theme.textColor.copy(alpha = 0.78f),
                maxLines = 2,
            )
        }

        // Spacer to push prayer name + letter picker to bottom
        Spacer(modifier = Modifier.weight(1f))

        // Prayer name (36pt, matching iOS)
        Text(
            text = entry.displayName,
            style = rememberAppTextStyle(36f),
            color = theme.textColor,
            letterSpacing = (-0.36f).sp,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Prayer letter picker — iOS highlights the whole HStack when in prayerShortcut step.
        Box(modifier = Modifier.padding(horizontal = 20.dp)) {
            OnboardingHighlight(
                highlighted = highlightPrayerShortcuts,
                theme = theme,
                shape = RoundedCornerShape(percent = 50),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally),
                ) {
                prayerEntries.forEachIndexed { i, item ->
                    val letter = run {
                        val name = item.displayName
                        val stripped = if (name.startsWith("ال")) name.drop(2) else name
                        stripped.first().toString().uppercase()
                    }
                    val isSelected = i == index
                    Text(
                        text = letter,
                        style = rememberAppTextStyle(
                            20f,
                            if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        ),
                        color = if (isSelected) {
                            theme.textColor
                        } else {
                            theme.textColor.copy(alpha = 0.38f)
                        },
                        modifier = Modifier
                            .heightIn(min = 36.dp)
                            .widthIn(min = 28.dp)
                            .hapticClickable { onSelectPrayer(i) },
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
        }
    }
}

private data class PrayerEntry(
    val canonical: String,
    val displayName: String,
    val adhan: String,
    val iqamahDisplay: String?,
)

private data class QuickInfo(val midnight: String, val lastThird: String)

private fun buildPrayerEntries(
    daily: DailyPrayerTimes,
    isFriday: Boolean,
    jummahSlots: List<String>,
    rawJummah: String?,
    language: AppLanguage,
): List<PrayerEntry> {
    val dhuhrCanonical = if (isFriday) "Jummah" else "Dhuhr"
    val dhuhrAdhan = if (isFriday) jummahSlots.firstOrNull() ?: daily.dhuhr else daily.dhuhr
    return listOf(
        PrayerEntry("Fajr", PrayerLocalization.displayName("Fajr", language), daily.fajr, null),
        PrayerEntry("Sunrise", PrayerLocalization.displayName("Sunrise", language), daily.sunrise, null),
        PrayerEntry(dhuhrCanonical, PrayerLocalization.displayName(dhuhrCanonical, language), dhuhrAdhan, null),
        PrayerEntry("Asr", PrayerLocalization.displayName("Asr", language), daily.asr, null),
        PrayerEntry("Maghrib", PrayerLocalization.displayName("Maghrib", language), daily.maghrib, null),
        PrayerEntry("Isha", PrayerLocalization.displayName("Isha", language), daily.isha, null),
    )
}

private fun computeQuickInfo(
    daily: DailyPrayerTimes,
    monthData: com.mikhailspeaks.masjidly.domain.MonthPrayerData?,
    displayedDate: Instant,
    uses24Hour: Boolean,
    locale: Locale,
): QuickInfo? {
    val day = PrayerTimesEngine.getDateInSheffield(displayedDate).day
    val nextFajr = monthData?.prayerTimes
        ?.sortedBy { it.date }
        ?.firstOrNull { it.date > day }
        ?.fajr
    val periods = PrayerTimesEngine.computeMidnightAndLastThird(daily.maghrib, nextFajr)
    val midnight = periods.midnight ?: return null
    val lastThird = periods.lastThird ?: return null
    return QuickInfo(
        midnight = PrayerTimesEngine.formatPrayerClockForDisplay(midnight, uses24Hour, locale),
        lastThird = PrayerTimesEngine.formatPrayerClockForDisplay(lastThird, uses24Hour, locale),
    )
}

@Composable
private fun PrayerCarouselCard(
    label: String,
    adhan: String,
    iqamah: String?,
    selected: Boolean,
    theme: TimeTheme,
    onClick: () -> Unit,
) {
    val bg = if (selected) theme.textColor.copy(alpha = 0.22f) else theme.textColor.copy(alpha = 0.12f)
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .hapticClickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = label, style = MaterialTheme.typography.labelLarge, color = theme.textColor)
        Spacer(modifier = Modifier.height(4.dp))
        Text(text = adhan, style = MaterialTheme.typography.bodyMedium, color = theme.textColor, fontWeight = FontWeight.Medium)
        iqamah?.let {
            Text(
                text = "Iq $it",
                style = MaterialTheme.typography.labelSmall,
                color = theme.textColor.copy(alpha = 0.75f),
            )
        }
    }
}

@Composable
private fun MissingMonthState(
    theme: TimeTheme,
    language: AppLanguage,
    displayedDate: Instant,
    locale: Locale,
    mosqueName: String,
    hasFallback: Boolean,
    onGoToAvailable: () -> Unit,
) {
    val context = LocalContext.current
    val monthTitle = DateTimeFormatter.ofPattern("LLLL yyyy", locale)
        .withZone(ZoneId.of("Europe/London"))
        .format(displayedDate)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp)
            .statusBarsPadding()
            .padding(top = 96.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = LocaleStrings.t("home.missing_times.title", language),
            style = MaterialTheme.typography.headlineSmall,
            color = theme.textColor,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = monthTitle,
            style = MaterialTheme.typography.bodyLarge,
            color = theme.textColor.copy(alpha = 0.72f),
            textAlign = TextAlign.Center,
        )
        if (hasFallback) {
            Spacer(modifier = Modifier.height(18.dp))
            HapticTextButton(
                onClick = onGoToAvailable,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(theme.textColor.copy(alpha = 0.92f)),
            ) {
                Text(
                    text = LocaleStrings.t("home.go_to_available_times", language),
                    color = if (theme.usesLightForeground) Color.Black else Color.White,
                )
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
        HapticTextButton(
            onClick = {
                MasjidlySupportMail.openMissingPrayerTimesEmail(
                    context = context,
                    mosqueName = mosqueName,
                    monthDisplay = monthTitle,
                    language = language,
                )
            },
            modifier = Modifier
                .clip(CircleShape)
                .background(Color.Transparent),
        ) {
            Text(
                text = LocaleStrings.t("home.missing_times.email_button", language),
                color = theme.textColor,
            )
        }
    }
}

@Composable
private fun HomeErrorState(theme: TimeTheme, language: AppLanguage, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = LocaleStrings.t("home.load_error", language),
            color = theme.textColor,
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.height(16.dp))
        HapticTextButton(
            onClick = onRetry,
            modifier = Modifier
                .clip(CircleShape)
                .background(theme.textColor.copy(alpha = 0.92f)),
        ) {
            Text(
                text = LocaleStrings.t("action.retry", language),
                color = if (theme.usesLightForeground) Color.Black else Color.White,
            )
        }
    }
}

private fun isFridayInSheffield(date: Instant): Boolean {
    val zdt = date.atZone(PrayerTimesEngine.sheffieldTimeZone)
    return zdt.dayOfWeek.value == 5 // Friday
}

private fun iqamahSubtitleLine(
    canonical: String,
    adhanRaw: String,
    daily: DailyPrayerTimes,
    iq: DailyIqamahTimes?,
    mosqueSlug: String,
    displayedDate: Instant,
    uses24Hour: Boolean,
    asrPreference: com.mikhailspeaks.masjidly.domain.AsrIqamahPreference,
    locale: Locale,
    jummahSlots: List<String>,
    language: AppLanguage,
): String? {
    if (canonical == "Sunrise") return null
    if (canonical == "Jummah" && jummahSlots.size >= 2) {
        val second = PrayerTimesEngine.formatPrayerClockForDisplay(jummahSlots[1], uses24Hour, locale)
        return LocaleStrings.format("home.jummah_2_format", language, second)
    }
    val raw = when (canonical) {
        "Fajr" -> iq?.let { PrayerTimesEngine.getIqamahTime("fajr", daily.fajr, it) }
        "Dhuhr" -> if (isFridayInSheffield(displayedDate)) null else PrayerTimesEngine.getDisplayIqamah(
            "dhuhr", daily.dhuhr, iq ?: return null, mosqueSlug, displayedDate, daily.maghrib,
        )
        "Jummah" -> null
        "Asr" -> iq?.let { PrayerTimesEngine.selectAsrIqamahTime(it.asr, daily.asr, asrPreference) }
        "Maghrib" -> iq?.let { PrayerTimesEngine.getDisplayIqamah("maghrib", daily.maghrib, it, mosqueSlug, displayedDate, daily.maghrib) }
        "Isha" -> iq?.let { PrayerTimesEngine.resolveIshaIqamahForDisplay(mosqueSlug, displayedDate, daily.isha, it, daily.maghrib) }
        else -> null
    } ?: return null
    if (raw.isBlank()) return null
    val adhanFormatted = PrayerTimesEngine.formatPrayerClockForDisplay(adhanRaw, uses24Hour, locale)
    val iqFormatted = PrayerTimesEngine.formatPrayerClockForDisplay(raw, uses24Hour, locale)
    val displayTime = if (iqFormatted == adhanFormatted) adhanFormatted else iqFormatted
    return LocaleStrings.format("home.iqamah_format", language, displayTime)
}
