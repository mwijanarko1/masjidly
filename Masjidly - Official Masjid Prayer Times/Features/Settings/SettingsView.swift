import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        NavigationStack {
            Form {
                if let err = model.loadError {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }
                Section("Mosque") {
                    Picker("Mosque", selection: mosqueSelectionBinding) {
                        ForEach(model.mosques) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                    .accessibilityIdentifier("MosquePicker")
                }
                Section("Display") {
                    Toggle("24-hour time", isOn: Bindable(settings).uses24HourTime)
                }
                Section("Notifications") {
                    Toggle("Prayer notifications", isOn: masterNotificationsBinding)
                    if settings.notifications.masterEnabled {
                        Toggle("Fajr", isOn: binding(\.fajr))
                        Toggle("Dhuhr / Jummah", isOn: binding(\.dhuhrJummah))
                        Toggle("Asr", isOn: binding(\.asr))
                        Toggle("Maghrib", isOn: binding(\.maghrib))
                        Toggle("Isha", isOn: binding(\.isha))
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .accessibilityIdentifier("tabSettings")
        .task {
            await model.load()
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
