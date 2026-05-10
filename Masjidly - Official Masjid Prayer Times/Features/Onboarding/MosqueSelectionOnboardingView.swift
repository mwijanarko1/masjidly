import SwiftUI

struct MosqueSelectionOnboardingView: View {
    let mosques: [Mosque]
    let timeTheme: HomeDesign.TimeTheme
    @Binding var selectedMosqueId: String
    let onContinue: (Mosque) -> Void

    var body: some View {
        ZStack {
            // Airy, atmospheric background gradient
            LinearGradient(
                colors: [
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.32 : 0.18),
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.16 : 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Choose your mosque")
                            .font(HomeDesign.Typography.app(size: 23, weight: .semibold))
                            .foregroundStyle(timeTheme.textColor)
                            .kerning(-0.5)
                            .multilineTextAlignment(.center)

                        Text("Masjidly will show official prayer and iqamah times for this mosque.")
                            .font(HomeDesign.Typography.app(size: 16, weight: .regular))
                            .foregroundStyle(timeTheme.textColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Picker("Mosque", selection: $selectedMosqueId) {
                        ForEach(mosques) { mosque in
                            Text(mosque.name).tag(mosque.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(timeTheme.usesLightForeground ? Color.white : HomeDesign.Colors.accent)
                    .font(HomeDesign.Typography.app(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Onboarding.MosquePicker")

                    Button {
                        guard let mosque = mosques.first(where: { $0.id == selectedMosqueId }) ?? mosques.first else { return }
                        onContinue(mosque)
                    } label: {
                        Text("Continue")
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.plain)
                    .disabled(mosques.isEmpty)
                    .opacity(mosques.isEmpty ? 0.45 : 1)
                    .accessibilityIdentifier("Onboarding.MosqueContinue")
                }
                .padding(24)
            }
            .frame(maxWidth: 380)
            .padding(.horizontal, 24)
        }
    }
}
