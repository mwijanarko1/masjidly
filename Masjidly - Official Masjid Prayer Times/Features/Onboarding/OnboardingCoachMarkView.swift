import SwiftUI

struct OnboardingCoachMarkView: View {
    let title: String
    let message: String
    /// Matches home / sheet sky so type and glass read as one Masjidly surface (not generic gray Material).
    let timeTheme: HomeDesign.TimeTheme
    /// Positions the hint card away from the controls users must tap.
    let variant: Variant
    /// When set with `onPrimaryButton`, the dimmed backdrop absorbs stray taps so only the card (and its button) advances the flow.
    let primaryButtonTitle: String?
    let onPrimaryButton: (() -> Void)?
    let primaryButtonAccessibilityIdentifier: String?
    /// When false, controls behind the coach mark remain tappable even while the card has a button.
    let blocksBackgroundInteractions: Bool

    /// Optional secondary (lower-emphasis) button shown below the primary button.
    let secondaryButtonTitle: String?
    let onSecondaryButton: (() -> Void)?
    let secondaryButtonAccessibilityIdentifier: String?

    enum Variant {
        /// Hint sits just under the top chrome (calendar / date / settings stay clear and tappable).
        case belowTopChrome
        /// Hint sits above the prayer-letter row so F–I shortcuts stay fully visible and tappable.
        case aboveShortcutRow
        /// Hint sits under the Qibla rings, above the large adhan time.
        case belowQiblaIcon
        /// Hint sits lower than the Qibla rings so the hero circle stays tappable/visible during countdown onboarding.
        case belowQiblaIconLower
        /// Hint pinned to the bottom; no dimming so the sheet behind stays fully interactive (timetable / settings explore).
        case floatingBottom
    }

    init(
        title: String,
        message: String,
        timeTheme: HomeDesign.TimeTheme,
        variant: Variant,
        primaryButtonTitle: String? = nil,
        onPrimaryButton: (() -> Void)? = nil,
        primaryButtonAccessibilityIdentifier: String? = nil,
        blocksBackgroundInteractions: Bool = true,
        secondaryButtonTitle: String? = nil,
        onSecondaryButton: (() -> Void)? = nil,
        secondaryButtonAccessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.message = message
        self.timeTheme = timeTheme
        self.variant = variant
        self.primaryButtonTitle = primaryButtonTitle
        self.onPrimaryButton = onPrimaryButton
        self.primaryButtonAccessibilityIdentifier = primaryButtonAccessibilityIdentifier
        self.blocksBackgroundInteractions = blocksBackgroundInteractions
        self.secondaryButtonTitle = secondaryButtonTitle
        self.onSecondaryButton = onSecondaryButton
        self.secondaryButtonAccessibilityIdentifier = secondaryButtonAccessibilityIdentifier
    }

    private var showsDimmingBackdrop: Bool {
        variant != .floatingBottom
    }

    var body: some View {
        Group {
            if variant == .floatingBottom {
                ZStack {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        hintCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                            .safeAreaPadding(.bottom, 8)
                            .allowsHitTesting(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                GeometryReader { geo in
                    let topChrome = max(geo.safeAreaInsets.top, 56) + 12
                    let topCardInset = topChrome + 52
                    let shortcutReserve = geo.safeAreaInsets.bottom + min(260, max(200, geo.size.height * 0.31))
                    let hasButtons = (onPrimaryButton != nil && primaryButtonTitle != nil) || (onSecondaryButton != nil && secondaryButtonTitle != nil)
                    let blocksBackground = showsDimmingBackdrop && blocksBackgroundInteractions && hasButtons

                    ZStack {
                        if showsDimmingBackdrop {
                            Color.black.opacity(timeTheme.usesLightForeground ? 0.12 : 0.08)
                                .ignoresSafeArea()
                                .accessibilityHidden(true)
                                .allowsHitTesting(blocksBackground)
                        }

                        switch variant {
                        case .floatingBottom:
                            EmptyView()
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

                        case .belowQiblaIcon:
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: max(geo.safeAreaInsets.top, 20) + geo.size.height * 0.28)
                                hintCard
                                    .padding(.horizontal, 24)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        case .belowQiblaIconLower:
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: max(geo.safeAreaInsets.top, 20) + geo.size.height * 0.40)
                                hintCard
                                    .padding(.horizontal, 24)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
                .allowsHitTesting(true)
            }
        }
    }

    @ViewBuilder
    private var hintCard: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .appFont(size: 19, weight: .semibold)
                    .foregroundStyle(timeTheme.textColor)
                    .kerning(-0.2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .appFont(size: 16, weight: .regular)
                    .foregroundStyle(timeTheme.textColor.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let primaryButtonTitle, let onPrimaryButton {
                    Button(action: onPrimaryButton) {
                        Text(primaryButtonTitle)
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.hapticPlain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                    .accessibilityIdentifier(primaryButtonAccessibilityIdentifier ?? "Onboarding.CoachContinue")

                    if let secondaryButtonTitle, let onSecondaryButton {
                        Button(action: onSecondaryButton) {
                            Text(secondaryButtonTitle)
                                .appFont(size: 15, weight: .regular)
                                .foregroundColor(timeTheme.textColor.opacity(0.7))
                                .underline(true, color: timeTheme.textColor.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.hapticPlain)
                        .padding(.top, 4)
                        .accessibilityIdentifier(secondaryButtonAccessibilityIdentifier ?? "Onboarding.CoachSecondary")
                    }
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(24)
        }
    }
}

struct OnboardingHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    let timeTheme: HomeDesign.TimeTheme

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHighlighted {
                    Capsule()
                        .stroke(timeTheme.textColor.opacity(0.8), lineWidth: 1.5)
                        .padding(-6)
                        .shadow(color: timeTheme.textColor.opacity(0.3), radius: 8)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(isHighlighted ? 1.08 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHighlighted)
    }
}

extension View {
    func onboardingHighlight(_ isHighlighted: Bool, timeTheme: HomeDesign.TimeTheme) -> some View {
        modifier(OnboardingHighlightModifier(isHighlighted: isHighlighted, timeTheme: timeTheme))
    }
}
