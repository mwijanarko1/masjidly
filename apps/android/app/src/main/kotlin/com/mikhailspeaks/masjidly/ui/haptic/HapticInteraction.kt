package com.mikhailspeaks.masjidly.ui.haptic

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics

/** Mirrors iOS `UIImpactFeedbackGenerator(style: .light)`. */
fun View.performMasjidlyButtonTapHaptic() {
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
    if (performHapticFeedback(HapticFeedbackConstants.CONFIRM)) return
  }
  if (performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)) return
  @Suppress("DEPRECATION")
  performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
}

/** Mirrors iOS `UIImpactFeedbackGenerator(style: .medium)` for long-press actions. */
fun View.performMasjidlyLongPressHaptic() {
  performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
}

@Composable
fun triggerButtonTapHaptic() {
  LocalView.current.performMasjidlyButtonTapHaptic()
}

@Composable
fun triggerLongPressHaptic() {
  LocalView.current.performMasjidlyLongPressHaptic()
}

/** @deprecated Use [triggerButtonTapHaptic]. */
@Composable
fun triggerSelectionHaptic() = triggerButtonTapHaptic()

@Composable
fun rememberHapticOnClick(onClick: () -> Unit): () -> Unit {
  val view = LocalView.current
  return remember(onClick, view) {
    {
      view.performMasjidlyButtonTapHaptic()
      onClick()
    }
  }
}

fun Modifier.plainClickable(
  enabled: Boolean = true,
  onClickLabel: String? = null,
  role: Role? = null,
  onClick: () -> Unit,
): Modifier = hapticClickable(
  enabled = enabled,
  onClickLabel = onClickLabel,
  role = role,
  hapticOnPress = false,
  onClick = onClick,
)

fun Modifier.hapticClickable(
  enabled: Boolean = true,
  onClickLabel: String? = null,
  role: Role? = null,
  hapticOnPress: Boolean = true,
  onClick: () -> Unit,
): Modifier = composed {
  val view = LocalView.current
  Modifier
    .semantics(mergeDescendants = true) {
      if (!enabled) disabled()
      this.role = role ?: Role.Button
      onClick(label = onClickLabel) {
        if (enabled) {
          view.performMasjidlyButtonTapHaptic()
          onClick()
        }
        true
      }
    }
    .then(
      if (enabled) {
        Modifier.pointerInput(onClick, hapticOnPress) {
          detectTapGestures(
            onPress = {
              if (hapticOnPress) {
                view.performMasjidlyButtonTapHaptic()
              }
              tryAwaitRelease()
            },
            onTap = { onClick() },
          )
        }
      } else {
        Modifier
      },
    )
}

@OptIn(ExperimentalFoundationApi::class)
fun Modifier.hapticCombinedClickable(
  enabled: Boolean = true,
  onClickLabel: String? = null,
  onLongClickLabel: String? = null,
  role: Role? = null,
  onLongClick: (() -> Unit)? = null,
  onClick: () -> Unit,
): Modifier = composed {
  val view = LocalView.current
  Modifier
    .semantics(mergeDescendants = true) {
      if (!enabled) disabled()
      this.role = role ?: Role.Button
      onClick(label = onClickLabel) {
        if (enabled) {
          view.performMasjidlyButtonTapHaptic()
          onClick()
        }
        true
      }
    }
    .then(
      if (enabled) {
        Modifier.pointerInput(onClick, onLongClick) {
          if (onLongClick != null) {
            detectTapGestures(
              onLongPress = {
                view.performMasjidlyLongPressHaptic()
                onLongClick()
              },
              onTap = {
                view.performMasjidlyButtonTapHaptic()
                onClick()
              },
            )
          } else {
            detectTapGestures(
              onPress = {
                view.performMasjidlyButtonTapHaptic()
                tryAwaitRelease()
              },
              onTap = { onClick() },
            )
          }
        }
      } else {
        Modifier
      },
    )
}

@Composable
fun HapticTextButton(
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  enabled: Boolean = true,
  content: @Composable RowScope.() -> Unit,
) {
  Row(
    modifier = modifier.hapticClickable(enabled = enabled, onClick = onClick),
    horizontalArrangement = Arrangement.Center,
    verticalAlignment = Alignment.CenterVertically,
    content = content,
  )
}
