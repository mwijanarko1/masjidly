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
                    title = "شعارات جديدة",
                    description = "أربع مظاهر جديدة لمسجدلي: فجر، سماء، ظهيرة، ووردي.",
                    icon = WhatsNewIcon.PALETTE,
                ),
                WhatsNewItem(
                    title = "اختيار أيقونة التطبيق",
                    description = "اختر شعارك المفضل في أي وقت من الإعدادات.",
                    icon = WhatsNewIcon.GRID,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "نئے لوگو",
                    description = "مسجدلی کے چار نئے انداز: فجر، آسمان، سہ پہر، اور گلابی۔",
                    icon = WhatsNewIcon.PALETTE,
                ),
                WhatsNewItem(
                    title = "ایپ آئیکن منتخب کریں",
                    description = "سیٹنگز سے کسی بھی وقت اپنا پسندیدہ لوگو چنیں۔",
                    icon = WhatsNewIcon.GRID,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Logo baru",
                    description = "Empat tampilan baru untuk Masjidly: Fajar, Langit, Sore, dan Mawar.",
                    icon = WhatsNewIcon.PALETTE,
                ),
                WhatsNewItem(
                    title = "Pilih ikon aplikasi",
                    description = "Pilih logo favorit Anda kapan saja dari Pengaturan.",
                    icon = WhatsNewIcon.GRID,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "New logos",
                    description = "Four fresh looks for Masjidly: Dawn, Sky, Afternoon, and Rose.",
                    icon = WhatsNewIcon.PALETTE,
                ),
                WhatsNewItem(
                    title = "App icon picker",
                    description = "Choose your favourite logo anytime in Settings.",
                    icon = WhatsNewIcon.GRID,
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
