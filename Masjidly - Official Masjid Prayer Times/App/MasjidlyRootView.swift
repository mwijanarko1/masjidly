import SwiftUI

/// Applies the persisted in-app locale and layout direction.
struct MasjidlyRootView: View {
    let homeViewModel: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding

    var body: some View {
        HomeView(model: homeViewModel)
            .environment(\.locale, settings.resolvedLocale)
            .environment(\.layoutDirection, settings.appLanguage.layoutDirection)
            .environment(onboarding)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdhanMiniPlayerBar(
                    timeTheme: settings.resolvedTheme(
                        dynamicTheme: HomeDesign.TimeTheme.homeHeroTheme(
                            displayedPrayerTimes: homeViewModel.displayedPrayerTimes,
                            selectedPrayerIndex: homeViewModel.selectedPrayerIndex
                        )
                    )
                )
                .environment(\.locale, settings.resolvedLocale)
                .environment(\.layoutDirection, settings.appLanguage.layoutDirection)
            }
            .onAppear {
                PrayerNotificationContent.registerCategories(locale: settings.resolvedLocale)
            }
            .onChange(of: settings.appLanguage) { _, _ in
                PrayerNotificationContent.registerCategories(locale: settings.resolvedLocale)
                Task { await homeViewModel.resyncNotificationsIfNeeded() }
            }
    }
}
