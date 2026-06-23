package com.mikhailspeaks.masjidly.features.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationContent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class AdhanPlaybackState(
    val showsMiniPlayer: Boolean = false,
    val isPlayingForUI: Boolean = false,
    val displayedCurrentTimeSec: Double = 0.0,
    val displayedDurationSec: Double = 0.0,
) {
    val playbackFraction: Double
        get() {
            val duration = displayedDurationSec
            if (duration <= 0) return 0.0
            return (displayedCurrentTimeSec / duration).coerceIn(0.0, 1.0)
        }
}

/**
 * In-app adhan playback with Music-style chrome — mirrors iOS `AdhanSoundPreviewPlayer`.
 */
object AdhanSoundPreviewPlayer {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val _state = MutableStateFlow(AdhanPlaybackState())
    val state: StateFlow<AdhanPlaybackState> = _state.asStateFlow()

    private var appContext: Context? = null
    private var player: MediaPlayer? = null
    private var loadedResourceId: Int? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private val progressTick = object : Runnable {
        override fun run() {
            tickProgress()
            mainHandler.postDelayed(this, 250L)
        }
    }

    fun attach(context: Context) {
        if (appContext == null) {
            appContext = context.applicationContext
            audioManager = appContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        }
    }

    /** Play / pause / resume bundled adhan (default clip). */
    fun toggle(context: Context) {
        attach(context)
        toggle(context, PrayerNotificationContent.bundledAdhanRawResource())
    }

    /** Play / pause / resume for the given raw resource. Uses a new load if the clip differs. */
    fun toggle(context: Context, rawResourceId: Int?) {
        attach(context)
        if (rawResourceId == null) return
        val current = player
        if (current?.isPlaying == true) {
            if (loadedResourceId == rawResourceId) {
                pause()
            } else {
                playFresh(rawResourceId)
            }
            return
        }
        if (current != null && loadedResourceId == rawResourceId) {
            resume()
            return
        }
        playFresh(rawResourceId)
    }

    fun togglePlayPauseFromChrome() {
        if (player == null) return
        if (_state.value.isPlayingForUI) pause() else resume()
    }

    fun dismissMiniPlayer() {
        stop()
    }

    fun stop() {
        mainHandler.removeCallbacks(progressTick)
        player?.runCatching {
            stop()
            release()
        }
        player = null
        loadedResourceId = null
        abandonAudioFocus()
        _state.value = AdhanPlaybackState()
    }

    private fun pause() {
        player?.pause()
        syncDisplayedTimesFromPlayer()
        _state.update { it.copy(isPlayingForUI = false) }
        mainHandler.removeCallbacks(progressTick)
    }

    private fun resume() {
        if (!requestAudioFocus()) return
        player?.start()
        syncDisplayedTimesFromPlayer()
        _state.update { it.copy(isPlayingForUI = player?.isPlaying == true) }
        startProgressTimerIfNeeded()
    }

    private fun playFresh(rawResourceId: Int) {
        stop()
        val context = appContext ?: return
        if (!requestAudioFocus()) return

        loadedResourceId = rawResourceId
        runCatching {
            MediaPlayer.create(context, rawResourceId)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setOnCompletionListener { mainHandler.post { handlePlaybackFinished() } }
                start()
                player = this
                syncDisplayedTimesFromPlayer()
                _state.value = AdhanPlaybackState(
                    showsMiniPlayer = true,
                    isPlayingForUI = true,
                    displayedCurrentTimeSec = _state.value.displayedCurrentTimeSec,
                    displayedDurationSec = _state.value.displayedDurationSec,
                )
                startProgressTimerIfNeeded()
            }
        }.onFailure {
            stop()
        }
    }

    private fun handlePlaybackFinished() {
        stop()
    }

    private fun startProgressTimerIfNeeded() {
        mainHandler.removeCallbacks(progressTick)
        mainHandler.post(progressTick)
    }

    private fun tickProgress() {
        syncDisplayedTimesFromPlayer()
        if (player?.isPlaying != true) {
            mainHandler.removeCallbacks(progressTick)
        }
    }

    private fun syncDisplayedTimesFromPlayer() {
        val current = player ?: return
        val durationMs = current.duration
        val durationSec = if (durationMs > 0) durationMs / 1000.0 else 0.0
        val currentSec = (current.currentPosition / 1000.0).coerceAtLeast(0.0)
        _state.update {
            it.copy(
                displayedCurrentTimeSec = currentSec,
                displayedDurationSec = if (durationSec > 0) durationSec else it.displayedDurationSec,
            )
        }
    }

    private fun requestAudioFocus(): Boolean {
        val manager = audioManager ?: return true
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAcceptsDelayedFocusGain(true)
            .setOnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                    -> mainHandler.post { pause() }
                }
            }
            .build()
        audioFocusRequest = request
        return manager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus() {
        val manager = audioManager ?: return
        val request = audioFocusRequest
        if (request != null) {
            manager.abandonAudioFocusRequest(request)
        }
        audioFocusRequest = null
    }
}
