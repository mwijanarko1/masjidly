import SwiftUI

private func homeLS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.locale) private var locale

    @State private var showingSettings = false
    @State private var showingTimetable = false
    @State private var selectedPrayerIndex = 0

    private var currentTheme: HomeDesign.TimeTheme {
        currentActiveTheme(d: model.displayedPrayerTimes)
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = HomeViewportMetrics(geometry: geo)
            ZStack(alignment: .bottom) {
                backgroundLayer(metrics: metrics)

                if let d = model.displayedPrayerTimes {
                    let prayers: [(canonical: String, time: String, theme: HomeDesign.TimeTheme)] = [
                        ("Fajr", d.fajr, .fajr),
                        ("Sunrise", d.sunrise, .sunrise),
                        ("Dhuhr", d.dhuhr, .dhuhr),
                        ("Asr", d.asr, .asr),
                        ("Maghrib", d.maghrib, .maghrib),
                        ("Isha", d.isha, .isha)
                    ]
                    let slug = model.selectedMosque?.slug ?? ""
                    let prayer = prayers[selectedPrayerIndex]
                    let adhanFormatted = formatTime(prayer.time)
                    let iqSubtitle = iqamahSubtitleLine(
                        prayerName: prayer.canonical,
                        adhanRaw: prayer.time,
                        daily: d,
                        iq: model.iqamahTimes,
                        mosqueSlug: slug
                    )
                    let displayName = PrayerLocalization.displayName(canonicalEnglish: prayer.canonical, locale: locale)
                    let labels = prayers.map { PrayerLocalization.displayName(canonicalEnglish: $0.canonical, locale: locale) }

                    MinimalistPrayerPage(
                        prayerName: displayName,
                        prayerTime: adhanFormatted,
                        iqamahTime: iqSubtitle,
                        theme: prayer.theme,
                        prayerLabels: labels,
                        selectedIndex: selectedPrayerIndex,
                        totalCount: prayers.count,
                        onSelectPrayer: { selectedPrayerIndex = $0 }
                    )
                    .onAppear {
                        if let nextName = model.nextCountdown?.nextName {
                            if let index = prayers.firstIndex(where: { $0.canonical == nextName }) {
                                selectedPrayerIndex = index
                            }
                        }
                    }
                } else {
                    ProgressView()
                }

                VStack {
                    HStack(alignment: .center) {
                        // Symmetrical placeholder to ensure dateDisplay is perfectly centered
                        Color.clear
                            .frame(width: 44, height: 44)
                            .padding(.leading, metrics.leadingChromeInset)
                        
                        Spacer()
                        
                        dateDisplay
                        
                        Spacer()
                        
                        settingsButton
                            .padding(.trailing, metrics.trailingChromeInset)
                    }
                    .padding(.top, metrics.topChromeInset)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .accessibilityIdentifier("tabHome")
        .task {
            await model.load()
            await model.resyncNotificationsIfNeeded()
        }
        .onAppear {
            Task { await model.applySelectionFromSettings() }
        }
        .onChange(of: settings.notifications.masterEnabled) { _, _ in
            Task { await model.resyncNotificationsIfNeeded() }
        }
        .onChange(of: settings.appLanguage) { _, _ in
            Task { await model.resyncNotificationsIfNeeded() }
        }
        .sheet(isPresented: $showingTimetable) {
            if let monthData = model.monthData, let mosque = model.selectedMosque {
                TimetableView(monthData: monthData, mosqueName: mosque.name, timeTheme: currentTheme)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: settingsViewModel, timeTheme: currentTheme)
                .environment(settings)
        }
    }

    @ViewBuilder
    private func backgroundLayer(metrics: HomeViewportMetrics) -> some View {
        let theme = currentActiveTheme(d: model.displayedPrayerTimes)
        ZStack {
            LinearGradient(gradient: theme.gradient, startPoint: .top, endPoint: .bottom)

            Circle()
                .fill(theme.iconColor.opacity(0.1))
                .frame(width: metrics.backgroundGlowDiameter, height: metrics.backgroundGlowDiameter)
                .offset(x: metrics.backgroundGlowOffsetX, y: metrics.backgroundGlowOffsetY)
                .blur(radius: 80)
        }
        .animation(.easeInOut(duration: 0.5), value: selectedPrayerIndex)
        .ignoresSafeArea()
    }

    private func currentActiveTheme(d: DailyPrayerTimes?) -> HomeDesign.TimeTheme {
        guard d != nil else { return .fajr }
        let prayers: [HomeDesign.TimeTheme] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        if selectedPrayerIndex < prayers.count {
            return prayers[selectedPrayerIndex]
        }
        return .fajr
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(HomeDesign.Typography.app(size: 20, weight: .light))
                .foregroundColor(currentTheme.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(homeLS("accessibility.settings", locale: locale)))
    }

    private var dateDisplay: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(currentDateString.uppercased())
                .font(HomeDesign.Typography.app(size: 13, weight: .semibold))
                .kerning(1.0)
                .foregroundColor(currentTheme.textColor.opacity(0.6))
            
            Text(currentHijriDateString.uppercased())
                .font(HomeDesign.Typography.app(size: 10, weight: .medium))
                .kerning(0.8)
                .foregroundColor(currentTheme.textColor.opacity(0.4))
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private var currentHijriDateString: String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamicCalendar
        formatter.locale = locale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func selectMosque(_ mosque: Mosque) {
        model.selectedMosque = mosque
        settings.selectedMosqueId = mosque.id
        settings.selectedMosqueSlug = mosque.slug
        Task {
            try? await model.refreshPrayerPayload(for: mosque)
            await model.resyncNotificationsIfNeeded()
        }
    }

    private func formatTime(_ t: String) -> String {
        settings.uses24HourTime ? t : PrayerTimesEngine.formatTo12Hour(t)
    }

    private func isFridayInSheffield(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.component(.weekday, from: date) == 6
    }

    private func iqamahString(for prayerName: String, daily: DailyPrayerTimes, iq: DailyIqamahTimes?, mosqueSlug: String) -> String? {
        guard let iq else { return nil }
        let now = Date()
        switch prayerName {
        case "Fajr":
            return PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: daily.fajr, iqamahTimes: iq)
        case "Sunrise":
            return nil
        case "Dhuhr":
            if isFridayInSheffield(now) {
                let j = iq.jummah.trimmingCharacters(in: .whitespacesAndNewlines)
                return j.isEmpty ? nil : j
            }
            return PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: daily.dhuhr, iqamahTimes: iq)
        case "Asr":
            return PrayerTimesEngine.getIqamahTime(prayer: "asr", adhanTime: daily.asr, iqamahTimes: iq)
        case "Maghrib":
            return PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: daily.maghrib, iqamahTimes: iq)
        case "Isha":
            return PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: mosqueSlug,
                date: now,
                ishaAdhan: daily.isha,
                iqamahTimes: iq,
                maghribAdhan: daily.maghrib
            )
        default:
            return nil
        }
    }

    /// Subtitle under adhan as localized `Iqamah: <time>`; when iqamah equals adhan, uses the same formatted string as the hero adhan.
    private func iqamahSubtitleLine(
        prayerName: String,
        adhanRaw: String,
        daily: DailyPrayerTimes,
        iq: DailyIqamahTimes?,
        mosqueSlug: String
    ) -> String? {
        guard let raw = iqamahString(for: prayerName, daily: daily, iq: iq, mosqueSlug: mosqueSlug) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let adhanFormatted = formatTime(adhanRaw)
        let iqFormatted = formatTime(raw)
        let displayTime = iqFormatted == adhanFormatted ? adhanFormatted : iqFormatted
        let format = homeLS("home.iqamah_format", locale: locale)
        return String(format: format, locale: locale, arguments: [displayTime])
    }
}

// MARK: - Viewport-aware layout

private struct HomeViewportMetrics: Sendable {
    let width: CGFloat
    let height: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let safeTrailing: CGFloat
    let safeLeading: CGFloat

    init(geometry: GeometryProxy) {
        let s = geometry.size
        width = s.width
        height = s.height
        safeTop = geometry.safeAreaInsets.top
        safeBottom = geometry.safeAreaInsets.bottom
        safeTrailing = geometry.safeAreaInsets.trailing
        safeLeading = geometry.safeAreaInsets.leading
    }

    private var contentWidth: CGFloat { min(width, 560) }
    private var compactHeight: Bool { height < 700 }
    private var narrowWidth: Bool { width < 360 }

    var backgroundGlowDiameter: CGFloat {
        min(480, max(280, width * 1.05))
    }

    var backgroundGlowOffsetX: CGFloat { width * 0.48 }

    var backgroundGlowOffsetY: CGFloat { -max(80, width * 0.22) }

    var topChromeInset: CGFloat {
        max(safeTop, 56) + 12
    }

    var trailingChromeInset: CGFloat {
        max(safeTrailing, 20)
    }

    var leadingChromeInset: CGFloat {
        max(safeLeading, 20)
    }
}

#Preview {
    let settings = SettingsStore()
    let repo = ConvexPrayerRepository(service: ConvexService())
    let scheduler = PrayerNotificationScheduler(repository: repo)
    let homeVM = HomeViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    let settingsVM = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    return NavigationStack {
        MasjidlyRootView(homeViewModel: homeVM)
            .environment(settings)
            .environment(settingsVM)
    }
}
