package com.mikhailspeaks.masjidly.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.ClosestMosquePromptDecision
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
 * Language → location → mosque → notifications, then done.
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
        val notificationDraft: OnboardingNotificationDraft = OnboardingNotificationDraft.defaultEnabled,
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
                // Do not seed from settings: load may have resolved the default MWHS slug.
                selectedMosqueId = "",
                notificationDraft = OnboardingNotificationDraft.defaultEnabled,
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
        // Do not restart mid-flow: settings changes (e.g. language) bump revision and
        // would otherwise trap the user on step 1 forever.
        if (_uiState.value.currentStep != null) {
            return
        }
        // Fresh onboarding always starts without a mosque so location can prefill closest.
        _uiState.update {
            it.copy(
                selectedMosqueId = "",
                notificationDraft = OnboardingNotificationDraft.defaultEnabled,
                isSelectingMosque = false,
                isCompletingNotifications = false,
                currentStep = OnboardingStep.ChooseLanguage,
            )
        }
    }

    fun selectLanguage(language: AppLanguage) {
        if (_uiState.value.currentStep != OnboardingStep.ChooseLanguage) return
        settings.appLanguage = language
        _uiState.update { it.copy(selectedLanguage = language, currentStep = OnboardingStep.RequestLocation) }
    }

    fun continueAfterLocationStep() {
        if (_uiState.value.currentStep != OnboardingStep.RequestLocation) return
        _uiState.update { it.copy(currentStep = OnboardingStep.ChooseMosque) }
    }

    /** Prefills the closest mosque once when the user has not chosen one yet. */
    fun applyClosestMosqueIfNeeded(mosques: List<Mosque>, latitude: Double, longitude: Double) {
        val state = _uiState.value
        if (state.currentStep != OnboardingStep.RequestLocation &&
            state.currentStep != OnboardingStep.ChooseMosque
        ) {
            return
        }
        if (state.selectedMosqueId.isNotEmpty()) return
        val closest = ClosestMosquePromptDecision.closestMosque(
            mosques = mosques,
            userLat = latitude,
            userLng = longitude,
        ) ?: return
        _uiState.update { it.copy(selectedMosqueId = closest.id) }
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
                        isSelectingMosque = false,
                        currentStep = OnboardingStep.Notifications,
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

    fun completeNotificationSetup() {
        if (_uiState.value.currentStep != OnboardingStep.Notifications ||
            _uiState.value.isCompletingNotifications
        ) {
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
                        draft.preIqamahReminderMinutes != null ||
                        draft.adhanFajr || draft.adhanDhuhrJummah || draft.adhanAsr ||
                        draft.adhanMaghrib || draft.adhanIsha ||
                        draft.iqamahFajr || draft.iqamahDhuhrJummah || draft.iqamahAsr ||
                        draft.iqamahMaghrib || draft.iqamahIsha,
                )
                settings.notifications = next
                if (next.masterEnabled) {
                    notificationScheduler.requestAuthorizationIfNeeded()
                    val mosque = homeViewModel.uiState.value.selectedMosque
                    if (mosque != null) {
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
                _uiState.update {
                    it.copy(currentStep = null, isCompletingNotifications = false)
                }
            } catch (e: Exception) {
                homeViewModel.setLastError(e.localizedMessage)
                _uiState.update { it.copy(isCompletingNotifications = false) }
            }
        }
    }

    fun restartTutorialFromDeveloperTools() {
        settings.hasCompletedOnboarding = false
        _uiState.update {
            it.copy(
                selectedMosqueId = "",
                selectedLanguage = settings.appLanguage,
                notificationDraft = OnboardingNotificationDraft.defaultEnabled,
                isSelectingMosque = false,
                isCompletingNotifications = false,
                currentStep = OnboardingStep.ChooseLanguage,
            )
        }
    }
}
