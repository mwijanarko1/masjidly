package com.mikhailspeaks.masjidly.features.settings

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.mikhailspeaks.masjidly.data.SettingsStore
import java.time.Duration
import java.time.Instant

/** Soft "enjoying Masjidly?" prompt; positive opens the Android review page when available. */
object AppReviewPromptCoordinator {
    private val minimumUsage = Duration.ofDays(1)

    fun recordLaunchIfNeeded(settings: SettingsStore) {
        settings.ensureFirstAppOpenTrackedAtRecordedIfNeeded()
    }

    fun shouldShowEnjoymentPrompt(settings: SettingsStore, isOnboardingBlocking: Boolean): Boolean {
        if (isOnboardingBlocking || !settings.hasCompletedOnboarding) return false
        if (settings.hasCompletedEnjoymentReviewFlow) return false
        val started = settings.firstAppOpenTrackedAt ?: return false
        return Duration.between(started, Instant.now()) >= minimumUsage
    }

    fun completePositive(context: Context, settings: SettingsStore) {
        settings.hasCompletedEnjoymentReviewFlow = true
        openReviewPage(context)
    }

    fun completeNegative(settings: SettingsStore) {
        settings.hasCompletedEnjoymentReviewFlow = true
    }

    fun resetForTesting(settings: SettingsStore) {
        settings.resetEnjoymentReviewPromptForTesting()
    }

    private fun openReviewPage(context: Context) {
        val packageName = context.packageName
        val marketUri = Uri.parse("market://details?id=$packageName&showAllReviews=true")
        val webUri = Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
        val marketIntent = Intent(Intent.ACTION_VIEW, marketUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(marketIntent)
        } catch (_: ActivityNotFoundException) {
            context.startActivity(Intent(Intent.ACTION_VIEW, webUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
