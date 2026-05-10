import SwiftUI

struct OnboardingCoachMarkView: View {
    let title: String
    let message: String
    /// Matches home / sheet sky so type and glass read as one Masjidly surface (not generic gray Material).
    let timeTheme: HomeDesign.TimeTheme
    /// Positions the hint card away from the controls users must tap.
    let variant: Variant

    enum Variant {
        /// Hint sits just under the top chrome (calendar / date / settings stay clear and tappable).
        case belowTopChrome
        /// Hint sits above the prayer-letter row so F–I shortcuts stay fully visible and tappable.
        case aboveShortcutRow
    }

    var body: some View {
        GeometryReader { geo in
            let topChrome = max(geo.safeAreaInsets.top, 56) + 12
            let topCardInset = topChrome + 52
            let shortcutReserve = geo.safeAreaInsets.bottom + min(260, max(200, geo.size.height * 0.31))

            ZStack {
                // Airy, atmospheric overlay instead of heavy black slab
                Color.black.opacity(timeTheme.usesLightForeground ? 0.12 : 0.08)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                switch variant {
                case .belowTopChrome:
                    VStack(spacing: 0) {
                        hintCard
                            .padding(.horizontal, 24)
                            .padding(.top, topCardInset)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                case .aboveShortcutRow:
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        hintCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, shortcutReserve)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private var hintCard: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(HomeDesign.Typography.app(size: 19, weight: .semibold))
                    .foregroundStyle(timeTheme.textColor)
                    .kerning(-0.2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(HomeDesign.Typography.app(size: 16, weight: .regular))
                    .foregroundStyle(timeTheme.textColor.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(24)
        }
    }
}

struct OnboardingHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHighlighted {
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: 1.5)
                        .padding(-6)
                        .shadow(color: .white.opacity(0.3), radius: 8)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(isHighlighted ? 1.08 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHighlighted)
    }
}

extension View {
    func onboardingHighlight(_ isHighlighted: Bool) -> some View {
        modifier(OnboardingHighlightModifier(isHighlighted: isHighlighted))
    }
}
