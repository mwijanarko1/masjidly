package com.mikhailspeaks.masjidly

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.material3.Surface
import androidx.compose.ui.Alignment
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.updates.AppUpdateStatus
import com.mikhailspeaks.masjidly.features.updates.MasjidlyRelease
import com.mikhailspeaks.masjidly.features.updates.UpdateChecker
import com.mikhailspeaks.masjidly.features.updates.UpdatePromptDialog
import com.mikhailspeaks.masjidly.features.updates.WhatsNew
import com.mikhailspeaks.masjidly.features.updates.WhatsNewOverlay
import com.mikhailspeaks.masjidly.features.audio.AdhanMiniPlayerBar
import com.mikhailspeaks.masjidly.features.notifications.ExactAlarmPromptDialog
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationContent
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationPermissions
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import com.mikhailspeaks.masjidly.ui.home.TimeTheme
import com.mikhailspeaks.masjidly.ui.navigation.MasjidlyNavHost
import com.mikhailspeaks.masjidly.ui.theme.LocalMasjidlyLocale
import com.mikhailspeaks.masjidly.ui.theme.MasjidlyTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun MasjidlyApp(
    homeViewModel: HomeViewModel,
    settingsStore: SettingsStore,
    viewModelFactory: ViewModelProvider.Factory,
    notificationScheduler: PrayerNotificationScheduler,
) {
    val settingsRevision by settingsStore.revision.collectAsState()
    val homeState by homeViewModel.uiState.collectAsState()
    val rtl = settingsStore.appLanguage.isRightToLeft
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var showingWhatsNew by remember { mutableStateOf(false) }
    var showUpdateAlert by remember { mutableStateOf(false) }
    var pendingRelease by remember { mutableStateOf<MasjidlyRelease?>(null) }
    var hasCheckedForUpdate by remember { mutableStateOf(false) }
    var showExactAlarmPrompt by remember { mutableStateOf(false) }

    @Suppress("UNUSED_VARIABLE")
    val _tick = settingsRevision

    val dynamicTheme = TimeTheme.homeHeroTheme(homeState.displayedPrayerTimes, homeState.selectedPrayerIndex)
    val theme = settingsStore.resolvedTheme(dynamicTheme)

    fun dismissWhatsNew() {
        settingsStore.lastSeenBuildVersion = WhatsNew.fullVersionString
        showingWhatsNew = false
        if (pendingRelease != null) {
            showUpdateAlert = true
        }
    }

    fun presentUpdateAlertIfReady() {
        if (pendingRelease == null) return
        if (!settingsStore.hasCompletedOnboarding) return
        if (showingWhatsNew) return
        showUpdateAlert = true
    }

    fun checkWhatsNew() {
        if (!settingsStore.hasCompletedOnboarding) return
        if (settingsStore.lastSeenBuildVersion == WhatsNew.fullVersionString) return
        showingWhatsNew = true
    }

    suspend fun checkForUpdate() {
        when (val status = UpdateChecker.checkForUpdate()) {
            is AppUpdateStatus.UpdateAvailable -> {
                pendingRelease = status.release
                presentUpdateAlertIfReady()
            }
            is AppUpdateStatus.UpToDate, is AppUpdateStatus.CheckFailed -> Unit
        }
    }

    suspend fun presentTestUpdateAlert() {
        pendingRelease = UpdateChecker.fetchLatestRelease() ?: MasjidlyRelease.testRelease
        showUpdateAlert = true
    }

    fun maybeShowExactAlarmPrompt() {
        val missing = settingsStore.hasCompletedOnboarding &&
            settingsStore.notifications.masterEnabled &&
            !PrayerNotificationPermissions.canScheduleExactAlarms(context)
        if (missing && !settingsStore.hasDismissedExactAlarmPrompt) showExactAlarmPrompt = true
        if (!missing) showExactAlarmPrompt = false
    }

    LaunchedEffect(settingsStore.hasCompletedOnboarding, settingsRevision) {
        maybeShowExactAlarmPrompt()
    }

    LaunchedEffect(settingsStore.hasCompletedOnboarding, homeState.loadState, settingsRevision) {
        if (!settingsStore.hasCompletedOnboarding) return@LaunchedEffect
        if (homeState.loadState == HomeViewModel.LoadState.IDLE) return@LaunchedEffect
        checkWhatsNew()
    }

    LaunchedEffect(settingsStore.hasCompletedOnboarding) {
        if (!settingsStore.hasCompletedOnboarding || hasCheckedForUpdate) return@LaunchedEffect
        hasCheckedForUpdate = true
        delay(2_000)
        checkForUpdate()
    }

    LaunchedEffect(settingsStore.appLanguage) {
        PrayerNotificationContent.ensureChannel(context)
        homeViewModel.resyncNotificationsIfNeeded()
    }

    LaunchedEffect(settingsStore.hasCompletedOnboarding, homeState.loadState) {
        if (!settingsStore.hasCompletedOnboarding) return@LaunchedEffect
        if (homeState.loadState == HomeViewModel.LoadState.IDLE) return@LaunchedEffect
        homeViewModel.resyncNotificationsIfNeeded()
    }

    androidx.compose.runtime.CompositionLocalProvider(
        LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr,
        LocalMasjidlyLocale provides settingsStore.resolvedLocale(),
    ) {
        val lifecycleOwner = LocalLifecycleOwner.current
        DisposableEffect(lifecycleOwner) {
            val observer = LifecycleEventObserver { _, event ->
                if (event == Lifecycle.Event.ON_RESUME) {
                    homeViewModel.refreshFromNetworkIfStale()
                    maybeShowExactAlarmPrompt()
                    scope.launch { homeViewModel.resyncNotificationsIfNeeded() }
                }
            }
            lifecycleOwner.lifecycle.addObserver(observer)
            onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
        }

        MasjidlyTheme {
            Surface(modifier = Modifier.fillMaxSize()) {
                Box(modifier = Modifier.fillMaxSize()) {
                    MasjidlyNavHost(
                        homeViewModel = homeViewModel,
                        settingsStore = settingsStore,
                        viewModelFactory = viewModelFactory,
                        notificationScheduler = notificationScheduler,
                        onTestWhatsNew = { showingWhatsNew = true },
                        onTestUpdatePrompt = {
                            scope.launch { presentTestUpdateAlert() }
                        },
                    )

                    if (showingWhatsNew) {
                        WhatsNewOverlay(
                            theme = theme,
                            language = settingsStore.appLanguage,
                            onDismiss = ::dismissWhatsNew,
                        )
                    }

                    Column(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .navigationBarsPadding(),
                    ) {
                        AdhanMiniPlayerBar(
                            appearance = theme,
                            language = settingsStore.appLanguage,
                        )
                    }
                }

                if (showExactAlarmPrompt) {
                    ExactAlarmPromptDialog(
                        language = settingsStore.appLanguage,
                        onLater = {
                            settingsStore.hasDismissedExactAlarmPrompt = true
                            showExactAlarmPrompt = false
                        },
                        onAllow = {
                            settingsStore.hasDismissedExactAlarmPrompt = true
                            showExactAlarmPrompt = false
                            PrayerNotificationPermissions.openExactAlarmSettings(context)
                        },
                    )
                }

                if (showUpdateAlert && pendingRelease != null) {
                    UpdatePromptDialog(
                        language = settingsStore.appLanguage,
                        onLater = { showUpdateAlert = false },
                        onUpdate = {
                            pendingRelease?.let { UpdateChecker.openUpdateUrl(context, it) }
                            showUpdateAlert = false
                        },
                    )
                }
            }
        }
    }
}
