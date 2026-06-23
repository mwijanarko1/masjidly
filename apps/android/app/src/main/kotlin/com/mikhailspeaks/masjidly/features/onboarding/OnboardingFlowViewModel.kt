package com.mikhailspeaks.masjidly.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import com.mikhailspeaks.masjidly.features.updates.WhatsNew
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Android counterpart to iOS `OnboardingFlowController.swift`.
 */
class OnboardingFlowViewModel(
    private val settings: SettingsStore,
    private val homeViewModel: HomeViewModel,
    private val notificationScheduler: PrayerNotificationScheduler,
) : ViewModel() {

    data class UiState(
        val currentStep: OnboardingStep? = null,
        val selectedLanguage: AppLanguage = AppLanguage.ENGLISH,
        val selectedMosqueId: String = "",
        val notificationDraft: OnboardingNotificationDraft = OnboardingNotificationDraft(),
        val isSelectingMosque: Boolean = false,
        val isCompletingNotifications: Boolean = false,
    ) {
        val isActive: Boolean get() = currentStep != null
    }

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        _uiState.update {
            it.copy(
                selectedLanguage = settings.appLanguage,
                selectedMosqueId = settings.selectedMosqueId.orEmpty(),
                notificationDraft = OnboardingNotificationDraft.fromSettings(settings.notifications),
            )
        }
    }

    fun startIfNeeded(mosques: List<Mosque>) {
        if (settings.hasCompletedOnboarding) {
            if (_uiState.value.currentStep != null) {
                _uiState.update { it.copy(currentStep = null) }
            }
            return
        }
        if (mosques.isEmpty()) {
            return
        }
        // Do not restart mid-flow — settings changes (e.g. language) bump revision and
        // would otherwise trap the user on step 1 forever.
        if (_uiState.value.currentStep != null) {
            return
        }
        val selectedId = _uiState.value.selectedMosqueId.ifEmpty {
            settings.selectedMosqueId
                ?: mosques.firstOrNull()?.id
                .orEmpty()
        }
        _uiState.update {
            it.copy(
                selectedMosqueId = selectedId,
                notificationDraft = OnboardingNotificationDraft.fromSettings(settings.notifications),
                isSelectingMosque = false,
                currentStep = OnboardingStep.ChooseLanguage,
            )
        }
    }

    fun selectLanguage(language: AppLanguage) {
        if (_uiState.value.currentStep != OnboardingStep.ChooseLanguage) return
        settings.appLanguage = language
        _uiState.update { it.copy(selectedLanguage = language, currentStep = OnboardingStep.ChooseMosque) }
    }

    fun selectMosque(mosque: Mosque) {
        if (_uiState.value.currentStep != OnboardingStep.ChooseMosque || _uiState.value.isSelectingMosque) return
        viewModelScope.launch {
            _uiState.update { it.copy(isSelectingMosque = true, selectedMosqueId = mosque.id) }
            try {
                settings.selectedMosqueId = mosque.id
                settings.selectedMosqueSlug = mosque.slug
                settings.selectedCityGroupingKey = mosque.cityGroupingKey
                settings.selectedCountryGroupingKey = MosqueSelection.countryGroupingKey(mosque)
                homeViewModel.switchToMosque(mosque)
                _uiState.update {
                    it.copy(
                        currentStep = OnboardingStep.PrayerShortcut(index = 0),
                        isSelectingMosque = false,
                    )
                }
            } catch (e: Exception) {
                homeViewModel.setLastError(e.localizedMessage)
                _uiState.update { it.copy(isSelectingMosque = false) }
            }
        }
    }

    fun updateSelectedMosqueId(id: String) {
        _uiState.update { it.copy(selectedMosqueId = id) }
    }

    fun updateNotificationDraft(transform: (OnboardingNotificationDraft) -> OnboardingNotificationDraft) {
        _uiState.update { it.copy(notificationDraft = transform(it.notificationDraft)) }
    }

    fun handlePrayerShortcutTap(index: Int) {
        val step = _uiState.value.currentStep as? OnboardingStep.PrayerShortcut ?: return
        if (step.index != 0 || index !in 0..5) return
        _uiState.update { it.copy(currentStep = OnboardingStep.QiblaCountdown) }
    }

    fun skipToTutorialEnd() {
        _uiState.update { it.copy(currentStep = OnboardingStep.Notifications) }
    }

    fun completeQiblaCountdownStep() {
        if (_uiState.value.currentStep != OnboardingStep.QiblaCountdown) return
        _uiState.update { it.copy(currentStep = OnboardingStep.Qibla) }
    }

    fun completeQiblaOnboardingAllowingLocationRequest() {
        if (_uiState.value.currentStep != OnboardingStep.Qibla) return
        settings.hideQiblaCompass = false
        _uiState.update { it.copy(currentStep = OnboardingStep.OpenTimetable) }
    }

    fun completeQiblaOnboardingDeferringLocation() {
        if (_uiState.value.currentStep != OnboardingStep.Qibla) return
        settings.hideQiblaCompass = true
        _uiState.update { it.copy(currentStep = OnboardingStep.OpenTimetable) }
    }

    fun handleTimetableOpened() {
        if (_uiState.value.currentStep != OnboardingStep.OpenTimetable) return
        _uiState.update { it.copy(currentStep = OnboardingStep.ExploreTimetable) }
    }

    fun acknowledgeTimetableExplore() {
        if (_uiState.value.currentStep != OnboardingStep.ExploreTimetable) return
        _uiState.update { it.copy(currentStep = OnboardingStep.CloseTimetable) }
    }

    fun handleTimetableClosed() {
        if (_uiState.value.currentStep != OnboardingStep.CloseTimetable) return
        _uiState.update { it.copy(currentStep = OnboardingStep.OpenSettings) }
    }

    fun handleSettingsOpened() {
        if (_uiState.value.currentStep != OnboardingStep.OpenSettings) return
        _uiState.update { it.copy(currentStep = OnboardingStep.ExploreSettings) }
    }

    fun acknowledgeSettingsExplore() {
        if (_uiState.value.currentStep != OnboardingStep.ExploreSettings) return
        _uiState.update { it.copy(currentStep = OnboardingStep.CloseSettings) }
    }

    fun handleSettingsClosed() {
        if (_uiState.value.currentStep != OnboardingStep.CloseSettings) return
        _uiState.update { it.copy(currentStep = OnboardingStep.Notifications) }
    }

    fun completeNotificationSetup() {
        if (_uiState.value.currentStep != OnboardingStep.Notifications || _uiState.value.isCompletingNotifications) {
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isCompletingNotifications = true) }
            try {
                val draft = _uiState.value.notificationDraft
                val next = settings.notifications.copy(
                    adhanEnabled = draft.adhanEnabled,
                    iqamahEnabled = draft.iqamahEnabled,
                    preAdhanReminderMinutes = draft.preAdhanReminderMinutes,
                    preIqamahReminderMinutes = draft.preIqamahReminderMinutes,
                    adhanFajr = draft.adhanFajr,
                    adhanDhuhrJummah = draft.adhanDhuhrJummah,
                    adhanAsr = draft.adhanAsr,
                    adhanMaghrib = draft.adhanMaghrib,
                    adhanIsha = draft.adhanIsha,
                    iqamahFajr = draft.iqamahFajr,
                    iqamahDhuhrJummah = draft.iqamahDhuhrJummah,
                    iqamahAsr = draft.iqamahAsr,
                    iqamahMaghrib = draft.iqamahMaghrib,
                    iqamahIsha = draft.iqamahIsha,
                    masterEnabled = draft.adhanEnabled ||
                        draft.iqamahEnabled ||
                        draft.preAdhanReminderMinutes != null ||
                        draft.preIqamahReminderMinutes != null,
                )
                settings.notifications = next
                if (next.masterEnabled) {
                    notificationScheduler.requestAuthorizationIfNeeded()
                    homeViewModel.uiState.value.selectedMosque?.let { mosque ->
                        notificationScheduler.rescheduleUpcomingPrayerNotifications(
                            mosque = mosque,
                            days = 7,
                            settings = next,
                            language = settings.appLanguage,
                            asrIqamahPreference = settings.asrIqamahPreference,
                        )
                    }
                } else {
                    notificationScheduler.cancelAllPrayerNotifications()
                }
                settings.lastSeenBuildVersion = WhatsNew.fullVersionString
                settings.hasCompletedOnboarding = true
                _uiState.update { it.copy(currentStep = null, isCompletingNotifications = false) }
            } catch (_: Exception) {
                _uiState.update { it.copy(isCompletingNotifications = false) }
            }
        }
    }

    fun restartTutorialFromDeveloperTools() {
        settings.hasCompletedOnboarding = false
        settings.hideQiblaCompass = false
        val mosques = homeViewModel.uiState.value.mosques
        val selectedId = _uiState.value.selectedMosqueId.ifEmpty {
            settings.selectedMosqueId
                ?: mosques.firstOrNull()?.id
                .orEmpty()
        }
        _uiState.update {
            it.copy(
                selectedMosqueId = selectedId,
                selectedLanguage = settings.appLanguage,
                notificationDraft = OnboardingNotificationDraft.fromSettings(settings.notifications),
                isSelectingMosque = false,
                currentStep = OnboardingStep.ChooseLanguage,
            )
        }
    }
}
