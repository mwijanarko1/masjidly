import SwiftUI

/// Bottom chrome for in-app adhan playback — frosted glass, border, shadow, and type colors match onboarding coach cards (`OnboardingTutorialChrome`).
struct AdhanMiniPlayerBar: View {
    let timeTheme: HomeDesign.TimeTheme
    @Bindable private var playback = AdhanSoundPreviewPlayer.shared

    private let rowSpacing: CGFloat = 16
    private let cardContentSpacing: CGFloat = 10

    var body: some View {
        if playback.showsMiniPlayer {
            OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                VStack(alignment: .leading, spacing: cardContentSpacing) {
                    adhanProgressTrack(fraction: playback.playbackFraction)

                    HStack(alignment: .center, spacing: rowSpacing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adhan")
                                .appFont(size: 19, weight: .semibold)
                                .foregroundStyle(timeTheme.textColor)
                                .kerning(-0.2)
                                .lineLimit(1)
                            Text(timeRemainingLabel)
                                .appFont(size: 14, weight: .regular)
                                .foregroundStyle(timeTheme.textColor.opacity(0.82))
                                .tracking(0.4)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            playback.togglePlayPauseFromChrome()
                        } label: {
                            Image(systemName: playback.isPlayingForUI ? "pause.fill" : "play.fill")
                                .appFont(size: 17, weight: .semibold)
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(HomeDesign.Colors.activeGradient, in: Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .shadow(color: HomeDesign.Colors.accent.opacity(0.35), radius: 15, y: 8)
                        .accessibilityLabel(playback.isPlayingForUI ? "Pause adhan" : "Play adhan")

                        Button {
                            playback.dismissMiniPlayer()
                        } label: {
                            Image(systemName: "xmark")
                                .appFont(size: 14, weight: .medium)
                                .foregroundStyle(timeTheme.textColor.opacity(0.55))
                                .frame(width: 40, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop adhan")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func adhanProgressTrack(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(timeTheme.textColor.opacity(0.18))
                Capsule()
                    .fill(HomeDesign.Colors.activeGradient)
                    .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adhan playback progress")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }

    private var timeRemainingLabel: String {
        let cur = playback.displayedCurrentTime
        let dur = playback.displayedDuration
        guard dur > 0 else { return "—" }
        let left = max(0, dur - cur)
        return "\(formatMMSS(cur)) / \(formatMMSS(dur)) · \(formatMMSS(left)) left"
    }

    private func formatMMSS(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.down)))
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
