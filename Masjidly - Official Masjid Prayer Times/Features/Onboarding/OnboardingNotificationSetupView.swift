import SwiftUI

struct OnboardingNotificationSetupView: View {
    let timeTheme: HomeDesign.TimeTheme
    @Binding var draft: OnboardingNotificationDraft
    let isSaving: Bool
    let onContinue: () -> Void
    @Environment(\.locale) private var locale

    private let reminderOptions: [Int?] = [nil, 5, 10, 15, 30]

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
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized("onboarding.notifications.title"))
                            .appFont(size: 23, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .kerning(-0.5)

                        Text(localized("onboarding.notifications.message"))
                            .appFont(size: 16, weight: .regular)
                            .foregroundStyle(timeTheme.textColor.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 20) {
                        Toggle(localized("notification.channel.adhan"), isOn: $draft.adhanEnabled)
                            .appFont(size: 18, weight: .medium)
                            .tint(HomeDesign.Colors.accent)
                            .foregroundStyle(timeTheme.textColor)
                            .accessibilityIdentifier("Onboarding.AdhanToggle")

                        Toggle(localized("notification.channel.iqamah"), isOn: $draft.iqamahEnabled)
                            .appFont(size: 18, weight: .medium)
                            .tint(HomeDesign.Colors.accent)
                            .foregroundStyle(timeTheme.textColor)
                            .accessibilityIdentifier("Onboarding.IqamahToggle")
                        
                        Divider()
                            .background(timeTheme.textColor.opacity(0.12))
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(localized("settings.reminders.title"))
                                .appFont(size: 16, weight: .semibold)
                                .foregroundStyle(timeTheme.textColor.opacity(0.6))
                                .kerning(0.5)

                            HStack {
                                Text(localized("settings.reminder.before_adhan"))
                                    .appFont(size: 16, weight: .regular)
                                    .foregroundStyle(timeTheme.textColor)
                                Spacer()
                                Picker(localized("settings.reminder.adhan_picker"), selection: $draft.preAdhanReminderMinutes) {
                                    ForEach(reminderOptions, id: \.self) { minutes in
                                        Text(reminderLabel(for: minutes)).tag(minutes)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(timeTheme.textColor)
                                .accessibilityIdentifier("Onboarding.AdhanReminderPicker")
                            }

                            HStack {
                                Text(localized("settings.reminder.before_iqamah"))
                                    .appFont(size: 16, weight: .regular)
                                    .foregroundStyle(timeTheme.textColor)
                                Spacer()
                                Picker(localized("settings.reminder.iqamah_picker"), selection: $draft.preIqamahReminderMinutes) {
                                    ForEach(reminderOptions, id: \.self) { minutes in
                                        Text(reminderLabel(for: minutes)).tag(minutes)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(timeTheme.textColor)
                                .accessibilityIdentifier("Onboarding.IqamahReminderPicker")
                            }
                        }
                    }

                    Button {
                        onContinue()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(HomeDesign.Colors.activeGradient, in: Capsule())
                            } else {
                                Text(localized("onboarding.finish"))
                                    .onboardingPrimaryCapsule()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .accessibilityIdentifier("Onboarding.NotificationFinish")
                }
                .toggleStyle(.switch)
                .padding(24)
            }
            .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
            .frame(maxWidth: 400, alignment: .leading)
            .padding(.horizontal, 24)
        }
    }

    private func reminderLabel(for minutes: Int?) -> String {
        guard let minutes else { return localized("settings.reminder.off") }
        let format = localized("settings.reminder.minutes_format")
        return String(format: format, locale: locale, arguments: [minutes])
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}
