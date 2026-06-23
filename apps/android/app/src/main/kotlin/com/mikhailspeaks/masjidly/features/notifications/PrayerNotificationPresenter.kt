package com.mikhailspeaks.masjidly.features.notifications

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.mikhailspeaks.masjidly.MainActivity
import com.mikhailspeaks.masjidly.R
import java.util.UUID

object PrayerNotificationPresenter {
    fun show(
        context: Context,
        id: String,
        title: String,
        body: String,
        categoryId: String,
        extras: Map<String, String>,
    ) {
        if (!PrayerNotificationPermissions.hasPostNotificationsPermission(context)) return
        PrayerNotificationContent.ensureChannel(context)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            extras.forEach { (key, value) -> putExtra(key, value) }
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val extrasBundle = Bundle().apply {
            extras.forEach { (key, value) -> putString(key, value) }
        }

        val notification = NotificationCompat.Builder(context, PrayerNotificationContent.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .setCategory(categoryId)
            .setExtras(extrasBundle)
            .build()

        NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
    }

    fun showInstantTest(
        context: Context,
        title: String,
        body: String,
        categoryId: String,
        extras: Map<String, String>,
    ) {
        show(
            context = context,
            id = "masjidly.debug.${UUID.randomUUID()}",
            title = title,
            body = body,
            categoryId = categoryId,
            extras = extras,
        )
    }
}
