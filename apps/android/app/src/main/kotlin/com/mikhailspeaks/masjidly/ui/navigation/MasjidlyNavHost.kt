package com.mikhailspeaks.masjidly.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.features.home.HomeScreen
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import com.mikhailspeaks.masjidly.features.onboarding.OnboardingFlowViewModel
import com.mikhailspeaks.masjidly.features.settings.SettingsScreen
import com.mikhailspeaks.masjidly.features.settings.SettingsViewModel
import com.mikhailspeaks.masjidly.features.timetable.TimetableScreen

@Composable
fun MasjidlyNavHost(
    homeViewModel: HomeViewModel,
    settingsStore: SettingsStore,
    viewModelFactory: ViewModelProvider.Factory,
    notificationScheduler: PrayerNotificationScheduler,
    onTestWhatsNew: () -> Unit = {},
    onTestUpdatePrompt: () -> Unit = {},
) {
    val navController = rememberNavController()
    val settingsRevision by settingsStore.revision.collectAsState()
    val onboardingViewModel = remember(homeViewModel, settingsStore, notificationScheduler) {
        OnboardingFlowViewModel(settingsStore, homeViewModel, notificationScheduler)
    }

    @Suppress("UNUSED_VARIABLE")
    val _tick = settingsRevision

    NavHost(
        navController = navController,
        startDestination = MasjidlyDestination.Home,
    ) {
        composable(MasjidlyDestination.Home) {
            HomeScreen(
                viewModel = homeViewModel,
                settingsStore = settingsStore,
                onboardingViewModel = onboardingViewModel,
                onOpenTimetable = { navController.navigate(MasjidlyDestination.Timetable) },
                onOpenSettings = { navController.navigate(MasjidlyDestination.Settings) },
            )
        }
        composable(MasjidlyDestination.Timetable) {
            TimetableScreen(
                homeViewModel = homeViewModel,
                settingsStore = settingsStore,
                onboardingViewModel = onboardingViewModel,
                onBack = {
                    onboardingViewModel.handleTimetableClosed()
                    navController.popBackStack()
                },
            )
        }
        composable(MasjidlyDestination.Settings) {
            val settingsViewModel: SettingsViewModel = viewModel(factory = viewModelFactory)
            val homeState by homeViewModel.uiState.collectAsState()
            LaunchedEffect(homeState.mosques) {
                settingsViewModel.updateMosques(homeState.mosques)
            }
            SettingsScreen(
                homeViewModel = homeViewModel,
                settingsViewModel = settingsViewModel,
                settingsStore = settingsStore,
                onboardingViewModel = onboardingViewModel,
                onBack = {
                    onboardingViewModel.handleSettingsClosed()
                    navController.popBackStack()
                },
                onTestWhatsNew = onTestWhatsNew,
                onTestUpdatePrompt = onTestUpdatePrompt,
            )
        }
    }
}
