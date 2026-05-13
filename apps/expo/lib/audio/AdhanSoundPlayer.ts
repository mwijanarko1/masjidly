type AdhanIndex = 1 | 2;
type AudioPlayer = import("expo-audio").AudioPlayer;

// ── Module-level state (subscribed by components) ──

type Listener = () => void;
const listeners = new Set<Listener>();

let _currentPlayer: AudioPlayer | null = null;
let _currentIndex: AdhanIndex | null = null;
let _isPlaying = false;
let _currentTime = 0;
let _duration = 0;
let _showsMiniPlayer = false;
let _interval: ReturnType<typeof setInterval> | null = null;
let _audioConfigured = false;

function notify() {
  listeners.forEach((fn) => fn());
}

function subscribe(fn: Listener): () => void {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

function startPolling() {
  stopPolling();
  _interval = setInterval(() => {
    if (_currentPlayer) {
      _currentTime = _currentPlayer.currentTime;
      _duration = _currentPlayer.duration;
      _isPlaying = _currentPlayer.playing;
      notify();
      if (!_currentPlayer.playing && _currentTime >= _duration - 0.5) {
        // Playback finished
        cleanupPlayer();
        notify();
      }
    }
  }, 250);
}

function stopPolling() {
  if (_interval !== null) {
    clearInterval(_interval);
    _interval = null;
  }
}

function cleanupPlayer() {
  stopPolling();
  _currentPlayer = null;
  _currentIndex = null;
  _isPlaying = false;
  _currentTime = 0;
  _duration = 0;
  _showsMiniPlayer = false;
}

// ── Public API ──

export const AdhanPlayer = {
  subscribe,

  get isPlaying() {
    return _isPlaying;
  },
  get currentTime() {
    return _currentTime;
  },
  get duration() {
    return _duration;
  },
  get showsMiniPlayer() {
    return _showsMiniPlayer;
  },
  get currentIndex() {
    return _currentIndex;
  },
  get playbackFraction(): number {
    return _duration > 0 ? Math.min(1, Math.max(0, _currentTime / _duration)) : 0;
  },
};

async function ensureAudioMode(): Promise<void> {
  if (_audioConfigured) return;
  try {
    const EA = await import("expo-audio");
    await EA.setAudioModeAsync({
      playsInSilentMode: true,
      shouldPlayInBackground: true,
      interruptionMode: "duckOthers",
    });
    _audioConfigured = true;
  } catch {
    // Audio mode not available
  }
}

export async function playAdhan(index: AdhanIndex = 1): Promise<void> {
  const EA = await getExpoAudio();
  if (!EA) return;

  await ensureAudioMode();

  try {
    await stopAdhan();

    const source =
      index === 1
        ? require("@/assets/audio/adhan-1.mp3")
        : require("@/assets/audio/adhan-2.mp3");

    const player = EA.createAudioPlayer(source);
    _currentPlayer = player;
    _currentIndex = index;
    _showsMiniPlayer = true;

    player.play();
    _isPlaying = true;
    _currentTime = player.currentTime;
    _duration = player.duration;
    notify();

    startPolling();
  } catch {
    cleanupPlayer();
    notify();
  }
}

export async function togglePlayPause(): Promise<void> {
  if (!_currentPlayer) return;
  try {
    if (_isPlaying) {
      _currentPlayer.pause();
      _isPlaying = false;
    } else {
      _currentPlayer.play();
      _isPlaying = true;
    }
    notify();
  } catch {
    // Ignore
  }
}

export async function stopAdhan(): Promise<void> {
  if (_currentPlayer) {
    try {
      await _currentPlayer.stop();
    } catch {
      // Ignore cleanup errors
    }
  }
  cleanupPlayer();
  notify();
}

async function getExpoAudio(): Promise<typeof import("expo-audio") | null> {
  try {
    return await import("expo-audio");
  } catch {
    return null;
  }
}
