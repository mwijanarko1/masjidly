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
    COMPARE,
    GRID,
    HOURGLASS,
    LOCK,
    MAP,
    PALETTE,
    REORDER,
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
                    title = "مقارنة المساجد",
                    description = "قارن أوقات الأذان والإقامة بين المساجد، أو ابحث عن المسجد المناسب حسب الوقت.",
                    icon = WhatsNewIcon.COMPARE,
                ),
                WhatsNewItem(
                    title = "ودجات الشاشة الرئيسية",
                    description = "ثلاثة تصاميم جديدة تعرض الصلاة القادمة مع العد التنازلي.",
                    icon = WhatsNewIcon.GRID,
                ),
                WhatsNewItem(
                    title = "ودجات شاشة القفل",
                    description = "ستة تصاميم جديدة لمتابعة الصلاة القادمة من شاشة القفل.",
                    icon = WhatsNewIcon.LOCK,
                ),
                WhatsNewItem(
                    title = "ترتيب علامات المساجد",
                    description = "اضغط مطولاً على علامة المسجد واسحبها لإعادة ترتيبها.",
                    icon = WhatsNewIcon.REORDER,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "مساجد کا موازنہ",
                    description = "مساجد کے درمیان اذان اور اقامت کے اوقات کا موازنہ کریں، یا وقت کے مطابق مسجد تلاش کریں۔",
                    icon = WhatsNewIcon.COMPARE,
                ),
                WhatsNewItem(
                    title = "ہوم اسکرین ویجٹس",
                    description = "اگلی نماز اور کاؤنٹ ڈاؤن دکھانے والے تین نئے ڈیزائن۔",
                    icon = WhatsNewIcon.GRID,
                ),
                WhatsNewItem(
                    title = "لاک اسکرین ویجٹس",
                    description = "لاک اسکرین سے اگلی نماز دیکھنے کے لیے چھ نئے ڈیزائن۔",
                    icon = WhatsNewIcon.LOCK,
                ),
                WhatsNewItem(
                    title = "مساجد کی ترتیب",
                    description = "مسجد کے ٹیب کو دبائے رکھیں اور گھسیٹ کر ترتیب بدلیں۔",
                    icon = WhatsNewIcon.REORDER,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Bandingkan masjid",
                    description = "Bandingkan waktu adzan dan iqamah antar masjid, atau cari masjid berdasarkan waktu.",
                    icon = WhatsNewIcon.COMPARE,
                ),
                WhatsNewItem(
                    title = "Widget layar utama",
                    description = "Tiga desain baru yang menampilkan salat berikutnya dengan hitung mundur.",
                    icon = WhatsNewIcon.GRID,
                ),
                WhatsNewItem(
                    title = "Widget layar kunci",
                    description = "Enam desain baru untuk melihat salat berikutnya dari layar kunci.",
                    icon = WhatsNewIcon.LOCK,
                ),
                WhatsNewItem(
                    title = "Urutkan tab masjid",
                    description = "Tekan lama tab masjid lalu seret untuk mengubah urutannya.",
                    icon = WhatsNewIcon.REORDER,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "Compare Masjids",
                    description = "Compare adhan and iqamah times across masjids, or find a masjid by time.",
                    icon = WhatsNewIcon.COMPARE,
                ),
                WhatsNewItem(
                    title = "Home Screen Widgets",
                    description = "Three new designs showing your next prayer with a live countdown.",
                    icon = WhatsNewIcon.GRID,
                ),
                WhatsNewItem(
                    title = "Lock Screen Widgets",
                    description = "Six new designs to check your next prayer from the Lock Screen.",
                    icon = WhatsNewIcon.LOCK,
                ),
                WhatsNewItem(
                    title = "Reorder Masjid Tabs",
                    description = "Press and hold a masjid tab, then drag it to reorder.",
                    icon = WhatsNewIcon.REORDER,
                ),
            )
        }
    }
}

/** Mirrors iOS `WhatsNewModalCopy`. */
data class WhatsNewModalCopy(
    val title: String,
    val versionPrefix: String,
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
                    continueLabel = "متابعة",
                )
                "ur" -> WhatsNewModalCopy(
                    title = "مسجدلی اپ ڈیٹ!",
                    versionPrefix = "ورژن",
                    continueLabel = "جاری رکھیں",
                )
                "id" -> WhatsNewModalCopy(
                    title = "Pembaruan Masjidly!",
                    versionPrefix = "Versi",
                    continueLabel = "Lanjut",
                )
                else -> WhatsNewModalCopy(
                    title = "Masjidly Update!",
                    versionPrefix = "Version",
                    continueLabel = "Continue",
                )
            }
        }
    }
}
