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
                    title = "ودجات مُعاد تصميمها",
                    description = "ودجات الشاشة الرئيسية والقفل مع عدّاد مباشر وجداول الصلاة.",
                    icon = WhatsNewIcon.WIDGET,
                ),
                WhatsNewItem(
                    title = "تدرجات صلاة جديدة",
                    description = "أصلي أو عصري أو مخصص لكل صلاة في الإعدادات ← السمة.",
                    icon = WhatsNewIcon.PALETTE,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "ویجٹس کا نیا ڈیزائن",
                    description = "ہوم اور لاک اسکرین ویجٹس میں لائیو کاؤنٹ ڈاؤن اور مکمل اوقات۔",
                    icon = WhatsNewIcon.WIDGET,
                ),
                WhatsNewItem(
                    title = "نئے نماز کے گریڈینٹ",
                    description = "ہر نماز کے لیے اصل، جدید یا حسبِ مناسب۔ ترتیبات ← تھیم۔",
                    icon = WhatsNewIcon.PALETTE,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Widget didesain ulang",
                    description = "Widget layar utama dan kunci dengan hitung mundur langsung dan jadwal lengkap.",
                    icon = WhatsNewIcon.WIDGET,
                ),
                WhatsNewItem(
                    title = "Gradien salat baru",
                    description = "Asli, Modern, atau Kustom per salat di Pengaturan → Tema.",
                    icon = WhatsNewIcon.PALETTE,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "Redesigned widgets",
                    description = "Home and lock screen widgets with live countdowns and full prayer times.",
                    icon = WhatsNewIcon.WIDGET,
                ),
                WhatsNewItem(
                    title = "New prayer gradients",
                    description = "Original, Modern, or Custom colors per prayer in Settings → Theme.",
                    icon = WhatsNewIcon.PALETTE,
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
