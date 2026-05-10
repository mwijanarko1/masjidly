import SwiftUI

private func homeLS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(OnboardingFlowController.self) private var onboarding
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
                        onSelectPrayer: { selectedPrayerIndex = $0 },
                        highlightedShortcutIndex: highlightedPrayerShortcutIndex,
                        onShortcutTapped: { onboarding.handlePrayerShortcutTap(index: $0) }
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
                        calendarButton
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
            await settingsViewModel.load()
            onboarding.startIfNeeded()
            await model.resyncNotificationsIfNeeded()
        }
        .onAppear {
            Task { await model.applySelectionFromSettings() }
        }
        .onChange(of: settings.notifications.masterEnabled) { _, _ in
            Task { await model.resyncNotificationsIfNeeded() }
        }
        .onChange(of: settings.appLanguage) { _, _ in
            Task {
                await model.resyncNotificationsIfNeeded()
                await model.refreshWidgetSnapshotForCurrentMosque()
            }
        }
        .onChange(of: settings.uses24HourTime) { _, _ in
            Task { await model.refreshWidgetSnapshotForCurrentMosque() }
        }
        .onChange(of: settings.selectedMosqueId) { _, _ in
            Task { await model.applySelectionFromSettings() }
        }
        .onChange(of: settings.selectedMosqueSlug) { _, _ in
            Task { await model.applySelectionFromSettings() }
        }
        .fullScreenCover(isPresented: $showingTimetable) {
            if let monthData = model.monthData, let mosque = model.selectedMosque {
                TimetableView(
                    initialMonthData: monthData,
                    mosqueName: mosque.name,
                    mosqueSlug: mosque.slug,
                    timeTheme: currentTheme,
                    model: model,
                    onDismiss: {
                        onboarding.handleTimetableClosed()
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(
                model: settingsViewModel,
                timeTheme: currentTheme,
                onDismiss: {
                    onboarding.handleSettingsClosed()
                }
            )
                .environment(settings)
        }
        .overlay {
            onboardingOverlay
        }
    }

    @ViewBuilder
    private func backgroundLayer(metrics: HomeViewportMetrics) -> some View {
        let theme = currentActiveTheme(d: model.displayedPrayerTimes)
        let sky = theme.sky
        
        ZStack {
            // 1. Base Atmospheric Sky
            LinearGradient(
                gradient: Gradient(colors: sky.baseColors),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 2. Horizon Glow (Cinematic Lighting)
            if let glow = sky.glowColor {
                RadialGradient(
                    colors: [glow.opacity(0.6), glow.opacity(0.3), .clear],
                    center: UnitPoint(x: 0.5, y: 0.82),
                    startRadius: 0,
                    endRadius: metrics.height * 0.7
                )
                .blendMode(.screen)
            }
            
            // 3. Subtle Light Wash (Top-down soft lighting)
            LinearGradient(
                colors: [Color.white.opacity(0.05), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
        }
        .animation(.easeInOut(duration: 0.8), value: selectedPrayerIndex)
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
            onboarding.handleSettingsOpened()
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(HomeDesign.Typography.app(size: 20, weight: .light))
                .foregroundColor(currentTheme.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .onboardingHighlight(onboarding.currentStep == .openSettings)
        .accessibilityLabel(Text(homeLS("accessibility.settings", locale: locale)))
    }

    private var calendarButton: some View {
        Button {
            onboarding.handleTimetableOpened()
            showingTimetable = true
        } label: {
            Image(systemName: "calendar")
                .font(HomeDesign.Typography.app(size: 20, weight: .light))
                .foregroundColor(currentTheme.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .onboardingHighlight(onboarding.currentStep == .openTimetable)
        .accessibilityLabel(Text(homeLS("accessibility.timetable", locale: locale)))
    }

    @ViewBuilder
    private var onboardingOverlay: some View {
        switch onboarding.currentStep {
        case .chooseMosque:
            MosqueSelectionOnboardingView(
                mosques: model.mosques,
                timeTheme: currentTheme,
                selectedMosqueId: Binding(
                    get: { onboarding.selectedMosqueId },
                    set: { onboarding.selectedMosqueId = $0 }
                ),
                onContinue: { mosque in
                    Task { await onboarding.selectMosque(mosque) }
                }
            )
        case .prayerShortcut(let index):
            OnboardingCoachMarkView(
                title: "Try the prayer shortcuts",
                message: "Tap \(shortcutLetter(for: index)) to view that prayer time.",
                timeTheme: currentTheme,
                variant: .aboveShortcutRow
            )
            .allowsHitTesting(false)
        case .openTimetable:
            OnboardingCoachMarkView(
                title: "Open the timetable",
                message: "Tap the calendar button (top-left) to see the full timetable.",
                timeTheme: currentTheme,
                variant: .belowTopChrome
            )
            .allowsHitTesting(false)
        case .closeTimetable:
            EmptyView()
        case .openSettings:
            OnboardingCoachMarkView(
                title: "Open Settings",
                message: "Tap the settings button (top-right) to choose preferences.",
                timeTheme: currentTheme,
                variant: .belowTopChrome
            )
            .allowsHitTesting(false)
        case .closeSettings:
            EmptyView()
        case .notifications:
            OnboardingNotificationSetupView(
                timeTheme: currentTheme,
                draft: Binding(
                    get: { onboarding.notificationDraft },
                    set: { onboarding.notificationDraft = $0 }
                ),
                isSaving: onboarding.isCompletingNotifications,
                onContinue: {
                    Task { await onboarding.completeNotificationSetup() }
                }
            )
        case nil:
            EmptyView()
        }
    }

    private var highlightedPrayerShortcutIndex: Int? {
        guard case .prayerShortcut(let index) = onboarding.currentStep else { return nil }
        return index
    }

    private func shortcutLetter(for index: Int) -> String {
        let letters = ["F", "S", "D", "A", "M", "I"]
        guard index >= 0, index < letters.count else { return "?" }
        return letters[index]
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
            await model.refreshWidgetSnapshotForCurrentMosque()
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
    let onboarding = OnboardingFlowController(
        settings: settings,
        homeViewModel: homeVM,
        settingsViewModel: settingsVM,
        notificationScheduler: scheduler
    )
    return NavigationStack {
        MasjidlyRootView(homeViewModel: homeVM)
            .environment(settings)
            .environment(settingsVM)
            .environment(onboarding)
    }
}
