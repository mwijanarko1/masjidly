import SwiftUI

/// Applies `\.locale` from `SettingsStore` so language changes take effect without relaunching.
struct MasjidlyRootView: View {
    let homeViewModel: HomeViewModel
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HomeView(model: homeViewModel)
            .environment(\.locale, settings.resolvedLocale)
            .environment(\.layoutDirection, settings.appLanguage.isResolvedRightToLeft ? .rightToLeft : .leftToRight)
    }
}
