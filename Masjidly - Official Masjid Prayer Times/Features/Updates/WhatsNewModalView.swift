import SwiftUI

/// A "What's New" update pop-up presented after a new build is installed.
/// Pattern adapted from QuranScroll's `WhatsNewModalView`, styled to match the
/// Masjidly tutorial / onboarding flow — frosted glass `OnboardingTutorialChrome.card`,
/// adaptive `timeTheme.textColor`, and the blue-gradient `.onboardingPrimaryCapsule()`.
struct WhatsNewModalView: View {
    @Environment(\.dismiss) private var dismiss

    let version: String
    let items: [WhatsNewItem]
    let timeTheme: HomeDesign.TimeTheme
    var onDismiss: (() -> Void)? = nil
    var onAction: ((WhatsNewAction) -> Void)?

    var body: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    Text("Masjidly Update!")
                        .appFont(size: 26, weight: .bold)
                        .foregroundStyle(timeTheme.textColor)

                    Text("Version \(version)")
                        .appFont(size: 14, weight: .medium)
                        .foregroundStyle(timeTheme.textColor.opacity(0.62))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(timeTheme.textColor.opacity(0.1))
                        .clipShape(Capsule())

                    // Scroll Indication
                    HStack(spacing: 4) {
                        Text("Swipe to scroll updates")
                            .appFont(size: 12, weight: .medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(timeTheme.textColor.opacity(0.45))
                    .padding(.top, 2)
                }
                .padding(.top, 8)

                // Features List (scrollable)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(HomeDesign.Colors.accent)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .appFont(size: 17, weight: .bold)
                                        .foregroundStyle(timeTheme.textColor)

                                    Text(item.description)
                                        .appFont(size: 14, weight: .regular)
                                        .foregroundStyle(timeTheme.textColor.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)

                                    if let action = item.action {
                                        exploreButton(for: action)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.visible)

                // Continue button — uses the blue-gradient capsule from onboarding
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.prepare()
                    gen.impactOccurred()
                    dismiss()
                    onDismiss?()
                } label: {
                    Text("Continue")
                        .onboardingPrimaryCapsule()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .padding(24)
        }
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
    }

    @ViewBuilder
    private func exploreButton(for action: WhatsNewAction) -> some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()
            dismiss()
            onDismiss?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAction?(action)
            }
        } label: {
            HStack(spacing: 4) {
                Text("Explore")
                    .appFont(size: 12, weight: .bold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(HomeDesign.Colors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(HomeDesign.Colors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.top, 4)
    }
}

#Preview {
    WhatsNewModalView(
        version: "1.1",
        items: WhatsNew.latestUpdates,
        timeTheme: .fajr,
        onAction: { _ in }
    )
}
