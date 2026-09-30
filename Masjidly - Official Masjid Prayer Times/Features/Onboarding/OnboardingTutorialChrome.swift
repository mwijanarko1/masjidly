import SwiftUI

/// Shared “frosted glass on sky” look for onboarding — iOS-native blur + Masjidly tints, not flat Material slabs.
enum OnboardingTutorialChrome {
    static let cornerRadius: CGFloat = 24 // Matches DESIGN.md lg radius

    private static func cardShadow(usesLightForeground: Bool) -> Shadow {
        if usesLightForeground {
            // Night themes: Deep but airy shadow to lift from navy/black voids
            return Shadow(color: .black.opacity(0.24), radius: 30, x: 0, y: 12)
        } else {
            // Day themes: Soft, nearly invisible card shadow matching DESIGN.md
            return HomeDesign.Shadows.softCard
        }
    }

    /// Frosted card behind arbitrary content (caller sets padding / typography).
    static func card<Content: View>(timeTheme: HomeDesign.TimeTheme, @ViewBuilder content: () -> Content) -> some View {
        card(usesLightForeground: timeTheme.usesLightForeground, content: content)
    }

    static func card<Content: View>(appearance: HomeDesign.ResolvedTheme, @ViewBuilder content: () -> Content) -> some View {
        card(usesLightForeground: appearance.usesLightForeground, content: content)
    }

    private static func card<Content: View>(usesLightForeground: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        // Subtle glass border matching DESIGN.md glass-border (#F0F0F0) or light ink
        let border: LinearGradient = {
            if usesLightForeground {
                return LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [Color(hex: "F0F0F0").opacity(0.8), Color(hex: "F0F0F0").opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }()

        return content()
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if usesLightForeground {
                        // Dark themes: Darker tint to make white text pop
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    } else {
                        // Light themes: Milky, clean glass surface
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.88),
                                    Color.white.opacity(0.64),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: 1)
            }
            .customShadow(cardShadow(usesLightForeground: usesLightForeground))
    }
}

extension View {
    /// Masjidly primary onboarding action — soft capsule, brand gradient (not system bordered pill).
    func onboardingPrimaryCapsule() -> some View {
        self.appFont(size: 16, weight: .semibold)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(HomeDesign.Colors.activeGradient, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: HomeDesign.Colors.accent.opacity(0.35), radius: 15, y: 8)
    }
}

private struct OnboardingEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.2)
                        : .spring(response: 0.5, dampingFraction: 0.85).delay(0.06 + Double(index) * 0.08)
                ) { shown = true }
            }
    }
}

extension View {
    /// Fade-up on first appearance; `index` staggers siblings (title 0, content 1, buttons 2).
    func onboardingEntrance(_ index: Int) -> some View {
        modifier(OnboardingEntrance(index: index))
    }
}
