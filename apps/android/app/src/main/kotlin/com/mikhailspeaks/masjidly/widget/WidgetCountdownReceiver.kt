package com.mikhailspeaks.masjidly.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.runBlocking

class WidgetCountdownReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            WidgetCountdownRefresher.ACTION_COUNTDOWN_TICK,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> Unit
            else -> return
        }

        val pendingResult = goAsync()
        Thread {
            try {
                runBlocking {
                    updateCountdownMasjidlyWidgets(context.applicationContext)
                    WidgetCountdownRefresher.rescheduleFromSnapshot(context.applicationContext)
                }
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
