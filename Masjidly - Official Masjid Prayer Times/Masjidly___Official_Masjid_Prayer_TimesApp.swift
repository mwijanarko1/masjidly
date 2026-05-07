import SwiftUI

@main
struct Masjidly___Official_Masjid_Prayer_TimesApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            HomeView(model: env.homeViewModel)
                .environment(env.settings)
                .environment(env.settingsViewModel)
        }
    }
}
