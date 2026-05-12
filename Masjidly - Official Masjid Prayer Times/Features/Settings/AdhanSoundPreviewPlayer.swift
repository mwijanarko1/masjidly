import AVFoundation
import Foundation
import MediaPlayer
import Observation

private final class AdhanPreviewFinishDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

/// In-app adhan playback with Music-style chrome. Uses **`playback`** session so longer clips keep playing with the screen locked (requires Background Mode › Audio).
@MainActor
@Observable
final class AdhanSoundPreviewPlayer {
    /// Shared instance for notification open → play adhan.
    static let shared = AdhanSoundPreviewPlayer()

    private var player: AVAudioPlayer?
    private var finishDelegate: AdhanPreviewFinishDelegate?
    private var loadedURL: URL?

    private var progressTimer: Timer?

    private(set) var isPlayingForUI = false

    /// Shown when there is an active or paused adhan session.
    private(set) var showsMiniPlayer: Bool = false

    private(set) var displayedDuration: TimeInterval = 0
    private(set) var displayedCurrentTime: TimeInterval = 0

    var playbackFraction: Double {
        let d = displayedDuration
        guard d > 0 else { return 0 }
        return min(1, max(0, displayedCurrentTime / d))
    }

    /// Play / pause / resume for the given bundle URL. Uses a new load if `url` differs from the paused clip.
    func toggle(url: URL?) {
        guard let url else { return }
        if player?.isPlaying == true {
            if loadedURL == url {
                pause()
            } else {
                playFresh(url)
            }
            return
        }
        if player != nil, loadedURL == url {
            resume()
            return
        }
        playFresh(url)
    }

    func togglePlayPauseFromChrome() {
        guard player != nil else { return }
        if isPlayingForUI {
            pause()
        } else {
            resume()
        }
    }

    func dismissMiniPlayer() {
        stop()
    }

    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        finishDelegate = nil
        loadedURL = nil
        isPlayingForUI = false
        showsMiniPlayer = false
        displayedDuration = 0
        displayedCurrentTime = 0
        clearNowPlayingAndRemoteCommands()
        deactivatePlaybackSession()
    }

    private func pause() {
        player?.pause()
        isPlayingForUI = false
        syncDisplayedTimesFromPlayer()
        updateNowPlayingInfo()
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func resume() {
        player?.play()
        isPlayingForUI = player?.isPlaying ?? false
        syncDisplayedTimesFromPlayer()
        updateNowPlayingInfo()
        startProgressTimerIfNeeded()
    }

    private func playFresh(_ url: URL) {
        stop()
        loadedURL = url
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: [])

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            let hook = AdhanPreviewFinishDelegate { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackFinished()
                }
            }
            finishDelegate = hook
            audioPlayer.delegate = hook
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
            isPlayingForUI = true
            showsMiniPlayer = true
            displayedDuration = audioPlayer.duration
            displayedCurrentTime = audioPlayer.currentTime
            configureRemoteCommands()
            updateNowPlayingInfo()
            startProgressTimerIfNeeded()
        } catch {
            player = nil
            finishDelegate = nil
            loadedURL = nil
            isPlayingForUI = false
            showsMiniPlayer = false
            displayedDuration = 0
            displayedCurrentTime = 0
            clearNowPlayingAndRemoteCommands()
            deactivatePlaybackSession()
        }
    }

    private func handlePlaybackFinished() {
        progressTimer?.invalidate()
        progressTimer = nil
        player = nil
        finishDelegate = nil
        loadedURL = nil
        isPlayingForUI = false
        showsMiniPlayer = false
        displayedDuration = 0
        displayedCurrentTime = 0
        clearNowPlayingAndRemoteCommands()
        deactivatePlaybackSession()
    }

    private func startProgressTimerIfNeeded() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tickProgress()
            }
        }
        if let t = progressTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func tickProgress() {
        syncDisplayedTimesFromPlayer()
        updateNowPlayingInfo()
        if player?.isPlaying != true {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    private func syncDisplayedTimesFromPlayer() {
        guard let p = player else { return }
        displayedCurrentTime = p.currentTime
        let d = p.duration
        if d > 0 { displayedDuration = d }
    }

    private func updateNowPlayingInfo() {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: "Adhan",
            MPMediaItemPropertyArtist: "Masjidly",
            MPMediaItemPropertyPlaybackDuration: displayedDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: displayedCurrentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlayingForUI ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                self.stop()
            }
            return .success
        }
    }

    private func clearNowPlayingAndRemoteCommands() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.stopCommand.removeTarget(nil)
    }

    private func deactivatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
