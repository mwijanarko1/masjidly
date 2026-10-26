package com.mikhailspeaks.masjidly.features.prayerfocus

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.mikhailspeaks.masjidly.ui.haptic.hapticClickable
import com.mikhailspeaks.masjidly.ui.home.QiblaPrayerIcon
import com.mikhailspeaks.masjidly.ui.home.ResolvedTheme
import com.mikhailspeaks.masjidly.ui.theme.LocalMasjidlyLocale
import com.mikhailspeaks.masjidly.ui.theme.rememberAppTextStyle
import java.util.Locale

/** Copy and colors for the blocking screen, resolved by the service. */
data class PrayerFocusOverlayContent(
    val title: String,
    val message: String,
    val endsAt: String,
    val okLabel: String,
    val prayedLabel: String,
    val theme: ResolvedTheme,
    val locale: Locale,
    val isRightToLeft: Boolean,
)

/**
 * Full-screen application overlay drawn over a selected app. It does not stop the app underneath,
 * and it is not focusable, so Back, Home, Recents, and the notification shade keep working.
 */
internal class PrayerFocusOverlay(
    private val context: Context,
    private val onCloseApp: () -> Unit,
    private val onPrayed: () -> Unit,
) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private var view: ComposeView? = null
    private var owner: OverlayLifecycleOwner? = null
    private var shownContent: PrayerFocusOverlayContent? = null

    val isShowing: Boolean get() = view != null

    fun show(content: PrayerFocusOverlayContent) {
        if (view != null && shownContent == content) return
        if (view != null) {
            shownContent = content
            view?.setContent { OverlayScreen(content, onCloseApp, onPrayed) }
            return
        }
        val lifecycleOwner = OverlayLifecycleOwner().also { it.start() }
        val composeView = ComposeView(context).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent { OverlayScreen(content, onCloseApp, onPrayed) }
        }
        try {
            windowManager.addView(composeView, layoutParams())
            view = composeView
            owner = lifecycleOwner
            shownContent = content
        } catch (_: RuntimeException) {
            // Overlay grant revoked or window rejected: never leave half-attached state behind.
            lifecycleOwner.stop()
        }
    }

    fun hide() {
        val current = view ?: return
        runCatching { windowManager.removeViewImmediate(current) }
        owner?.stop()
        view = null
        owner = null
        shownContent = null
    }

    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.OPAQUE,
    ).apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        title = "Masjidly Prayer Focus"
    }
}

@Composable
private fun OverlayScreen(
    content: PrayerFocusOverlayContent,
    onCloseApp: () -> Unit,
    onPrayed: () -> Unit,
) {
    val theme = content.theme
    CompositionLocalProvider(
        LocalLayoutDirection provides if (content.isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr,
        LocalMasjidlyLocale provides content.locale,
    ) {
        // Mirrors the iOS shield: prayer icon and copy in the middle, OK and "I've prayed" at the bottom.
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(theme.sky.baseColors))
                .safeDrawingPadding()
                .padding(horizontal = 28.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                // Scrolls at large font sizes instead of pushing the buttons off screen.
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    QiblaPrayerIcon(
                        theme = theme,
                        rotationDegrees = null,
                        size = 140.dp,
                        modifier = Modifier.clearAndSetSemantics { },
                    )
                    Spacer(modifier = Modifier.height(28.dp))
                    Text(
                        text = content.title,
                        style = rememberAppTextStyle(30f, FontWeight.Bold),
                        color = theme.textColor,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.semantics { heading() },
                    )
                    Spacer(modifier = Modifier.height(14.dp))
                    Text(
                        text = content.message,
                        style = rememberAppTextStyle(18f),
                        color = theme.textColor.copy(alpha = 0.88f),
                        textAlign = TextAlign.Center,
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Text(
                        text = content.endsAt,
                        style = rememberAppTextStyle(16f, FontWeight.SemiBold, tabularDigits = true),
                        color = theme.textColor.copy(alpha = 0.75f),
                        textAlign = TextAlign.Center,
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .clip(RoundedCornerShape(percent = 50))
                    .background(Brush.verticalGradient(listOf(Color(0xFF47A6FF), Color(0xFF2E8DFF))))
                    .hapticClickable(role = Role.Button, onClick = onCloseApp)
                    .padding(horizontal = 16.dp, vertical = 15.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = content.okLabel,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    color = Color.White,
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .hapticClickable(role = Role.Button, onClick = onPrayed)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = content.prayedLabel,
                    style = rememberAppTextStyle(17f, FontWeight.SemiBold),
                    color = theme.textColor,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/** Minimal owners so Compose can run inside a WindowManager view outside an Activity. */
private class OverlayLifecycleOwner : SavedStateRegistryOwner {
    private val registry = LifecycleRegistry(this)
    private val savedState = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = registry
    override val savedStateRegistry: SavedStateRegistry get() = savedState.savedStateRegistry

    fun start() {
        savedState.performRestore(null)
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun stop() {
        registry.currentState = Lifecycle.State.DESTROYED
    }
}
