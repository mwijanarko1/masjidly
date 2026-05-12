import Foundation
import Observation
import StoreKit
import UIKit

/// Drives the soft “enjoying Masjidly?” prompt after minimum usage, then requests an App Store review for positive responses.
@Observable
@MainActor
final class AppReviewPromptCoordinator {
    private let settings: SettingsStore

    /// When `true`, `HomeView` presents the enjoyment confirmation dialog.
    var showEnjoymentPrompt = false

    /// At least this many seconds after first tracked launch before the automatic prompt is offered.
    private static let minimumUsageInterval: TimeInterval = 86400

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func recordLaunchIfNeeded() {
        settings.ensureFirstAppOpenTrackedAtRecordedIfNeeded()
    }

    /// Call when home is ready and onboarding is not blocking the experience.
    func considerPresentingEnjoymentPromptIfEligible(isOnboardingBlocking: Bool) {
        guard !isOnboardingBlocking else { return }
        guard settings.hasCompletedOnboarding else { return }
        guard !settings.hasCompletedEnjoymentReviewFlow else { return }
        guard !showEnjoymentPrompt else { return }
        guard let started = settings.firstAppOpenTrackedAt else { return }
        guard Date().timeIntervalSince(started) >= Self.minimumUsageInterval else { return }
        showEnjoymentPrompt = true
    }

    func userConfirmedEnjoymentPositive() {
        showEnjoymentPrompt = false
        settings.hasCompletedEnjoymentReviewFlow = true
        requestStoreReviewIfPossible()
    }

    func userConfirmedEnjoymentNegative() {
        showEnjoymentPrompt = false
        settings.hasCompletedEnjoymentReviewFlow = true
    }

    #if DEBUG
    /// Clears persisted review state and simulates enough usage time, then shows the soft prompt (for QA).
    func resetAndPresentEnjoymentPromptForTesting() {
        settings.resetEnjoymentReviewPromptForTesting()
        showEnjoymentPrompt = true
    }
    #endif

    private func requestStoreReviewIfPossible() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ??
            UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
