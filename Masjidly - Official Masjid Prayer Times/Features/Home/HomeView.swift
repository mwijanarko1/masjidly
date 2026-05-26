import SwiftUI
import CoreLocation
import UserNotifications

private func homeLS(_ key: String, locale: Locale) -> String {
    LocaleBundle.string(forKey: key, locale: locale)
}

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(OnboardingFlowController.self) private var onboarding
    @Environment(AppReviewPromptCoordinator.self) private var reviewPrompt
    @Environment(\.scenePhase) private var scenePhase
    /// Derived from the observable store so language changes re-localize the entire home immediately.
    private var locale: Locale { settings.resolvedLocale }

    @State private var showingSettings = false
    @State private var showingTimetable = false
    @State private var showingWhatsNew = false
    @State private var showingNotificationRecovery = false
    @State private var notificationRecoveryIsBugRecovery = false
    @State private var qiblaDirectionProvider = QiblaDirectionProvider()

    private var dynamicTheme: HomeDesign.TimeTheme {
        HomeDesign.TimeTheme.homeHeroTheme(
            displayedPrayerTimes: model.displayedPrayerTimes,
            selectedPrayerIndex: model.selectedPrayerIndex
        )
    }

    private var currentTheme: HomeDesign.TimeTheme {
        settings.resolvedTheme(dynamicTheme: dynamicTheme)
    }

    var body: some View {
        homeChromeStack
    }

    private var homeChromeStack: some View {
        homePresentationChrome
    }

    private var homePresentationChrome: some View {
        AnyView(homeNotificationChrome)
            .fullScreenCover(isPresented: $showingTimetable, content: timetableFullScreenView)
            .fullScreenCover(isPresented: $showingSettings, content: settingsFullScreenView)
            .enjoymentReviewAlert(
                title: homeLS("review.enjoyment.title", locale: locale),
                message: homeLS("review.enjoyment.message", locale: locale),
                loveTitle: homeLS("review.enjoyment.love_it", locale: locale),
                notReallyTitle: homeLS("review.enjoyment.not_really", locale: locale),
                isPresented: Binding(
                    get: { reviewPrompt.showEnjoymentPrompt },
                    set: { reviewPrompt.showEnjoymentPrompt = $0 }
                ),
                onLoveIt: { reviewPrompt.userConfirmedEnjoymentPositive() },
                onNotReally: { reviewPrompt.userConfirmedEnjoymentNegative() }
            )
            .notificationRecoveryAlert(
                isBugRecovery: $notificationRecoveryIsBugRecovery,
                isPresented: $showingNotificationRecovery,
                onEnable: { handleNotificationRecoveryEnable() },
                onDismiss: { showingNotificationRecovery = false }
            )
    }

    private var homeNotificationChrome: some View {
        AnyView(homeStateChangeChrome)
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyOpenTimetable)) { _ in
                showingSettings = false
                showingTimetable = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyOpenSettingsMosque)) { _ in
                showingTimetable = false
                showingSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyFocusHomeTimes)) { _ in
                showingTimetable = false
                showingSettings = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyShowWhatsNew)) { _ in
                showingTimetable = false
                showingSettings = false
                showingWhatsNew = true
            }
    }

    private var homeStateChangeChrome: some View {
        AnyView(homeLifecycleChrome)
            .onChange(of: settings.uses24HourTime) { _, _ in
                Task { await model.refreshWidgetSnapshotForCurrentMosque() }
            }
            .onChange(of: settings.selectedMosqueId) { _, _ in
                Task { await model.applySelectionFromSettings() }
            }
            .onChange(of: settings.selectedMosqueSlug) { _, _ in
                Task { await model.applySelectionFromSettings() }
            }
            .onChange(of: model.selectedMosque) { _, newValue in
                qiblaDirectionProvider.updateFallbackMosque(newValue)
            }
            .onChange(of: qiblaDirectionProvider.authorizationStatus) { _, newStatus in
                handleQiblaAuthorizationStatusChange(newStatus)
            }
    }

    private var homeLifecycleChrome: some View {
        homeContent
            .task {
                await model.load()
                await settingsViewModel.load()
                onboarding.startIfNeeded()
                await model.resyncNotificationsIfNeeded()
                checkWhatsNew()
                checkNotificationRecovery()
            }
            .onAppear {
                Task { await model.applySelectionFromSettings() }
                reviewPrompt.recordLaunchIfNeeded()
                reviewPrompt.considerPresentingEnjoymentPromptIfEligible(
                    isOnboardingBlocking: enjoymentReviewFlowBlocked
                )
            }
            .onChange(of: settings.hasCompletedOnboarding) { _, completed in
                guard completed else { return }
                reviewPrompt.recordLaunchIfNeeded()
                reviewPrompt.considerPresentingEnjoymentPromptIfEligible(
                    isOnboardingBlocking: enjoymentReviewFlowBlocked
                )
                checkWhatsNew()
                checkNotificationRecovery()
            }
            .onChange(of: onboarding.isActive) { _, isActive in
                guard !isActive else { return }
                reviewPrompt.considerPresentingEnjoymentPromptIfEligible(
                    isOnboardingBlocking: enjoymentReviewFlowBlocked
                )
            }
            .onChange(of: settings.notifications.masterEnabled) { _, _ in
                Task { await model.resyncNotificationsIfNeeded() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await model.refreshFromNetworkIfStale()
                    await model.resyncNotificationsIfNeeded()
                }
                reviewPrompt.considerPresentingEnjoymentPromptIfEligible(
                    isOnboardingBlocking: enjoymentReviewFlowBlocked
                )
            }
    }

    private var homeContent: some View {
        GeometryReader { geo in
            let metrics = HomeViewportMetrics(geometry: geo)
            homeMainZStack(metrics: metrics)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .accessibilityIdentifier("tabHome")
        .overlay {
            if showingWhatsNew {
                whatsNewOverlay
            }
        }
    }

    private func homeMainZStack(metrics: HomeViewportMetrics) -> AnyView {
        AnyView(
            ZStack(alignment: .bottom) {
                backgroundLayer(metrics: metrics)

                if let d = model.displayedPrayerTimes {
                    homePrayerPage(for: d)
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

                onboardingOverlay
            }
        )
    }

    private func homePrayerPage(for daily: DailyPrayerTimes) -> AnyView {
        let isFriday = isFridayInSheffield(Date())
        let jummahTime = model.iqamahTimes?.jummah
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? daily.dhuhr
        let prayers: [(canonical: String, time: String, theme: HomeDesign.TimeTheme)] = [
            ("Fajr", daily.fajr, .fajr),
            ("Sunrise", daily.sunrise, .sunrise),
            (isFriday ? "Jummah" : "Dhuhr", isFriday ? jummahTime : daily.dhuhr, .dhuhr),
            ("Asr", daily.asr, .asr),
            ("Maghrib", daily.maghrib, .maghrib),
            ("Isha", daily.isha, .isha)
        ]
        let slug = model.selectedMosque?.slug ?? ""
        let prayer = prayers[model.selectedPrayerIndex]
        let heroParts = PrayerTimesEngine.formatPrayerTimeHeroParts(
            prayer.time,
            uses24Hour: settings.uses24HourTime,
            locale: locale
        )
        let prayerTimeDisplay: String = {
            if let meridiem = heroParts.meridiem, !meridiem.isEmpty {
                return "\(heroParts.clock)\u{2009}\(meridiem)"
            }
            return heroParts.clock
        }()
        let iqSubtitle = iqamahSubtitleLine(
            prayerName: prayer.canonical,
            adhanRaw: prayer.time,
            daily: daily,
            iq: model.iqamahTimes,
            mosqueSlug: slug
        )
        let displayName = PrayerLocalization.displayName(canonicalEnglish: prayer.canonical, locale: locale)
        let labels = prayers.map { PrayerLocalization.displayName(canonicalEnglish: $0.canonical, locale: locale) }

        return AnyView(
            MinimalistPrayerPage(
                prayerName: displayName,
                prayerTime: prayerTimeDisplay,
                iqamahTime: iqSubtitle,
                theme: currentTheme,
                showQiblaCompass: !settings.hideQiblaCompass,
                qiblaRotationDegrees: qiblaDirectionProvider.displayedRotationDegrees,
                qiblaOnboardingHighlighted: onboarding.currentStep == .qibla || onboarding.currentStep == .qiblaCountdown,
                mosqueSlug: slug,
                dailyPrayerTimes: daily,
                dailyIqamahTimes: model.iqamahTimes,
                prayerLabels: labels,
                selectedIndex: model.selectedPrayerIndex,
                totalCount: prayers.count,
                onSelectPrayer: { model.selectedPrayerIndex = $0 },
                highlightedShortcutIndex: highlightedPrayerShortcutIndex,
                onShortcutTapped: { onboarding.handlePrayerShortcutTap(index: $0) }
            )
            .onAppear {
                let deferAuth = !settings.hasCompletedOnboarding || settings.hideQiblaCompass
                if settings.hideQiblaCompass {
                    qiblaDirectionProvider.stop()
                } else {
                    qiblaDirectionProvider.start(fallbackMosque: model.selectedMosque, deferAuthorization: deferAuth)
                }
                if let nextName = model.nextCountdown?.nextName {
                    if let index = prayers.firstIndex(where: { $0.canonical == nextName }) {
                        model.selectedPrayerIndex = index
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var whatsNewOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Full-bleed backdrop (dimming + adaptive atmospheric gradient)
                ZStack {
                    Color.black.opacity(0.4)
                    
                    LinearGradient(
                        colors: currentTheme.sky.baseColors.map { $0.opacity(0.55) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    if let glow = currentTheme.sky.glowColor {
                        RadialGradient(
                            colors: [glow.opacity(0.4), glow.opacity(0.15), .clear],
                            center: UnitPoint(x: 0.5, y: 0.82),
                            startRadius: 0,
                            endRadius: 500
                        )
                        .blendMode(.screen)
                    }
                }
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWhatsNew()
                }

                WhatsNewModalView(
                    version: WhatsNew.currentVersion,
                    items: WhatsNew.localizedUpdates(locale: locale),
                    timeTheme: currentTheme,
                    locale: locale,
                    onDismiss: {
                        dismissWhatsNew()
                    }
                )
                .padding(.horizontal, 24)
                .frame(maxWidth: 380)
                .frame(maxHeight: min(580, geo.size.height - 80))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }

    private func dismissWhatsNew() {
        settings.lastSeenBuildVersion = WhatsNew.fullVersionString
        withAnimation(.easeInOut(duration: 0.18)) {
            showingWhatsNew = false
        }
    }

    @ViewBuilder
    private var whatsNewSheet: some View {
        WhatsNewModalView(
            version: WhatsNew.currentVersion,
            items: WhatsNew.localizedUpdates(locale: locale),
            timeTheme: currentTheme,
            locale: locale
        )
        .onDisappear {
            settings.lastSeenBuildVersion = WhatsNew.fullVersionString
        }
    }

    private func timetableFullScreenView() -> AnyView {
        AnyView(timetableFullScreen)
    }

    private func settingsFullScreenView() -> AnyView {
        AnyView(settingsFullScreen)
    }

    @ViewBuilder
    private var timetableFullScreen: some View {
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
            .environment(onboarding)
            .environment(\.locale, settings.resolvedLocale)
            .environment(\.layoutDirection, settings.appLanguage.layoutDirection)
            .environment(\.appFontName, settings.appFontName)
        }
    }

    @ViewBuilder
    private var settingsFullScreen: some View {
        SettingsView(
            model: settingsViewModel,
            timeTheme: currentTheme,
            onDismiss: {
                onboarding.handleSettingsClosed()
            }
        )
        .environment(onboarding)
        .environment(settings)
        .environment(reviewPrompt)
        .environment(\.locale, settings.resolvedLocale)
        .environment(\.layoutDirection, settings.appLanguage.layoutDirection)
        .environment(\.appFontName, settings.appFontName)
    }

    private var enjoymentReviewFlowBlocked: Bool {
        onboarding.isActive || !settings.hasCompletedOnboarding
    }

    @ViewBuilder
    private func backgroundLayer(metrics: HomeViewportMetrics) -> some View {
        let theme = currentTheme
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
        .animation(.easeInOut(duration: 0.8), value: model.selectedPrayerIndex)
        .animation(.easeInOut(duration: 0.8), value: settings.fixedTheme)
        .animation(.easeInOut(duration: 0.8), value: settings.themeMode)
        .ignoresSafeArea()
    }

    private var settingsButton: some View {
        Button {
            onboarding.handleSettingsOpened()
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .appFont(size: 20, weight: .light)
                .foregroundColor(currentTheme.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .onboardingHighlight(onboarding.currentStep == .openSettings, timeTheme: currentTheme)
        .accessibilityLabel(Text(homeLS("accessibility.settings", locale: locale)))
    }

    private var calendarButton: some View {
        Button {
            onboarding.handleTimetableOpened()
            showingTimetable = true
        } label: {
            Image(systemName: "calendar")
                .appFont(size: 20, weight: .light)
                .foregroundColor(currentTheme.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .onboardingHighlight(onboarding.currentStep == .openTimetable, timeTheme: currentTheme)
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
                title: homeLS("onboarding.shortcut.title", locale: locale),
                message: String(
                    format: homeLS("onboarding.shortcut.message_format", locale: locale),
                    locale: locale,
                    arguments: [shortcutLetter(for: index)]
                ),
                timeTheme: currentTheme,
                variant: .aboveShortcutRow
            )
            .allowsHitTesting(false)
        case .qiblaCountdown:
            OnboardingCoachMarkView(
                title: homeLS("onboarding.qibla_countdown.title", locale: locale),
                message: homeLS("onboarding.qibla_countdown.message", locale: locale),
                timeTheme: currentTheme,
                variant: .belowQiblaIconLower,
                primaryButtonTitle: homeLS("onboarding.continue", locale: locale),
                onPrimaryButton: {
                    onboarding.completeQiblaCountdownStep()
                },
                primaryButtonAccessibilityIdentifier: "Onboarding.QiblaCountdownContinue",
                blocksBackgroundInteractions: false
            )
        case .qibla:
            OnboardingCoachMarkView(
                title: homeLS("onboarding.qibla.title", locale: locale),
                message: homeLS("onboarding.qibla.message", locale: locale),
                timeTheme: currentTheme,
                variant: .belowQiblaIconLower,
                primaryButtonTitle: homeLS("onboarding.qibla.allow_location", locale: locale),
                onPrimaryButton: {
                    qiblaDirectionProvider.requestWhenInUseAuthorizationIfNeeded()
                    onboarding.completeQiblaOnboardingAllowingLocationRequest()
                },
                primaryButtonAccessibilityIdentifier: "Onboarding.QiblaAllow",
                secondaryButtonTitle: homeLS("onboarding.qibla.later", locale: locale),
                onSecondaryButton: {
                    onboarding.completeQiblaOnboardingDeferringLocation()
                },
                secondaryButtonAccessibilityIdentifier: "Onboarding.QiblaLater"
            )
        case .openTimetable:
            OnboardingCoachMarkView(
                title: homeLS("onboarding.timetable.title", locale: locale),
                message: homeLS("onboarding.timetable.message", locale: locale),
                timeTheme: currentTheme,
                variant: .belowTopChrome
            )
            .allowsHitTesting(false)
        case .exploreTimetable:
            EmptyView()
        case .closeTimetable:
            EmptyView()
        case .openSettings:
            OnboardingCoachMarkView(
                title: homeLS("onboarding.settings.title", locale: locale),
                message: homeLS("onboarding.settings.message", locale: locale),
                timeTheme: currentTheme,
                variant: .belowTopChrome
            )
            .allowsHitTesting(false)
        case .exploreSettings:
            EmptyView()
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
                .appFont(size: 13, weight: .semibold)
                .kerning(1.0)
                .foregroundColor(currentTheme.textColor.opacity(0.6))
            
            Text(currentHijriDateString.uppercased())
                .appFont(size: 10, weight: .medium)
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

    private func checkNotificationRecovery() {
        guard settings.hasCompletedOnboarding else { return }
        guard !showingWhatsNew else { return }

        let n = settings.notifications
        let bugRecoveryCondition = !n.masterEnabled && (n.adhanEnabled || n.iqamahEnabled)

        if bugRecoveryCondition {
            notificationRecoveryIsBugRecovery = true
            showingNotificationRecovery = true
            return
        }

        guard n.masterEnabled else { return }

        // Check OS-level permission asynchronously
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .denied:
                await MainActor.run {
                    notificationRecoveryIsBugRecovery = false
                    showingNotificationRecovery = true
                }
            default:
                break
            }
        }
    }

    private func handleNotificationRecoveryEnable() {
        Task {
            if notificationRecoveryIsBugRecovery {
                // Fix masterEnabled from the bug so resync works
                var n = settings.notifications
                n.masterEnabled = n.adhanEnabled || n.iqamahEnabled ||
                                  n.preAdhanReminderMinutes != nil ||
                                  n.preIqamahReminderMinutes != nil
                settings.notifications = n
            }

            // Request OS permission and reschedule via the model
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if granted {
                    await model.resyncNotificationsIfNeeded()
                }
            } catch {
                // Silently handle the error
            }

            showingNotificationRecovery = false
        }
    }

    private func checkWhatsNew() {
        let currentBuild = WhatsNew.fullVersionString
        guard settings.lastSeenBuildVersion != currentBuild else { return }
        guard settings.hasCompletedOnboarding else { return }
        showingWhatsNew = true
    }

    private func handleQiblaAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        let isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
        if isAuthorized {
            settings.hideQiblaCompass = false
        }
    }

    private func selectMosque(_ mosque: Mosque) {
        model.selectedMosque = mosque
        settings.selectedMosqueId = mosque.id
        settings.selectedMosqueSlug = mosque.slug
        settings.selectedCityGroupingKey = mosque.cityGroupingKey
        Task {
            try? await model.refreshPrayerPayload(for: mosque)
            await model.refreshWidgetSnapshotForCurrentMosque()
            await model.resyncNotificationsIfNeeded()
        }
    }

    private func formatTime(_ t: String) -> String {
        PrayerTimesEngine.formatPrayerTimeForDisplay(t, uses24Hour: settings.uses24HourTime, locale: locale)
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
            if isFridayInSheffield(now) { return nil }
            return PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: daily.dhuhr, iqamahTimes: iq)
        case "Jummah":
            return nil
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

private extension View {
    func notificationRecoveryAlert(
        isBugRecovery: Binding<Bool>,
        isPresented: Binding<Bool>,
        onEnable: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        alert("Notifications", isPresented: isPresented) {
            if isBugRecovery.wrappedValue {
                Button("Enable Notifications", action: onEnable)
                Button("Not Now", role: .cancel, action: onDismiss)
            } else {
                Button("Open Settings", action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                })
                Button("Not Now", role: .cancel, action: onDismiss)
            }
        } message: {
            if isBugRecovery.wrappedValue {
                Text("During setup, prayer notifications weren\'t saved correctly. Enable them now to receive adhan and iqamah alerts.")
            } else {
                Text("Prayer notifications are enabled in Masjidly but blocked by your device settings. Open Settings to allow notifications.")
            }
        }
    }

    func enjoymentReviewAlert(
        title: String,
        message: String,
        loveTitle: String,
        notReallyTitle: String,
        isPresented: Binding<Bool>,
        onLoveIt: @escaping () -> Void,
        onNotReally: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(loveTitle, action: onLoveIt)
            Button(notReallyTitle, role: .cancel, action: onNotReally)
        } message: {
            Text(message)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let masjidlyShowWhatsNew = Notification.Name("masjidly.show.whatsnew")
    static let masjidlyShowUpdatePrompt = Notification.Name("masjidly.show.updatePrompt")
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
    let cache = PrayerTimesDiskCache()
    let homeVM = HomeViewModel(repository: repo, settings: settings, notificationScheduler: scheduler, diskCache: cache)
    let settingsVM = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler, diskCache: cache)
    let onboarding = OnboardingFlowController(
        settings: settings,
        homeViewModel: homeVM,
        settingsViewModel: settingsVM,
        notificationScheduler: scheduler
    )
    let review = AppReviewPromptCoordinator(settings: settings)
    return NavigationStack {
        MasjidlyRootView(homeViewModel: homeVM)
            .environment(settings)
            .environment(settingsVM)
            .environment(onboarding)
            .environment(review)
    }
}

