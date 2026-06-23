package com.mikhailspeaks.masjidly.features.settings

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.mikhailspeaks.masjidly.BuildConfig
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.domain.LocaleStrings

/** Mirrors iOS `MasjidlySupportMail.swift`. */
object MasjidlySupportMail {
    const val RECIPIENT = "mikhailbuilds@gmail.com"

    enum class Category {
        FEEDBACK,
        PRAYER_TIMES,
        REQUEST_MASJID,
    }

    data class SupportContext(
        val mosqueName: String?,
        val appMarketingVersion: String,
        val appBuild: String,
        val systemVersion: String,
    )

    fun currentContext(mosqueName: String?): SupportContext =
        SupportContext(
            mosqueName = mosqueName,
            appMarketingVersion = BuildConfig.VERSION_NAME,
            appBuild = BuildConfig.VERSION_CODE.toString(),
            systemVersion = "Android ${Build.VERSION.RELEASE}",
        )

    fun mailtoUri(category: Category, mosqueName: String?): Uri? {
        val ctx = currentContext(mosqueName)
        val subject = subject(category)
        val body = buildString {
            append(bodyTemplate(category))
            val trimmedMosque = ctx.mosqueName?.trim().orEmpty()
            if (trimmedMosque.isNotEmpty()) {
                append("\n\nSelected mosque: ")
                append(trimmedMosque)
            }
            append("\n\n—\nMasjidly ")
            append(ctx.appMarketingVersion)
            append(" (build ")
            append(ctx.appBuild)
            append(")\n")
            append(ctx.systemVersion)
        }
        return Uri.parse(
            "mailto:$RECIPIENT?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}",
        )
    }

    fun open(context: android.content.Context, category: Category, mosqueName: String?) {
        val uri = mailtoUri(category, mosqueName) ?: return
        val intent = Intent(Intent.ACTION_SENDTO, uri)
        context.startActivity(Intent.createChooser(intent, subject(category)))
    }

    fun openMissingPrayerTimesEmail(
        context: android.content.Context,
        mosqueName: String?,
        monthDisplay: String,
        language: AppLanguage,
    ) {
        val resolvedMosque = mosqueName?.trim().orEmpty().ifEmpty {
            LocaleStrings.t("settings.email.mosque.not_selected", language)
        }
        val subject = LocaleStrings.format(
            "support.mail.missing_prayer_times.subject",
            language,
            resolvedMosque,
            monthDisplay,
        )
        val body = LocaleStrings.format(
            "support.mail.missing_prayer_times.body",
            language,
            resolvedMosque,
            monthDisplay,
        ) + "\n\n" + LocaleStrings.format(
            "support.mail.footer",
            language,
            BuildConfig.VERSION_NAME,
            BuildConfig.VERSION_CODE.toString(),
            "Android ${Build.VERSION.RELEASE}",
        )
        val uri = Uri.parse(
            "mailto:$RECIPIENT?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}",
        )
        val intent = Intent(Intent.ACTION_SENDTO, uri)
        context.startActivity(Intent.createChooser(intent, null))
    }

    private fun subject(category: Category): String = when (category) {
        Category.FEEDBACK -> "Masjidly — Ideas & feedback"
        Category.PRAYER_TIMES -> "Masjidly — Prayer times question"
        Category.REQUEST_MASJID -> "Masjidly — Request a masjid"
    }

    private fun bodyTemplate(category: Category): String = when (category) {
        Category.FEEDBACK ->
            "Hi Masjidly team,\n\nI'd like to share the following idea or feedback:\n\n\n\nThanks,"
        Category.PRAYER_TIMES ->
            "Hi Masjidly team,\n\nI'm writing about prayer times. Please see the details below.\n\n" +
                "Mosque:\nDate (or month):\nWhat looks wrong:\n\nThanks,"
        Category.REQUEST_MASJID ->
            "Hi Masjidly team,\n\nI'd like to request adding a masjid to Masjidly.\n\n" +
                "Masjid name:\nCity / country:\nWebsite or contact details:\nPrayer timetable source:\n\nThanks,"
    }
}
