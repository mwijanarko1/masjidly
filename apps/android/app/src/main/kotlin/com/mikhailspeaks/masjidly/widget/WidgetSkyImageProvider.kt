package com.mikhailspeaks.masjidly.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.mikhailspeaks.masjidly.R
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.home.SkyGradientSet
import com.mikhailspeaks.masjidly.ui.home.TimeTheme

internal fun skyBackgroundImageProvider(appearance: ResolvedTheme): androidx.glance.ImageProvider {
    if (appearance.gradientSet == SkyGradientSet.CUSTOM) {
        return androidx.glance.ImageProvider(createVerticalGradientBitmap(appearance.top, appearance.bottom))
    }
    return androidx.glance.ImageProvider(skyDrawableFor(appearance))
}

private fun createVerticalGradientBitmap(top: Color, bottom: Color, width: Int = 512, height: Int = 512): Bitmap {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = LinearGradient(
            0f,
            0f,
            0f,
            height.toFloat(),
            top.toArgb(),
            bottom.toArgb(),
            Shader.TileMode.CLAMP,
        )
    }
    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    return bitmap
}

private fun skyDrawableFor(appearance: ResolvedTheme): Int {
    val modern = appearance.gradientSet == SkyGradientSet.SET2
    return when (appearance.timeTheme) {
        TimeTheme.FAJR -> if (modern) R.drawable.widget_sky_fajr_modern else R.drawable.widget_sky_fajr
        TimeTheme.SUNRISE -> if (modern) R.drawable.widget_sky_sunrise_modern else R.drawable.widget_sky_sunrise
        TimeTheme.DHUHR -> if (modern) R.drawable.widget_sky_dhuhr_modern else R.drawable.widget_sky_dhuhr
        TimeTheme.ASR -> if (modern) R.drawable.widget_sky_asr_modern else R.drawable.widget_sky_asr
        TimeTheme.MAGHRIB -> if (modern) R.drawable.widget_sky_maghrib_modern else R.drawable.widget_sky_maghrib
        TimeTheme.ISHA, TimeTheme.TAHAJJUD -> if (modern) R.drawable.widget_sky_isha_modern else R.drawable.widget_sky_isha
    }
}
