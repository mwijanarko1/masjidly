import Observation
import SwiftUI

private func LS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    let timeTheme: HomeDesign.TimeTheme
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                Section {
                    mosquePicker
                } header: {
                    sectionHeader(localized("settings.section.mosque.title"))
                }
                .listRowBackground(Color.white.opacity(timeTheme == .isha || timeTheme == .tahajjud ? 0.05 : 0.4))

                Section {
                    languagePicker
                } header: {
                    sectionHeader(localized("settings.language.title"))
                }
                .listRowBackground(Color.white.opacity(timeTheme == .isha || timeTheme == .tahajjud ? 0.05 : 0.4))

                Section {
                    SettingsToggleRow(
                        icon: "clock",
                        title: localized("settings.time.24h.title"),
                        isOn: Bindable(settings).uses24HourTime,
                        timeTheme: timeTheme
                    )
                } header: {
                    sectionHeader(localized("settings.section.display.title"))
                }
                .listRowBackground(Color.white.opacity(timeTheme == .isha || timeTheme == .tahajjud ? 0.05 : 0.4))

                Section {
                    SettingsToggleRow(
                        icon: "bell.badge",
                        title: localized("settings.notifications.master.title"),
                        isOn: masterNotificationsBinding,
                        timeTheme: timeTheme,
                        isPrimary: true
                    )

                    if settings.notifications.masterEnabled {
                        notificationRows
                    }
                } header: {
                    sectionHeader(localized("settings.notifications.title"))
                }
                .listRowBackground(Color.white.opacity(timeTheme == .isha || timeTheme == .tahajjud ? 0.05 : 0.4))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(settingsBackground)
            .navigationTitle(localized("settings.navigation.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(timeTheme.textColor)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
            }
        }
        .accessibilityIdentifier("tabSettings")
        .task {
            await model.load()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(HomeDesign.Typography.app(size: 14, weight: .medium))
            .foregroundColor(timeTheme.textColor.opacity(0.6))
            .textCase(nil)
            .padding(.leading, -16) // Align closer to the list edge
    }

    private func localized(_ key: String) -> String {
        LS(key, locale: locale)
    }

    private var languagePicker: some View {
        HStack {
            Image(systemName: "globe")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(timeTheme.textColor)
                .frame(width: 24)
            
            Text(localized("settings.language.picker"))
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)

            Spacer()

            Picker("", selection: Bindable(settings).appLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(LS(lang.catalogOptionKey, locale: locale))
                        .tag(lang)
                }
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
        }
    }

    private var settingsBackground: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                gradient: timeTheme.gradient,
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(timeTheme.iconColor.opacity(0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 150, y: -100)
        }
        .ignoresSafeArea()
    }





    private var mosquePicker: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(timeTheme.textColor)
                .frame(width: 24)
            
            Text(localized("settings.mosque.picker"))
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)

            Spacer()

            Picker("", selection: mosqueSelectionBinding) {
                ForEach(model.mosques) { m in
                    Text(m.name).tag(m.id)
                }
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
        }
    }

    private var notificationRows: some View {
        Group {
            NotificationToggleRow(title: localized("settings.notification.fajr"), isOn: binding(\.fajr), timeTheme: timeTheme)
            NotificationToggleRow(title: localized("settings.notification.dhuhr_jummah"), isOn: binding(\.dhuhrJummah), timeTheme: timeTheme)
            NotificationToggleRow(title: localized("settings.notification.asr"), isOn: binding(\.asr), timeTheme: timeTheme)
            NotificationToggleRow(title: localized("settings.notification.maghrib"), isOn: binding(\.maghrib), timeTheme: timeTheme)
            NotificationToggleRow(title: localized("settings.notification.isha"), isOn: binding(\.isha), timeTheme: timeTheme)
        }
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
    @Binding var isOn: Bool
    let timeTheme: HomeDesign.TimeTheme
    var isPrimary = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(timeTheme.textColor)
                    .frame(width: 24, alignment: .center)

                Text(title)
                    .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                    .foregroundColor(timeTheme.textColor)
            }
        }
        .tint(timeTheme.textColor)
    }
}

private struct NotificationToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let timeTheme: HomeDesign.TimeTheme

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(HomeDesign.Typography.app(size: 17, weight: .regular))
            .foregroundColor(timeTheme.textColor)
            .tint(timeTheme.textColor)
            .padding(.leading, 40)
    }
}

#Preview {
    let settings = SettingsStore()
    let repo = ConvexPrayerRepository(service: ConvexService())
    let scheduler = PrayerNotificationScheduler(repository: repo)
    let model = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    return SettingsView(model: model, timeTheme: .dhuhr)
        .environment(settings)
}
