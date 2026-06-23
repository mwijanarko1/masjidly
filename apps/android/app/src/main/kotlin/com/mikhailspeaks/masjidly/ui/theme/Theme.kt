package com.mikhailspeaks.masjidly.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val MasjidlyDarkColors = darkColorScheme(
    primary = MasjidlyGreen,
    onPrimary = androidx.compose.ui.graphics.Color.White,
    background = MasjidlyBackground,
    onBackground = androidx.compose.ui.graphics.Color.White,
    surface = MasjidlyBackground,
    onSurface = androidx.compose.ui.graphics.Color.White,
)

private val MasjidlyLightColors = lightColorScheme(
    primary = MasjidlyGreen,
    onPrimary = androidx.compose.ui.graphics.Color.White,
    background = DhuhrTop,
    onBackground = androidx.compose.ui.graphics.Color(0xFF111111),
    surface = DhuhrTop,
    onSurface = androidx.compose.ui.graphics.Color(0xFF111111),
)

@Composable
fun MasjidlyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) MasjidlyDarkColors else MasjidlyLightColors
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = MasjidlyTypography,
        content = content,
    )
}
