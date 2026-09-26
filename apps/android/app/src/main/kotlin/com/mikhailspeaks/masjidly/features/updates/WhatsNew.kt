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
                    title = "تبويبات المساجد",
                    description = "اعرض أوقات أكثر من مسجد عبر التبويبات. افتحها، انتقل بينها، أو أغلقها. يبقى المسجد المحدد في الإعدادات للإشعارات والودجت.",
                    icon = WhatsNewIcon.WIDGET,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "مسجد کے ٹیبز",
                    description = "ٹیبز سے ایک سے زیادہ مساجد کے اوقات دیکھیں۔ کھولیں، سوئچ کریں، یا بند کریں۔ اطلاعات اور ویجٹ کے لیے ڈیفالٹ مسجد سیٹنگز میں ہی رہے گی۔",
                    icon = WhatsNewIcon.WIDGET,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Tab masjid",
                    description = "Lihat jadwal lebih dari satu masjid lewat tab. Buka, beralih, atau tutup tab. Masjid untuk notifikasi dan widget tetap dipilih di Pengaturan.",
                    icon = WhatsNewIcon.WIDGET,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "Mosque tabs",
                    description = "Mosque tabs let you see times for more than one mosque. Open, switch, or close them anytime. The active mosque controls notifications and the widget.",
                    icon = WhatsNewIcon.WIDGET,
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
