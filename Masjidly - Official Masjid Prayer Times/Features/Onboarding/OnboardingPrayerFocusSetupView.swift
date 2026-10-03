import FamilyControls
import SwiftUI

/// Step 1: opt in or skip Prayer Focus (tutorial chrome).
struct OnboardingPrayerFocusIntroView: View {
    let timeTheme: HomeDesign.TimeTheme
    let onTurnOn: () -> Void
    let onSkip: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        prayerFocusOnboardingChrome(timeTheme: timeTheme) {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text(localized("onboarding.prayer_focus.intro.title"))
                        .appFont(size: 23, weight: .semibold)
                        .foregroundStyle(timeTheme.textColor)
                        .kerning(-0.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(localized("onboarding.prayer_focus.intro.message"))
                        .appFont(size: 16)
                        .foregroundStyle(timeTheme.textColor.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .onboardingEntrance(0)

                VStack(spacing: 12) {
                    Button(action: onTurnOn) {
                        Text(localized("onboarding.prayer_focus.intro.turn_on"))
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Onboarding.PrayerFocusTurnOn")

                    Button(action: onSkip) {
                        Text(localized("onboarding.location.skip"))
                            .appFont(size: 16, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Onboarding.PrayerFocusIntroSkip")
                }
                .onboardingEntrance(1)
            }
            .padding(24)
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

/// Step 2: Screen Time first if needed, then an intermediate “Choose apps” card before the system picker.
struct OnboardingPrayerFocusAppsView: View {
    let timeTheme: HomeDesign.TimeTheme
    let onContinue: () -> Void
    let onSkip: () -> Void
    @Environment(\.locale) private var locale
    /// Owned here so HomeView does not observe Prayer Focus and re-render on every reschedule.
    @Bindable private var prayerFocus = PrayerFocusController.shared
    @State private var isRequestingAuthorization = false
    @State private var authorizationFailed = false
    /// Local picker state; binding directly to `@Observable` selection often fails to commit on Done.
    @State private var isPickerPresented = false
    @State private var pickerSelection = FamilyActivitySelection()

    private var selectedAppCount: Int { PrayerFocusController.selectionCount(pickerSelection) }

    private var canContinue: Bool {
        prayerFocus.isAuthorized && selectedAppCount > 0
    }

    var body: some View {
        prayerFocusOnboardingChrome(timeTheme: timeTheme) {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text(localized(prayerFocus.isAuthorized
                        ? "onboarding.prayer_focus.apps.title"
                        : "onboarding.prayer_focus.screen_time.title"))
                        .appFont(size: 23, weight: .semibold)
                        .foregroundStyle(timeTheme.textColor)
                        .kerning(-0.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(localized(prayerFocus.isAuthorized
                        ? "onboarding.prayer_focus.apps.message"
                        : "onboarding.prayer_focus.screen_time.message"))
                        .appFont(size: 16)
                        .foregroundStyle(timeTheme.textColor.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .onboardingEntrance(0)

                VStack(spacing: 12) {
                    if !prayerFocus.isAuthorized {
                        Button {
                            guard !isRequestingAuthorization else { return }
                            isRequestingAuthorization = true
                            authorizationFailed = false
                            Task {
                                // Only request access here; Prayer Focus turns on at Finish.
                                do {
                                    try await prayerFocus.requestAuthorization()
                                } catch {
                                    authorizationFailed = true
                                }
                                authorizationFailed = authorizationFailed || !prayerFocus.isAuthorized
                                isRequestingAuthorization = false
                            }
                        } label: {
                            Group {
                                if isRequestingAuthorization {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(HomeDesign.Colors.activeGradient, in: Capsule())
                                } else {
                                    Text(localized("settings.prayer_focus.allow_access"))
                                        .onboardingPrimaryCapsule()
                                }
                            }
                        }
                        .buttonStyle(.hapticPlain)
                        .disabled(isRequestingAuthorization)
                        .accessibilityIdentifier("Onboarding.PrayerFocusAllowScreenTime")

                        if authorizationFailed {
                            Text(localized("settings.prayer_focus.status.needs_authorization"))
                                .appFont(size: 14, weight: .medium)
                                .foregroundStyle(timeTheme.textColor.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("Onboarding.PrayerFocusAuthorizationError")
                        }
                    } else if canContinue {
                        // Tapping the selection card reopens the picker, so no separate "Choose apps" button.
                        Button {
                            isPickerPresented = true
                        } label: {
                            HStack(spacing: 10) {
                                Text(PrayerFocusController.selectionSummary(pickerSelection, locale: locale, localized: localized))
                                    .appFont(size: 16, weight: .medium)
                                    .foregroundStyle(timeTheme.textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(timeTheme.textColor.opacity(0.5))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(timeTheme.textColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(timeTheme.textColor.opacity(0.14), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.hapticPlain)
                        .accessibilityLabel(localized("settings.prayer_focus.choose_apps"))
                        .accessibilityIdentifier("Onboarding.PrayerFocusChooseApps")

                        Button(action: onContinue) {
                            Text(localized("onboarding.continue"))
                                .onboardingPrimaryCapsule()
                        }
                        .buttonStyle(.hapticPlain)
                        .accessibilityIdentifier("Onboarding.PrayerFocusAppsContinue")
                        .padding(.top, 6)
                    } else {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Text(localized("settings.prayer_focus.choose_apps"))
                                .onboardingPrimaryCapsule()
                        }
                        .buttonStyle(.hapticPlain)
                        .accessibilityIdentifier("Onboarding.PrayerFocusChooseApps")
                    }

                    Button(action: onSkip) {
                        Text(localized("onboarding.location.skip"))
                            .appFont(size: 16, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Onboarding.PrayerFocusAppsSkip")
                }
                .animation(.easeInOut(duration: 0.25), value: canContinue)
                .onboardingEntrance(1)
            }
            .padding(24)
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $pickerSelection)
        .onAppear {
            pickerSelection = prayerFocus.selection
        }
        .onChange(of: isPickerPresented) { _, presented in
            guard !presented else { return }
            // Commit selection after Done; FamilyControls often won't write through @Observable bindings.
            // The user advances explicitly with Continue.
            prayerFocus.selection = pickerSelection
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

/// Step 3: start, duration, and which prayers.
struct OnboardingPrayerFocusScheduleView: View {
    let timeTheme: HomeDesign.TimeTheme
    let onFinish: () -> Void
    @Environment(\.locale) private var locale
    /// Draft locally so toggles do not hit DeviceActivity on every change.
    @State private var draft = PrayerFocusController.shared.settings
    @State private var scheduleFailed = false
    @State private var rowsHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let topMargin = max(proxy.safeAreaInsets.top + 32, 80 as CGFloat)
            let bottomMargin = proxy.safeAreaInsets.bottom + 24
            let availableHeight = max(280, proxy.size.height - topMargin - bottomMargin)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(timeTheme.usesLightForeground ? 0.32 : 0.18),
                        Color.black.opacity(timeTheme.usesLightForeground ? 0.16 : 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localized("onboarding.prayer_focus.schedule.title"))
                                    .appFont(size: 23, weight: .semibold)
                                    .foregroundStyle(timeTheme.textColor)
                                    .kerning(-0.5)

                                Text(localized("onboarding.prayer_focus.schedule.message"))
                                    .appFont(size: 16, weight: .regular)
                                    .foregroundStyle(timeTheme.textColor.opacity(0.8))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .onboardingEntrance(0)

                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 16) {
                                    scheduleRow(title: localized("settings.prayer_focus.start.title")) {
                                        Picker(localized("settings.prayer_focus.start.title"), selection: $draft.start) {
                                            Text(localized("notification.channel.adhan")).tag(PrayerFocusStart.adhan)
                                            Text(localized("notification.channel.iqamah")).tag(PrayerFocusStart.iqamah)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(timeTheme.textColor)
                                    }

                                    scheduleRow(title: localized("settings.prayer_focus.duration.title")) {
                                        Picker(localized("settings.prayer_focus.duration.title"), selection: $draft.durationMinutes) {
                                            ForEach(PrayerFocusSettings.durationOptions, id: \.self) { minutes in
                                                Text(durationLabel(minutes)).tag(minutes)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(timeTheme.textColor)
                                    }

                                    Text(localized("settings.prayer_focus.prayers.title"))
                                        .appFont(size: 16, weight: .semibold)
                                        .foregroundStyle(timeTheme.textColor.opacity(0.6))
                                        .kerning(0.5)

                                    VStack(spacing: 0) {
                                        ForEach(Array(PrayerFocusPrayer.allCases.enumerated()), id: \.element.rawValue) { index, prayer in
                                            if index > 0 {
                                                Divider()
                                                    .background(timeTheme.textColor.opacity(0.12))
                                                    .padding(.vertical, 2)
                                            }
                                            Toggle(isOn: prayerBinding(prayer)) {
                                                Text(localized(prayer.labelKey))
                                                    .appFont(size: 16, weight: .medium)
                                                    .foregroundStyle(timeTheme.textColor)
                                            }
                                            .tint(HomeDesign.Colors.accent)
                                            .frame(minHeight: 48)
                                            .padding(.vertical, 4)
                                            .padding(.trailing, 2)
                                        }
                                    }
                                }
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear { rowsHeight = geo.size.height }
                                            .onChange(of: geo.size.height) { _, height in rowsHeight = height }
                                    }
                                )
                            }
                            // Hug the rows; still scrolls when the card hits the screen limit.
                            .frame(maxHeight: rowsHeight > 0 ? rowsHeight : .infinity)
                            .onboardingEntrance(1)

                            if scheduleFailed {
                                Text(localized("settings.prayer_focus.status.failed"))
                                    .appFont(size: 14, weight: .medium)
                                    .foregroundStyle(timeTheme.textColor.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("Onboarding.PrayerFocusScheduleError")
                            }

                            Button {
                                // First activation point in onboarding; the settings write reschedules synchronously.
                                let controller = PrayerFocusController.shared
                                var next = draft
                                next.isEnabled = true
                                controller.settings = next
                                if controller.status(at: Date()) == .failed {
                                    controller.disable()
                                    scheduleFailed = true
                                } else {
                                    onFinish()
                                }
                            } label: {
                                Text(localized("onboarding.finish"))
                                    .onboardingPrimaryCapsule()
                            }
                            .buttonStyle(.hapticPlain)
                            .accessibilityIdentifier("Onboarding.PrayerFocusFinish")
                            .onboardingEntrance(2)
                        }
                        .toggleStyle(.switch)
                        .padding(24)
                    }
                    .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
                    .frame(maxWidth: 400, maxHeight: availableHeight, alignment: .leading)
                    .padding(.horizontal, 24)
                }
                .padding(.top, topMargin)
                .padding(.bottom, bottomMargin)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .onAppear {
            draft = PrayerFocusController.shared.settings
            draft.isEnabled = true
        }
    }

    private func scheduleRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .appFont(size: 16, weight: .regular)
                .foregroundStyle(timeTheme.textColor)
            Spacer()
            content()
        }
    }

    private func prayerBinding(_ prayer: PrayerFocusPrayer) -> Binding<Bool> {
        Binding(
            get: { draft.prayers.contains(prayer) },
            set: { isOn in
                if isOn {
                    draft.prayers.insert(prayer)
                } else {
                    draft.prayers.remove(prayer)
                }
            }
        )
    }

    private func durationLabel(_ minutes: Int) -> String {
        String(format: localized("settings.reminder.minutes_format"), locale: locale, arguments: [minutes])
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

@ViewBuilder
private func prayerFocusOnboardingChrome<Content: View>(
    timeTheme: HomeDesign.TimeTheme,
    @ViewBuilder content: () -> Content
) -> some View {
    ZStack {
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
            content()
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 400)
        .padding(.horizontal, 18)
    }
    .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
}
