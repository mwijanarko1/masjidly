import SwiftUI

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
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyShowUpdatePrompt)) { _ in
                presentTestUpdateAlert()
            }
            .alert(
                updateAlertTitle,
                isPresented: $showUpdateAlert,
                presenting: pendingRelease
            ) { release in
                Button(updateLaterLabel) {
                    showUpdateAlert = false
                }
                Button(updateNowLabel) {
                    AppUpdateChecker.openAppStore()
                    showUpdateAlert = false
                }
            } message: { release in
                Text(updateMessage(for: release))
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

    private func updateMessage(for release: MasjidlyRelease) -> String {
        let version = release.ios.version
        let isTestRelease = version == "9.9.9"

        let notes: String
        switch settings.appLanguage {
        case .arabic: notes = release.notes.ar
        case .urdu: notes = release.notes.ur
        case .indonesian: notes = release.notes.id
        default: notes = release.notes.en
        }

        switch settings.appLanguage {
        case .arabic:
            let versionLine = "الإصدار \(version) متوفر الآن"
            if isTestRelease {
                return versionLine + "\n\n" + notes
            }
            return versionLine + "\n\n" + notes + "\n\nاضغط على \"فتح المتجر\" للتحديث."

        case .urdu:
            let versionLine = "ورژن \(version) اب دستیاب ہے"
            if isTestRelease {
                return versionLine + "\n\n" + notes
            }
            return versionLine + "\n\n" + notes + "\n\nاپ ڈیٹ کرنے کے لیے \"اسٹور کھولیں\" پر تھپتھپائیں۔"

        case .indonesian:
            let versionLine = "Versi \(version) kini tersedia"
            if isTestRelease {
                return versionLine + "\n\n" + notes
            }
            return versionLine + "\n\n" + notes + "\n\nKetuk \"Buka App Store\" untuk memperbarui."

        default:
            let versionLine = "Version \(version) is now available"
            if isTestRelease {
                return versionLine + "\n\n" + notes
            }
            return versionLine + "\n\n" + notes + "\n\nTap \"Open App Store\" to update."
        }
    }
}
