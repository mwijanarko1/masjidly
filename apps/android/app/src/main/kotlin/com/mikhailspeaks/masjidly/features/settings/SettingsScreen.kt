package com.mikhailspeaks.masjidly.features.settings

import android.Manifest
import android.content.Intent
import android.location.Location
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.haptic.rememberHapticOnClick
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.border
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.mikhailspeaks.masjidly.BuildConfig
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AdhanPrayerToggle
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.IqamahPrayerToggle
import com.mikhailspeaks.masjidly.domain.LocaleStrings
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.domain.NotificationSettings
import com.mikhailspeaks.masjidly.domain.PrayerLocalization
import com.mikhailspeaks.masjidly.domain.adhanEnabled
import com.mikhailspeaks.masjidly.domain.iqamahEnabled
import com.mikhailspeaks.masjidly.domain.localizedLabel
import com.mikhailspeaks.masjidly.domain.setAdhanEnabled
import com.mikhailspeaks.masjidly.domain.setIqamahEnabled
import com.mikhailspeaks.masjidly.domain.syncMasterFlag
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingFlowViewModel
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingHighlight
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingStep
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationPermissions
import com.mikhailspeaks.masjidly.features.onboarding.SettingsOnboardingOverlay
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.SkyGradientSet
import com.mikhailspeaks.masjidly.ui.home.ThemeMode
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.widget.updateAllMasjidlyWidgets
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import android.content.pm.PackageManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    homeViewModel: HomeViewModel,
    settingsViewModel: SettingsViewModel,
    settingsStore: SettingsStore,
    onboardingViewModel: OnboardingFlowViewModel,
    onBack: () -> Unit,
    onTestWhatsNew: () -> Unit = {},
    onTestUpdatePrompt: () -> Unit = {},
) {
    val homeState by homeViewModel.uiState.collectAsState()
    val onboardingState by onboardingViewModel.uiState.collectAsState()
    val settingsRevision by settingsStore.revision.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val mosques = homeState.mosques

    @Suppress("UNUSED_VARIABLE")
    val _settingsTick = settingsRevision

    val dynamicTheme = TimeTheme.homeHeroTheme(homeState.displayedPrayerTimes, homeState.selectedPrayerIndex)
    val theme = settingsStore.resolvedTheme(dynamicTheme)
    val language = settingsStore.appLanguage

    val countries = remember(mosques) { MosqueSelection.countryOptions(mosques) }
    val effectiveCountryKey = remember(
        mosques,
        settingsRevision,
        settingsStore.selectedCountryGroupingKey,
        settingsStore.selectedMosqueId,
    ) {
        MosqueSelection.effectiveCountryGroupingKey(
            mosques = mosques,
            storedKey = settingsStore.selectedCountryGroupingKey,
            selectedMosqueId = settingsStore.selectedMosqueId,
        )
    }

    val cities = remember(mosques, effectiveCountryKey) {
        MosqueSelection.cityOptions(mosques, effectiveCountryKey)
    }
    val effectiveCityKey = remember(
        mosques,
        effectiveCountryKey,
        settingsRevision,
        settingsStore.selectedCityGroupingKey,
        settingsStore.selectedMosqueId,
    ) {
        MosqueSelection.effectiveCityGroupingKey(
            mosques = mosques,
            countryKey = effectiveCountryKey,
            storedKey = settingsStore.selectedCityGroupingKey,
            selectedMosqueId = settingsStore.selectedMosqueId,
        )
    }

    val mosquesInCity = remember(mosques, effectiveCountryKey, effectiveCityKey) {
        MosqueSelection.mosquesInSelectedCity(mosques, effectiveCountryKey, effectiveCityKey)
    }
    val effectiveMosqueId = remember(mosquesInCity, settingsRevision, settingsStore.selectedMosqueId) {
        MosqueSelection.effectiveSelectedMosqueId(mosquesInCity, settingsStore.selectedMosqueId)
    }

    val locationProvider = remember { SettingsClosestMosqueLocationProvider(context) }
    var userLocation by remember { mutableStateOf<Location?>(null) }
    var hasLocationPermission by remember {
        mutableStateOf(locationProvider.hasLocationPermission())
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { _ ->
        hasLocationPermission = locationProvider.hasLocationPermission()
        if (hasLocationPermission && settingsStore.hideQiblaCompass) {
            settingsStore.hideQiblaCompass = false
        }
    }

    LaunchedEffect(hasLocationPermission) {
        if (hasLocationPermission && settingsStore.hideQiblaCompass) {
            settingsStore.hideQiblaCompass = false
        }
    }

    LaunchedEffect(settingsStore.hideQiblaCompass, hasLocationPermission, settingsRevision) {
        if (settingsStore.hideQiblaCompass) {
            userLocation = null
            locationProvider.clear()
            return@LaunchedEffect
        }

        if (!hasLocationPermission) {
            userLocation = null
            locationProvider.clear()
            return@LaunchedEffect
        }

        locationProvider.start()
        userLocation = locationProvider.fetchLocation()
    }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, settingsStore.hideQiblaCompass) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                hasLocationPermission = locationProvider.hasLocationPermission()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val closestMosque = remember(mosques, userLocation, settingsStore.hideQiblaCompass, hasLocationPermission) {
        if (settingsStore.hideQiblaCompass || !hasLocationPermission) return@remember null
        val location = userLocation ?: return@remember null
        MosqueSelection.closestMosque(mosques, location.latitude, location.longitude)
    }

    val supportsMultipleAsrAdhan = settingsViewModel.supportsMultipleAsrAdhan
    val selectedMosqueName = remember(mosques, settingsStore.selectedMosqueId) {
        settingsStore.selectedMosqueId?.let { id -> mosques.firstOrNull { it.id == id }?.name }
    }

    LaunchedEffect(settingsStore.selectedMosqueId, settingsStore.selectedMosqueSlug) {
        settingsViewModel.refreshAsrAdhanSupport()
    }

    val shouldShowLocationRecovery = settingsStore.hideQiblaCompass || !hasLocationPermission

    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(theme.sky.baseColors)),
        )
        theme.sky.glowColor?.let { glow ->
            Canvas(modifier = Modifier.fillMaxSize()) {
                val center = Offset(size.width * 0.79f, size.height * -0.06f)
                val radius = size.width * 0.58f
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            glow.copy(alpha = 0.12f * theme.sky.glowBaseAlpha),
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

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState()),
        ) {
            // Title header matching iOS: large title + X close
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 22.dp, end = 22.dp, top = 16.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = LocaleStrings.t("settings.navigation.title", language),
                    style = rememberAppTextStyle(34f, FontWeight.Bold),
                    color = theme.textColor,
                    modifier = Modifier.weight(1f),
                )
                OnboardingHighlight(
                    highlighted = onboardingState.currentStep == OnboardingStep.CloseSettings,
                    theme = theme,
                    shape = CircleShape,
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(theme.textColor.copy(alpha = 0.1f))
                            .hapticClickable(onClick = onBack),
                        contentAlignment = Alignment.Center,
                    ) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = LocaleStrings.t("accessibility.close", language),
                        tint = theme.textColor,
                        modifier = Modifier.size(18.dp),
                    )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .padding(horizontal = 22.dp, vertical = 8.dp),
            ) {
                // Mosque section
                SettingsPlainSection(LocaleStrings.t("settings.section.mosque.title", language), theme) {
                    PickerRow(LocaleStrings.t("settings.country.picker", language), countries, effectiveCountryKey, language, theme) { key ->
                        settingsStore.selectedCountryGroupingKey = key
                        val inCountry = MosqueSelection.mosquesInCountry(key, mosques)
                        val cityKey = MosqueSelection.effectiveCityGroupingKey(
                            mosques = mosques,
                            countryKey = key,
                            storedKey = settingsStore.selectedCityGroupingKey,
                            selectedMosqueId = settingsStore.selectedMosqueId,
                        )
                        val inCity = MosqueSelection.mosquesInCity(cityKey, inCountry)
                        if (inCity.any { it.id == settingsStore.selectedMosqueId }) return@PickerRow
                        inCountry.firstOrNull()?.let { mosque ->
                            selectMosque(mosque, settingsStore, homeViewModel, settingsViewModel)
                        }
                    }
                    SettingsDivider(theme)
                    PickerRow(LocaleStrings.t("settings.city.picker", language), cities, effectiveCityKey, language, theme) { key ->
                        settingsStore.selectedCityGroupingKey = key
                        val inCountry = MosqueSelection.mosquesInCountry(effectiveCountryKey, mosques)
                        val inCity = MosqueSelection.mosquesInCity(key, inCountry)
                        if (inCity.any { it.id == settingsStore.selectedMosqueId }) return@PickerRow
                        inCity.firstOrNull()?.let { mosque ->
                            selectMosque(mosque, settingsStore, homeViewModel, settingsViewModel)
                        }
                    }
                    SettingsDivider(theme)
                    MosquePickerRow(LocaleStrings.t("settings.mosque.picker", language), mosquesInCity, effectiveMosqueId, language, theme) { mosque ->
                        selectMosque(mosque, settingsStore, homeViewModel, settingsViewModel)
                    }
                    if (closestMosque != null) {
                        SettingsDivider(theme)
                        ClosestMosqueRow(closestMosque!!, language, theme) { mosque ->
                            selectMosque(mosque, settingsStore, homeViewModel, settingsViewModel)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Display section
                SettingsPlainSection(LocaleStrings.t("settings.section.display.title", language), theme) {
                    SettingsToggleRow(LocaleStrings.t("settings.time.24h.title", language), settingsStore.uses24HourTime, theme) {
                        settingsStore.uses24HourTime = it
                    }
                    if (supportsMultipleAsrAdhan) {
                        SettingsDivider(theme)
                        PickerRow(
                            label = LocaleStrings.t("settings.asr_adhan_time", language),
                            options = listOf(
                                AsrIqamahPreference.FIRST.wireValue to LocaleStrings.t("settings.asr_first", language),
                                AsrIqamahPreference.SECOND.wireValue to LocaleStrings.t("settings.asr_second", language),
                            ),
                            selectedKey = settingsStore.asrIqamahPreference.wireValue,
                            language = language,
                            theme = theme,
                        ) { key ->
                            settingsStore.asrIqamahPreference = AsrIqamahPreference.fromWire(key)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Language section
                SettingsPlainSection(LocaleStrings.t("settings.section.language.title", language), theme) {
                    PickerRow(
                        label = LocaleStrings.t("settings.language.app", language),
                        options = AppLanguage.entries.map { it.wireValue to it.displayName },
                        selectedKey = settingsStore.appLanguage.wireValue,
                        language = language,
                        theme = theme,
                    ) { key ->
                        settingsStore.appLanguage = AppLanguage.fromWire(key)
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Theme section
                SettingsPlainSection(LocaleStrings.t("settings.section.theme.title", language), theme) {
                    PickerRow(
                        label = LocaleStrings.t("settings.theme.mode", language),
                        options = listOf(
                            ThemeMode.DYNAMIC.wireValue to LocaleStrings.t("settings.theme.mode.dynamic", language),
                            ThemeMode.FIXED.wireValue to LocaleStrings.t("settings.theme.mode.fixed", language),
                        ),
                        selectedKey = settingsStore.themeMode.wireValue,
                        language = language,
                        theme = theme,
                    ) { key ->
                        settingsStore.themeMode = ThemeMode.fromWire(key)
                    }
                    if (settingsStore.themeMode == ThemeMode.FIXED) {
                        SettingsDivider(theme)
                        PickerRow(
                            label = LocaleStrings.t("settings.theme.fixed_theme", language),
                            options = TimeTheme.selectablePrayerThemes.map {
                                it.wireValue to prayerThemeLabel(it, language)
                            },
                            selectedKey = settingsStore.fixedTheme.wireValue,
                            language = language,
                            theme = theme,
                        ) { key ->
                            settingsStore.fixedTheme = TimeTheme.fromWire(key)
                        }
                    }
                    SettingsDivider(theme)
                    SkyGradientSettingsSection(
                        language = language,
                        theme = theme,
                        settingsStore = settingsStore,
                        onGradientChanged = {
                            scope.launch { updateAllMasjidlyWidgets(context) }
                        },
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Qibla section
                SettingsPlainSection(LocaleStrings.t("settings.section.qibla.title", language), theme) {
                    SettingsToggleRow(LocaleStrings.t("settings.qibla.enabled.title", language), !settingsStore.hideQiblaCompass, theme) { enabled ->
                        settingsStore.hideQiblaCompass = !enabled
                        if (enabled && !hasLocationPermission) {
                            permissionLauncher.launch(
                                arrayOf(
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                    Manifest.permission.ACCESS_COARSE_LOCATION,
                                ),
                            )
                        }
                    }
                }

                if (shouldShowLocationRecovery) {
                    Spacer(modifier = Modifier.height(24.dp))
                    SettingsPlainSection(LocaleStrings.t("settings.section.location.title", language), theme) {
                        Text(
                            text = LocaleStrings.t("settings.location.recovery.message", language),
                            style = rememberAppTextStyle(15f),
                            color = theme.textColor.copy(alpha = 0.8f),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        LocationRecoveryButton(
                            label = if (hasLocationPermission) {
                                LocaleStrings.t("settings.location.open_settings", language)
                            } else {
                                LocaleStrings.t("settings.location.allow", language)
                            },
                            theme = theme,
                            onClick = {
                                val fineGranted = ContextCompat.checkSelfPermission(
                                    context,
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                ) == PackageManager.PERMISSION_GRANTED
                                val coarseGranted = ContextCompat.checkSelfPermission(
                                    context,
                                    Manifest.permission.ACCESS_COARSE_LOCATION,
                                ) == PackageManager.PERMISSION_GRANTED
                                if (!fineGranted && !coarseGranted) {
                                    permissionLauncher.launch(
                                        arrayOf(
                                            Manifest.permission.ACCESS_FINE_LOCATION,
                                            Manifest.permission.ACCESS_COARSE_LOCATION,
                                        ),
                                    )
                                } else {
                                    context.startActivity(
                                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                            data = Uri.fromParts("package", context.packageName, null)
                                        },
                                    )
                                }
                            },
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Notifications section
                SettingsPlainSection(LocaleStrings.t("settings.notifications.title", language), theme) {
                    NotificationSettingsSection(settingsStore, settingsViewModel, language, theme)
                }

                Spacer(modifier = Modifier.height(24.dp))

                SettingsSectionTitle(LocaleStrings.t("settings.section.contact.title", language), theme)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    InsetActionButton(LocaleStrings.t("settings.contact.feedback.title", language), theme) {
                        MasjidlySupportMail.open(context, MasjidlySupportMail.Category.FEEDBACK, selectedMosqueName)
                    }
                    InsetActionButton(LocaleStrings.t("settings.contact.prayer_times.title", language), theme) {
                        MasjidlySupportMail.open(context, MasjidlySupportMail.Category.PRAYER_TIMES, selectedMosqueName)
                    }
                    InsetActionButton(LocaleStrings.t("settings.contact.request_masjid.title", language), theme) {
                        MasjidlySupportMail.open(context, MasjidlySupportMail.Category.REQUEST_MASJID, selectedMosqueName)
                    }
                }

                if (BuildConfig.DEBUG) {
                    Spacer(modifier = Modifier.height(24.dp))
                    SettingsSectionTitle(LocaleStrings.t("settings.section.development.title", language), theme)
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        InsetActionButton(LocaleStrings.t("settings.development.test_tutorial", language), theme) {
                            onboardingViewModel.restartTutorialFromDeveloperTools()
                            onBack()
                        }
                        DevNotificationButton(
                            LocaleStrings.format(
                                "settings.development.test_notification_format",
                                language,
                                LocaleStrings.t("settings.development.notification_type.adhan", language),
                            ),
                            LocaleStrings.t("settings.development.instant", language),
                            theme,
                        ) {
                            settingsViewModel.fireTestNotification(context, SettingsViewModel.TestNotificationType.ADHAN)
                        }
                        DevNotificationButton(
                            LocaleStrings.format(
                                "settings.development.test_notification_format",
                                language,
                                LocaleStrings.t("settings.development.notification_type.iqamah", language),
                            ),
                            LocaleStrings.t("settings.development.instant", language),
                            theme,
                        ) {
                            settingsViewModel.fireTestNotification(context, SettingsViewModel.TestNotificationType.IQAMAH)
                        }
                        DevNotificationButton(
                            LocaleStrings.format(
                                "settings.development.test_notification_format",
                                language,
                                LocaleStrings.t("settings.development.notification_type.reminder", language),
                            ),
                            LocaleStrings.t("settings.development.instant", language),
                            theme,
                        ) {
                            settingsViewModel.fireTestNotification(context, SettingsViewModel.TestNotificationType.REMINDER)
                        }
                        DevNotificationButton(
                            LocaleStrings.format(
                                "settings.development.test_notification_format",
                                language,
                                LocaleStrings.t("settings.development.notification_type.all", language),
                            ),
                            LocaleStrings.t("settings.development.three_instant", language),
                            theme,
                        ) {
                            settingsViewModel.fireTestNotification(context, SettingsViewModel.TestNotificationType.ALL)
                        }
                        InsetActionButton(LocaleStrings.t("settings.development.test_whats_new", language), theme) {
                            onTestWhatsNew()
                        }
                        InsetActionButton(LocaleStrings.t("settings.development.test_update_prompt", language), theme) {
                            onTestUpdatePrompt()
                        }
                        InsetActionButton(LocaleStrings.t("settings.development.test_review_prompt", language), theme) {
                            AppReviewPromptCoordinator.resetForTesting(settingsStore)
                            onBack()
                        }
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))
            }
        }

        onboardingState.currentStep?.let { step ->
            SettingsOnboardingOverlay(
                step = step,
                theme = theme,
                language = settingsStore.appLanguage,
                onboarding = onboardingViewModel,
            )
        }
    }
}

private data class ExactAlarmCopy(val message: String, val button: String) {
    companion object {
        fun forLanguage(language: AppLanguage): ExactAlarmCopy = when (language) {
            AppLanguage.ARABIC -> ExactAlarmCopy("يحتاج أندرويد إذن المنبّهات الدقيقة لتصل تنبيهات الصلاة في وقتها.", "السماح بالمنبّهات الدقيقة")
            AppLanguage.URDU -> ExactAlarmCopy("نماز کی اطلاعات وقت پر بھیجنے کے لیے Android کو exact alarms کی اجازت چاہیے۔", "Exact alarms کی اجازت دیں")
            AppLanguage.INDONESIAN -> ExactAlarmCopy("Android memerlukan izin alarm tepat agar notifikasi salat tiba tepat waktu.", "Izinkan alarm tepat")
            AppLanguage.ENGLISH -> ExactAlarmCopy("Android needs exact alarm access for prayer notifications to arrive on time.", "Allow exact alarms")
        }
    }
}

@Composable
private fun NotificationSettingsSection(
    settingsStore: SettingsStore,
    settingsViewModel: SettingsViewModel,
    language: AppLanguage,
    theme: ResolvedTheme,
) {
    val context = LocalContext.current
    var notifications by remember(settingsStore.revision.collectAsState().value) {
        mutableStateOf(settingsStore.notifications)
    }
    var adhanExpanded by remember { mutableStateOf(false) }
    var iqamahExpanded by remember { mutableStateOf(false) }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { _ ->
        settingsViewModel.onNotificationsChanged()
    }

    fun requestNotificationPermissionIfNeeded() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    fun persistMaster(enabled: Boolean) {
        notifications = notifications.copy(masterEnabled = enabled)
        settingsStore.notifications = notifications
        if (enabled) requestNotificationPermissionIfNeeded()
        settingsViewModel.onNotificationsChanged()
    }

    fun persistWithMasterSync(updated: NotificationSettings) {
        updated.syncMasterFlag()
        notifications = updated
        settingsStore.notifications = updated
        settingsViewModel.onNotificationsChanged()
    }

    SettingsToggleRow(LocaleStrings.t("settings.notifications.master.title", language), notifications.masterEnabled, theme) { enabled ->
        persistMaster(enabled)
    }

    if (notifications.masterEnabled) {
        if (!PrayerNotificationPermissions.canScheduleExactAlarms(context)) {
            val copy = ExactAlarmCopy.forLanguage(language)
            SettingsDivider(theme)
            Text(
                text = copy.message,
                style = rememberAppTextStyle(15f),
                color = theme.textColor.copy(alpha = 0.8f),
            )
            Spacer(modifier = Modifier.height(8.dp))
            LocationRecoveryButton(copy.button, theme) {
                PrayerNotificationPermissions.openExactAlarmSettings(context)
            }
        }
        SettingsDivider(theme)
        NotificationGroupRow(
            title = LocaleStrings.t("onboarding.notifications.prayers_adhan", language),
            expanded = adhanExpanded,
            enabled = notifications.adhanEnabled,
            language = language,
            theme = theme,
            onExpand = { adhanExpanded = !adhanExpanded },
            onToggle = { enabled ->
                val n = notifications.copy(adhanEnabled = enabled)
                if (enabled) AdhanPrayerToggle.entries.forEach { n.setAdhanEnabled(it, true) }
                persistWithMasterSync(n)
            },
        ) {
            AdhanPrayerToggle.entries.forEachIndexed { index, prayer ->
                if (index > 0) SettingsDivider(theme)
                SettingsToggleRow(prayer.localizedLabel(language), notifications.adhanEnabled(prayer), theme) { on ->
                    val n = notifications.copy().also { it.setAdhanEnabled(prayer, on) }
                    persistWithMasterSync(n)
                }
            }
        }

        SettingsDivider(theme)
        NotificationGroupRow(
            title = LocaleStrings.t("onboarding.notifications.prayers_iqamah", language),
            expanded = iqamahExpanded,
            enabled = notifications.iqamahEnabled,
            language = language,
            theme = theme,
            onExpand = { iqamahExpanded = !iqamahExpanded },
            onToggle = { enabled ->
                val n = notifications.copy(iqamahEnabled = enabled)
                if (enabled) IqamahPrayerToggle.entries.forEach { n.setIqamahEnabled(it, true) }
                persistWithMasterSync(n)
            },
        ) {
            IqamahPrayerToggle.entries.forEachIndexed { index, prayer ->
                if (index > 0) SettingsDivider(theme)
                SettingsToggleRow(prayer.localizedLabel(language), notifications.iqamahEnabled(prayer), theme) { on ->
                    val n = notifications.copy().also { it.setIqamahEnabled(prayer, on) }
                    persistWithMasterSync(n)
                }
            }
        }

        SettingsDivider(theme)
        ReminderPickerRow(LocaleStrings.t("settings.reminder.before_adhan", language), notifications.preAdhanReminderMinutes, language, theme) { minutes ->
            persistWithMasterSync(notifications.copy(preAdhanReminderMinutes = minutes))
        }
        SettingsDivider(theme)
        ReminderPickerRow(LocaleStrings.t("settings.reminder.before_iqamah", language), notifications.preIqamahReminderMinutes, language, theme) { minutes ->
            persistWithMasterSync(notifications.copy(preIqamahReminderMinutes = minutes))
        }
    }
}

@Composable
private fun NotificationGroupRow(
    title: String,
    expanded: Boolean,
    enabled: Boolean,
    language: AppLanguage,
    theme: ResolvedTheme,
    onExpand: () -> Unit,
    onToggle: (Boolean) -> Unit,
    content: @Composable () -> Unit,
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp)
                .heightIn(min = 44.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .hapticClickable(onClick = onExpand),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Expand chevron matching iOS: right-pointing rotated when expanded
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = if (expanded) {
                        LocaleStrings.t("accessibility.collapse", language)
                    } else {
                        LocaleStrings.t("accessibility.expand", language)
                    },
                    tint = theme.textColor,
                    modifier = Modifier
                        .size(18.dp)
                        .rotate(if (expanded) 90f else 0f),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    title,
                    modifier = Modifier.weight(1f),
                    color = theme.textColor,
                    style = rememberAppTextStyle(17f),
                )
            }
            IosSettingsSwitch(checked = enabled, theme = theme, onCheckedChange = onToggle)
        }
        if (expanded) {
            Column(modifier = Modifier.padding(start = 26.dp)) {
                content()
            }
        }
    }
}

@Composable
private fun ReminderPickerRow(
    label: String,
    selected: Int?,
    language: AppLanguage,
    theme: ResolvedTheme,
    onSelect: (Int?) -> Unit,
) {
    val options = listOf(
        null to LocaleStrings.t("settings.reminder.none", language),
        5 to LocaleStrings.t("settings.reminder.5min", language),
        10 to LocaleStrings.t("settings.reminder.10min", language),
        15 to LocaleStrings.t("settings.reminder.15min", language),
        30 to LocaleStrings.t("settings.reminder.30min", language),
    )
    PickerRow(label, options.map { (k, v) -> (k?.toString() ?: "none") to v }, selected?.toString() ?: "none", language, theme) { key ->
        onSelect(if (key == "none") null else key.toIntOrNull())
    }
}

@Composable
private fun IosSettingsSwitch(
    checked: Boolean,
    theme: ResolvedTheme,
    onCheckedChange: (Boolean) -> Unit,
) {
    val thumbOffset by animateDpAsState(
        targetValue = if (checked) 20.dp else 0.dp,
        label = "settingsSwitchThumb",
    )
    Box(
        modifier = Modifier
            .width(51.dp)
            .height(31.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (checked) theme.textColor else theme.textColor.copy(alpha = 0.18f))
            .hapticClickable { onCheckedChange(!checked) }
            .padding(2.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Box(
            modifier = Modifier
                .offset(x = thumbOffset)
                .size(27.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.96f))
                .border(0.5.dp, Color.Black.copy(alpha = if (checked && theme.usesLightForeground) 0.22f else 0.08f), CircleShape),
        )
    }
}

@Composable
private fun SettingsToggleRow(label: String, checked: Boolean, theme: ResolvedTheme, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .heightIn(min = 44.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            modifier = Modifier.weight(1f),
            color = theme.textColor,
            style = rememberAppTextStyle(17f),
        )
        IosSettingsSwitch(checked = checked, theme = theme, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun PickerRow(
    label: String,
    options: List<Pair<String, String>>,
    selectedKey: String,
    language: AppLanguage,
    theme: ResolvedTheme,
    onSelect: (String) -> Unit,
) {
    var sheetOpen by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { it.first == selectedKey }?.second ?: "—"
    val pickerOptions = remember(options) {
        options.map { (key, value) -> SettingsPickerOption(key, value) }
    }

    SettingsMenuPickerRow(
        label = label,
        displayValue = selectedLabel,
        sheetTitle = label,
        theme = theme,
        onClick = { sheetOpen = true },
    )
    SettingsPickerBottomSheet(
        visible = sheetOpen,
        title = label,
        options = pickerOptions,
        selectedKey = selectedKey,
        theme = theme,
        language = language,
        onDismiss = { sheetOpen = false },
        onSelect = onSelect,
    )
}

@Composable
private fun MosquePickerRow(
    label: String,
    mosques: List<Mosque>,
    selectedId: String,
    language: AppLanguage,
    theme: ResolvedTheme,
    onSelect: (Mosque) -> Unit,
) {
    var sheetOpen by remember { mutableStateOf(false) }
    val displayName = mosques.firstOrNull { it.id == selectedId }?.name
        ?: mosques.firstOrNull()?.name
        ?: ""
    val pickerOptions = remember(mosques) {
        mosques.map { mosque -> SettingsPickerOption(mosque.id, mosque.name) }
    }

    SettingsMenuPickerRow(
        label = label,
        displayValue = displayName,
        sheetTitle = label,
        theme = theme,
        multilineValue = true,
        onClick = { sheetOpen = true },
    )
    SettingsPickerBottomSheet(
        visible = sheetOpen,
        title = label,
        options = pickerOptions,
        selectedKey = selectedId,
        theme = theme,
        language = language,
        onDismiss = { sheetOpen = false },
        onSelect = { id ->
            mosques.firstOrNull { it.id == id }?.let(onSelect)
        },
    )
}

@Composable
private fun ClosestMosqueRow(
    mosque: Mosque,
    language: AppLanguage,
    theme: ResolvedTheme,
    onSelect: (Mosque) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = LocaleStrings.format("settings.closest_mosque.format", language, mosque.name),
            style = rememberAppTextStyle(14f),
            color = theme.textColor.copy(alpha = 0.8f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(10.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(theme.textColor.copy(alpha = 0.14f))
                .border(1.dp, theme.textColor.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
                .padding(vertical = 12.dp)
                .hapticClickable { onSelect(mosque) },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = LocaleStrings.t("settings.closest_mosque.select", language),
                color = theme.textColor,
                style = rememberAppTextStyle(15f, FontWeight.SemiBold),
            )
        }
    }
}

@Composable
private fun SettingsPlainSection(
    title: String,
    theme: ResolvedTheme,
    content: @Composable ColumnScope.() -> Unit,
) {
    SettingsSectionTitle(title, theme)
    Column(content = content)
}

@Composable
private fun InsetActionButton(label: String, theme: ResolvedTheme, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(theme.textColor.copy(alpha = 0.14f))
            .border(1.dp, theme.textColor.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .hapticClickable(onClick = onClick),
    ) {
        Text(
            text = label,
            color = theme.textColor,
            style = rememberAppTextStyle(17f, FontWeight.Medium),
        )
    }
}

@Composable
private fun DevNotificationButton(
    title: String,
    subtitle: String,
    theme: ResolvedTheme,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(theme.textColor.copy(alpha = 0.14f))
            .border(1.dp, theme.textColor.copy(alpha = 0.22f), RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .hapticClickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                color = theme.textColor,
                style = rememberAppTextStyle(17f, FontWeight.Medium),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = subtitle,
                color = theme.textColor.copy(alpha = 0.55f),
                style = rememberAppTextStyle(13f),
                textAlign = TextAlign.End,
            )
        }
    }
}

@Composable
private fun LocationRecoveryButton(label: String, theme: ResolvedTheme, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(theme.textColor.copy(alpha = 0.25f))
            .padding(vertical = 14.dp)
            .hapticClickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            style = rememberAppTextStyle(16f, FontWeight.SemiBold),
        )
    }
}

private fun prayerThemeLabel(theme: TimeTheme, language: AppLanguage): String = when (theme) {
    TimeTheme.FAJR -> PrayerLocalization.displayName("Fajr", language)
    TimeTheme.SUNRISE -> PrayerLocalization.displayName("Sunrise", language)
    TimeTheme.DHUHR -> PrayerLocalization.displayName("Dhuhr", language)
    TimeTheme.ASR -> PrayerLocalization.displayName("Asr", language)
    TimeTheme.MAGHRIB -> PrayerLocalization.displayName("Maghrib", language)
    TimeTheme.ISHA -> PrayerLocalization.displayName("Isha", language)
    TimeTheme.TAHAJJUD -> PrayerLocalization.displayName("Tahajjud", language)
}

@Composable
private fun SkyGradientSettingsSection(
    language: AppLanguage,
    theme: ResolvedTheme,
    settingsStore: SettingsStore,
    onGradientChanged: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    CollapsibleSettingsSubsection(
        title = LocaleStrings.t("settings.theme.gradient.section_title", language),
        expanded = expanded,
        theme = theme,
        language = language,
        onToggle = { expanded = !expanded },
    ) {
        TimeTheme.configurableGradientThemes.forEachIndexed { index, prayerTheme ->
            if (index > 0) SettingsDivider(theme)
            val label = LocaleStrings.format(
                "settings.theme.gradient.prayer_format",
                language,
                prayerThemeLabel(prayerTheme, language),
            )
            PickerRow(
                label = label,
                options = SkyGradientSet.entries.map { set ->
                    set.wireValue to skyGradientSetLabel(set, language)
                },
                selectedKey = settingsStore.skyGradientSet(for = prayerTheme).wireValue,
                language = language,
                theme = theme,
            ) { key ->
                SkyGradientSet.fromWire(key)?.let { set ->
                    settingsStore.setSkyGradientSet(set, for = prayerTheme)
                    onGradientChanged()
                }
            }
        }
    }
}

@Composable
private fun CollapsibleSettingsSubsection(
    title: String,
    expanded: Boolean,
    theme: ResolvedTheme,
    language: AppLanguage,
    onToggle: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp)
                .heightIn(min = 44.dp)
                .hapticClickable(onClick = onToggle),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = if (expanded) {
                    LocaleStrings.t("accessibility.collapse", language)
                } else {
                    LocaleStrings.t("accessibility.expand", language)
                },
                tint = theme.textColor,
                modifier = Modifier
                    .size(18.dp)
                    .rotate(if (expanded) 90f else 0f),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                title,
                color = theme.textColor,
                style = rememberAppTextStyle(17f),
            )
        }
        if (expanded) {
            Column(modifier = Modifier.padding(start = 26.dp), content = content)
        }
    }
}

private fun skyGradientSetLabel(set: SkyGradientSet, language: AppLanguage): String = when (set) {
    SkyGradientSet.CLASSIC -> LocaleStrings.t("settings.theme.gradient.classic", language)
    SkyGradientSet.SET2 -> LocaleStrings.t("settings.theme.gradient.set2", language)
}

private fun showDevToast(context: android.content.Context, message: String) {
    android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()
}

@Composable
private fun SettingsSectionTitle(title: String, theme: ResolvedTheme) {
    Text(
        text = title.uppercase(),
        style = rememberAppTextStyle(13f, FontWeight.SemiBold),
        color = theme.textColor.copy(alpha = 0.52f),
        letterSpacing = 0.4.sp,
        modifier = Modifier.padding(bottom = 8.dp),
    )
}

@Composable
private fun SettingsDivider(theme: ResolvedTheme) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(0.5.dp)
            .background(theme.textColor.copy(alpha = 0.18f))
    )
}

private fun selectMosque(
    mosque: Mosque,
    settingsStore: SettingsStore,
    homeViewModel: HomeViewModel,
    settingsViewModel: SettingsViewModel,
) {
    settingsStore.selectedMosqueId = mosque.id
    settingsStore.selectedMosqueSlug = mosque.slug
    settingsStore.selectedCityGroupingKey = mosque.cityGroupingKey
    settingsStore.selectedCountryGroupingKey = MosqueSelection.countryGroupingKey(mosque)
    homeViewModel.applySelectionFromSettings()
    settingsViewModel.refreshAsrAdhanSupport()
}
