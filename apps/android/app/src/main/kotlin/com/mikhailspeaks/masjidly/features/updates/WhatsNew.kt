package com.mikhailspeaks.masjidly.features.updates

import com.mikhailspeaks.masjidly.BuildConfig
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.util.Locale

/** Mirrors iOS `WhatsNewItem`. */
data class WhatsNewItem(
    val title: String,
    val description: String,
    val icon: WhatsNewIcon,
)

enum class WhatsNewIcon {
    BUG_FIX,
    GRID,
    MAP,
    PALETTE,
    WIDGET,
}

/** Mirrors iOS `WhatsNew.swift`. */
object WhatsNew {
    val currentVersion: String
        get() = BuildConfig.VERSION_NAME.substringBefore("-")

    val currentBuild: String
        get() = BuildConfig.VERSION_CODE.toString()

    val fullVersionString: String
        get() = "$currentVersion ($currentBuild)"

    fun localizedUpdates(language: AppLanguage): List<WhatsNewItem> =
        localizedUpdates(language.resolvedLocale())

    fun localizedUpdates(locale: Locale): List<WhatsNewItem> {
        val code = locale.language.lowercase()
        return when (code) {
            "ar" -> listOf(
                WhatsNewItem(
                    title = "إصلاح الأخطاء",
                    description = "تم إصلاح أخطاء متعلقة بالتوقيت الصيفي.",
                    icon = WhatsNewIcon.BUG_FIX,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "بگ فکسز",
                    description = "ڈے لائٹ سیونگ ٹائم سے متعلق خرابیاں ٹھیک کر دی گئیں۔",
                    icon = WhatsNewIcon.BUG_FIX,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Perbaikan bug",
                    description = "Memperbaiki bug terkait Daylight Saving Time.",
                    icon = WhatsNewIcon.BUG_FIX,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "Bug Fixes",
                    description = "Fixed bugs relating to Daylight Saving Time.",
                    icon = WhatsNewIcon.BUG_FIX,
                ),
            )
        }
    }
}

/** Mirrors iOS `WhatsNewModalCopy`. */
data class WhatsNewModalCopy(
    val title: String,
    val versionPrefix: String,
    val swipeHint: String,
    val continueLabel: String,
) {
    fun versionLabel(version: String): String = "$versionPrefix $version"

    companion object {
        fun forLanguage(language: AppLanguage): WhatsNewModalCopy =
            forLocale(language.resolvedLocale())

        fun forLocale(locale: Locale): WhatsNewModalCopy {
            val code = locale.language.lowercase()
            return when (code) {
                "ar" -> WhatsNewModalCopy(
                    title = "تحديث مسجدلي!",
                    versionPrefix = "الإصدار",
                    swipeHint = "مرر للمزيد",
                    continueLabel = "متابعة",
                )
                "ur" -> WhatsNewModalCopy(
                    title = "مسجدلی اپ ڈیٹ!",
                    versionPrefix = "ورژن",
                    swipeHint = "مزید کے لیے اسکرول کریں",
                    continueLabel = "جاری رکھیں",
                )
                "id" -> WhatsNewModalCopy(
                    title = "Pembaruan Masjidly!",
                    versionPrefix = "Versi",
                    swipeHint = "Gulir untuk lainnya",
                    continueLabel = "Lanjut",
                )
                else -> WhatsNewModalCopy(
                    title = "Masjidly Update!",
                    versionPrefix = "Version",
                    swipeHint = "Scroll for more",
                    continueLabel = "Continue",
                )
            }
        }
    }
}
