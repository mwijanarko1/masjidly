package com.mikhailspeaks.masjidly.features.updates

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontWeight
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.ui.haptic.rememberHapticOnClick
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

/** System alert for in-app updates — mirrors iOS `HomeView` / `MasjidlyRootView` alert copy. */
@Composable
fun UpdatePromptDialog(
    language: AppLanguage,
    onLater: () -> Unit,
    onUpdate: () -> Unit,
) {
    val copy = UpdatePromptCopy.forLanguage(language)
    val hapticLater = rememberHapticOnClick(onLater)
    val hapticUpdate = rememberHapticOnClick(onUpdate)

    AlertDialog(
        onDismissRequest = hapticLater,
        title = {
            Text(
                text = copy.title,
                style = rememberAppTextStyle(18f, FontWeight.SemiBold),
            )
        },
        text = {
            Text(
                text = copy.message,
                style = rememberAppTextStyle(15f),
            )
        },
        confirmButton = {
            TextButton(onClick = hapticUpdate) {
                Text(
                    text = copy.updateNowLabel,
                    style = rememberAppTextStyle(15f, FontWeight.SemiBold),
                )
            }
        },
        dismissButton = {
            TextButton(onClick = hapticLater) {
                Text(
                    text = copy.laterLabel,
                    style = rememberAppTextStyle(15f),
                )
            }
        },
    )
}

private data class UpdatePromptCopy(
    val title: String,
    val message: String,
    val updateNowLabel: String,
    val laterLabel: String,
) {
    companion object {
        fun forLanguage(language: AppLanguage): UpdatePromptCopy = when (language) {
            AppLanguage.ARABIC -> UpdatePromptCopy(
                title = "تحديث متوفر",
                message = "نسخة أحدث من مسجدلي جاهزة للتثبيت.",
                updateNowLabel = "تحميل",
                laterLabel = "لاحقاً",
            )
            AppLanguage.URDU -> UpdatePromptCopy(
                title = "اپ ڈیٹ دستیاب ہے",
                message = "مسجدلی کا نیا ورژن انسٹال کرنے کے لیے تیار ہے۔",
                updateNowLabel = "ڈاؤن لوڈ کریں",
                laterLabel = "بعد میں",
            )
            AppLanguage.INDONESIAN -> UpdatePromptCopy(
                title = "Pembaruan Tersedia",
                message = "Versi baru Masjidly siap dipasang.",
                updateNowLabel = "Unduh",
                laterLabel = "Nanti",
            )
            AppLanguage.ENGLISH -> UpdatePromptCopy(
                title = "Update Available",
                message = "A newer version of Masjidly is ready.",
                updateNowLabel = "Download",
                laterLabel = "Later",
            )
        }
    }
}
