import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                settingsBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if let err = model.loadError {
                            errorBanner(err)
                        }

                        VStack(spacing: 16) {
                            settingsSection(
                                title: "Mosque",
                                subtitle: "Choose the official timetable used across the app."
                            ) {
                                mosquePicker
                            }

                            settingsSection(
                                title: "Display",
                                subtitle: "Keep times easy to scan at a glance."
                            ) {
                                SettingsToggleRow(
                                    icon: "clock",
                                    title: "24-hour time",
                                    subtitle: settings.uses24HourTime ? "Showing 18:45 style times" : "Showing 6:45 PM style times",
                                    isOn: Bindable(settings).uses24HourTime
                                )
                            }

                            settingsSection(
                                title: "Notifications",
                                subtitle: "Control prayer reminders for the selected mosque."
                            ) {
                                VStack(spacing: 10) {
                                    SettingsToggleRow(
                                        icon: "bell.badge",
                                        title: "Prayer notifications",
                                        subtitle: settings.notifications.masterEnabled ? "Reminders are active" : "All reminders are paused",
                                        isOn: masterNotificationsBinding,
                                        isPrimary: true
                                    )

                                    if settings.notifications.masterEnabled {
                                        notificationRows
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: settings.notifications.masterEnabled)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HomeDesign.Colors.accent)
                }
            }
        }
        .accessibilityIdentifier("tabSettings")
        .task {
            await model.load()
        }
    }

    private var settingsBackground: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                gradient: HomeDesign.TimeTheme.weather.gradient,
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(HomeDesign.Colors.accent.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 130, y: -120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(HomeDesign.Colors.primary)
                .accessibilityAddTraits(.isHeader)

            Text("Manage your mosque, time format, and prayer reminders.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(HomeDesign.Colors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "D98A2B"))

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeDesign.Colors.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFF5E6"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "F6C15A").opacity(0.35), lineWidth: 1)
        )
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(HomeDesign.Colors.primary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(HomeDesign.Colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(HomeDesign.Colors.glassBorder, lineWidth: 1)
                )
                .customShadow(HomeDesign.Shadows.softCard)
        }
    }

    private var mosquePicker: some View {
        Picker("Mosque", selection: mosqueSelectionBinding) {
            ForEach(model.mosques) { m in
                Text(m.name).tag(m.id)
            }
        }
        .pickerStyle(.menu)
        .tint(HomeDesign.Colors.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("MosquePicker")
    }

    private var notificationRows: some View {
        VStack(spacing: 0) {
            NotificationToggleRow(title: "Fajr", isOn: binding(\.fajr))
            SettingsDivider()
            NotificationToggleRow(title: "Dhuhr / Jummah", isOn: binding(\.dhuhrJummah))
            SettingsDivider()
            NotificationToggleRow(title: "Asr", isOn: binding(\.asr))
            SettingsDivider()
            NotificationToggleRow(title: "Maghrib", isOn: binding(\.maghrib))
            SettingsDivider()
            NotificationToggleRow(title: "Isha", isOn: binding(\.isha))
        }
        .padding(.top, 2)
        .background(Color(hex: "F8F9FB"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var mosqueSelectionBinding: Binding<String> {
        Binding(
            get: {
                if let id = settings.selectedMosqueId, model.mosques.contains(where: { $0.id == id }) {
                    return id
                }
                return model.mosques.first?.id ?? ""
            },
            set: { id in
                guard let m = model.mosques.first(where: { $0.id == id }) else { return }
                Task { await model.selectMosque(m) }
            }
        )
    }

    private var masterNotificationsBinding: Binding<Bool> {
        Binding(
            get: { settings.notifications.masterEnabled },
            set: { newValue in
                var n = settings.notifications
                n.masterEnabled = newValue
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.notifications[keyPath: keyPath] },
            set: { newValue in
                var n = settings.notifications
                n[keyPath: keyPath] = newValue
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isPrimary = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isPrimary ? .white : HomeDesign.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(isPrimary ? HomeDesign.Colors.activeGradient : LinearGradient(colors: [Color(hex: "EEF7FF")], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HomeDesign.Colors.primary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(HomeDesign.Colors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(HomeDesign.Colors.accent)
        .padding(.vertical, 4)
    }
}

private struct NotificationToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(HomeDesign.Colors.primary)
            .tint(HomeDesign.Colors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(HomeDesign.Colors.glassBorder)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}
