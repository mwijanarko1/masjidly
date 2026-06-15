import SwiftUI
import WidgetKit

/// Applies the persisted in-app locale and layout direction.
struct MasjidlyRootView: View {
    let homeViewModel: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding

    @State private var showUpdateAlert = false
    @State private var pendingRelease: MasjidlyRelease?

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
                checkForUpdate()
            }
            .onChange(of: settings.appLanguage) { _, _ in
                PrayerNotificationContent.registerCategories(locale: settings.resolvedLocale)
                Task { await homeViewModel.resyncNotificationsIfNeeded() }
            }
            .onChange(of: settings.themeMode) { _, _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: settings.fixedTheme) { _, _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyShowUpdatePrompt)) { _ in
                presentTestUpdateAlert()
            }
            .alert(
                updateAlertTitle,
                isPresented: $showUpdateAlert,
                presenting: pendingRelease
            ) { release in
                Button(updateLaterLabel) {
                    HapticFeedback.buttonTap()
                    showUpdateAlert = false
                }
                Button(updateNowLabel) {
                    HapticFeedback.buttonTap()
                    AppUpdateChecker.openAppStore(release: release)
                    showUpdateAlert = false
                }
            } message: { _ in
                Text(updateMessage)
            }
    }

    // MARK: - Update Check

    private func checkForUpdate() {
        Task {
            let status = await AppUpdateChecker.checkForUpdate()
            switch status {
            case .updateAvailable(let release):
                pendingRelease = release
                showUpdateAlert = true
            case .upToDate, .checkFailed:
                break
            }
        }
    }

    private func presentTestUpdateAlert() {
        Task {
            pendingRelease = await AppUpdateChecker.fetchLatestRelease() ?? MasjidlyRelease.testRelease
            showUpdateAlert = true
        }
    }

    // MARK: - Localized Labels

    private var updateAlertTitle: String {
        switch settings.appLanguage {
        case .arabic: return "تحديث متوفر"
        case .urdu: return "اپ ڈیٹ دستیاب ہے"
        case .indonesian: return "Pembaruan Tersedia"
        default: return "Update Available"
        }
    }

    private var updateNowLabel: String {
        switch settings.appLanguage {
        case .arabic: return "فتح المتجر"
        case .urdu: return "اسٹور کھولیں"
        case .indonesian: return "Buka App Store"
        default: return "Open App Store"
        }
    }

    private var updateLaterLabel: String {
        switch settings.appLanguage {
        case .arabic: return "لاحقاً"
        case .urdu: return "بعد میں"
        case .indonesian: return "Nanti"
        default: return "Later"
        }
    }

    private var updateMessage: String {
        switch settings.appLanguage {
        case .arabic: return "نسخة أحدث من مسجدلي جاهزة للتثبيت."
        case .urdu: return "مسجدلی کا نیا ورژن انسٹال کرنے کے لیے تیار ہے۔"
        case .indonesian: return "Versi baru Masjidly siap dipasang."
        default: return "A newer version of Masjidly is ready."
        }
    }
}
