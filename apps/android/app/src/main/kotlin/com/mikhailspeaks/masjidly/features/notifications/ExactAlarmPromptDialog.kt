package com.mikhailspeaks.masjidly.features.notifications

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontWeight
import com.mikhailspeaks.masjidly.domain.AppLanguage
import com.mikhailspeaks.masjidly.ui.haptic.rememberHapticOnClick
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle

@Composable
fun ExactAlarmPromptDialog(
    language: AppLanguage,
    onLater: () -> Unit,
    onAllow: () -> Unit,
) {
    val copy = ExactAlarmPromptCopy.forLanguage(language)
    val hapticLater = rememberHapticOnClick(onLater)
    val hapticAllow = rememberHapticOnClick(onAllow)

    AlertDialog(
        onDismissRequest = hapticLater,
        title = { Text(copy.title, style = rememberAppTextStyle(18f, FontWeight.SemiBold)) },
        text = { Text(copy.message, style = rememberAppTextStyle(15f)) },
        confirmButton = {
            TextButton(onClick = hapticAllow) {
                Text(copy.allowLabel, style = rememberAppTextStyle(15f, FontWeight.SemiBold))
            }
        },
        dismissButton = {
            TextButton(onClick = hapticLater) {
                Text(copy.laterLabel, style = rememberAppTextStyle(15f))
            }
        },
    )
}

private data class ExactAlarmPromptCopy(
    val title: String,
    val message: String,
    val allowLabel: String,
    val laterLabel: String,
) {
    companion object {
        fun forLanguage(language: AppLanguage): ExactAlarmPromptCopy = when (language) {
            AppLanguage.ARABIC -> ExactAlarmPromptCopy(
                title = "السماح بتنبيهات دقيقة",
                message = "لكي تصل تنبيهات الأذان والإقامة في وقتها، يحتاج مسجدلي إذن المنبّهات الدقيقة من أندرويد.",
                allowLabel = "السماح",
                laterLabel = "لاحقاً",
            )
            AppLanguage.URDU -> ExactAlarmPromptCopy(
                title = "درست وقت کی اجازت",
                message = "اذان اور اقامت کی اطلاعات وقت پر پہنچانے کے لیے مسجدلی کو Android exact alarms کی اجازت چاہیے۔",
                allowLabel = "اجازت دیں",
                laterLabel = "بعد میں",
            )
            AppLanguage.INDONESIAN -> ExactAlarmPromptCopy(
                title = "Izinkan alarm tepat",
                message = "Agar notifikasi adzan dan iqamah tiba tepat waktu, Masjidly memerlukan izin alarm tepat dari Android.",
                allowLabel = "Izinkan",
                laterLabel = "Nanti",
            )
            AppLanguage.ENGLISH -> ExactAlarmPromptCopy(
                title = "Allow exact prayer alarms",
                message = "Masjidly needs Android exact alarm access so adhan and iqamah notifications arrive at the correct prayer time.",
                allowLabel = "Allow",
                laterLabel = "Later",
            )
        }
    }
}
