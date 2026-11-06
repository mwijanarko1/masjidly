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
    let locale: Locale
    var onDismiss: (() -> Void)? = nil

    private var copy: WhatsNewModalCopy {
        WhatsNewModalCopy(locale: locale)
    }

    var body: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    Text(copy.title)
                        .appFont(size: 26, weight: .bold)
                        .foregroundStyle(timeTheme.textColor)

                    Text(copy.versionLabel(version))
                        .appFont(size: 14, weight: .medium)
                        .foregroundStyle(timeTheme.textColor.opacity(0.62))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(timeTheme.textColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)

                ViewThatFits(in: .vertical) {
                    itemsList
                        .padding(.horizontal, 2)

                    ScrollView {
                        itemsList
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                    }
                    .scrollIndicators(.visible)
                }

                // Continue button — uses the blue-gradient capsule from onboarding
                Button {
                    if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(copy.continueLabel)
                        .onboardingPrimaryCapsule()
                }
                .buttonStyle(.hapticPlain)
                .padding(.bottom, 8)
            }
            .padding(24)
        }
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
    }

    private var itemsList: some View {
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
                    }
                }
            }
        }
    }

}

private struct WhatsNewModalCopy {
    let title: String
    let versionPrefix: String
    let continueLabel: String

    init(locale: Locale) {
        let code = locale.language.languageCode?.identifier ?? String(locale.identifier.prefix(2))
        switch code {
        case "ar":
            title = "تحديث مسجدلي!"
            versionPrefix = "الإصدار"
            continueLabel = "متابعة"
        case "ur":
            title = "مسجدلی اپ ڈیٹ!"
            versionPrefix = "ورژن"
            continueLabel = "جاری رکھیں"
        case "id":
            title = "Pembaruan Masjidly!"
            versionPrefix = "Versi"
            continueLabel = "Lanjut"
        default:
            title = "Masjidly Update!"
            versionPrefix = "Version"
            continueLabel = "Continue"
        }
    }

    func versionLabel(_ version: String) -> String {
        "\(versionPrefix) \(version)"
    }
}

#Preview {
    WhatsNewModalView(
        version: "1.1",
        items: WhatsNew.latestUpdates,
        timeTheme: .fajr,
        locale: Locale(identifier: "en")
    )
}
