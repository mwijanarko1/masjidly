import SwiftUI

/// Launch modal offering to switch to the geographically closest mosque.
struct ClosestMosquePromptModalView: View {
    let closestMosqueName: String
    let selectedMosqueName: String
    let timeTheme: HomeDesign.TimeTheme
    let locale: Locale
    let onUseClosest: () -> Void
    let onKeepSelected: () -> Void

    private var title: String {
        LocaleBundle.string(forKey: "home.closest_mosque_prompt.title", locale: locale)
    }

    private var message: String {
        LocaleBundle.string(forKey: "home.closest_mosque_prompt.message", locale: locale)
    }

    private var useTitle: String {
        String(
            format: LocaleBundle.string(forKey: "home.closest_mosque_prompt.use_format", locale: locale),
            closestMosqueName
        )
    }

    private var keepTitle: String {
        String(
            format: LocaleBundle.string(forKey: "home.closest_mosque_prompt.keep_format", locale: locale),
            selectedMosqueName
        )
    }

    var body: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text(title)
                        .appFont(size: 26, weight: .bold)
                        .foregroundStyle(timeTheme.textColor)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .appFont(size: 15, weight: .regular)
                        .foregroundStyle(timeTheme.textColor.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    Button(action: onUseClosest) {
                        Text(useTitle)
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("ClosestMosquePrompt.Use")

                    Button(action: onKeepSelected) {
                        Text(keepTitle)
                            .appFont(size: 15, weight: .regular)
                            .foregroundStyle(timeTheme.textColor.opacity(0.7))
                            .underline(true, color: timeTheme.textColor.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("ClosestMosquePrompt.Keep")
                }
                .padding(.bottom, 8)
            }
            .padding(24)
        }
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
    }
}
