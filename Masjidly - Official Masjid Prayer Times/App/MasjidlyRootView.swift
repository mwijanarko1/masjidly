import SwiftUI

/// Applies English locale and LTR layout.
struct MasjidlyRootView: View {
    let homeViewModel: HomeViewModel
    @Environment(OnboardingFlowController.self) private var onboarding

    var body: some View {
        HomeView(model: homeViewModel)
            .environment(\.locale, Locale(identifier: "en"))
            .environment(\.layoutDirection, .leftToRight)
            .environment(onboarding)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdhanMiniPlayerBar(
                    timeTheme: HomeDesign.TimeTheme.homeHeroTheme(
                        displayedPrayerTimes: homeViewModel.displayedPrayerTimes,
                        selectedPrayerIndex: homeViewModel.selectedPrayerIndex
                    )
                )
            }
    }
}
