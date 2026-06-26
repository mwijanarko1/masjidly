import SwiftUI
import CoreLocation

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
    @Environment(\.openURL) private var openURL
    /// Derived from the observable store so language changes re-localize the entire home immediately.
    private var locale: Locale { settings.resolvedLocale }

    @State private var showingSettings = false
    @State private var showingTimetable = false
    @State private var showingWhatsNew = false
    @State private var showingDatePicker = false
    @State private var datePickerSelection = Date()
    @State private var showUpdateAlert = false
    @State private var showReviewFeedbackPrompt = false
    @State private var pendingRelease: MasjidlyRelease?
    @State private var hasCheckedForUpdate = false
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

    private var currentAppearance: HomeDesign.ResolvedTheme {
        settings.resolvedAppearance(for: currentTheme)
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
            .sheet(isPresented: $showingDatePicker, content: datePickerSheet)
            .enjoymentReviewAlert(
                title: homeLS("review.enjoyment.title", locale: locale),
                message: homeLS("review.enjoyment.message", locale: locale),
                loveTitle: homeLS("review.enjoyment.love_it", locale: locale),
                notReallyTitle: homeLS("review.enjoyment.not_really", locale: locale),
                isPresented: Binding(
                    get: { reviewPrompt.showEnjoymentPrompt },
                    set: { reviewPrompt.showEnjoymentPrompt = $0 }
                ),
                onLoveIt: {
                    reviewPrompt.userConfirmedEnjoymentPositive()
                    presentUpdateAlertIfReady()
                },
                onNotReally: {
                    reviewPrompt.userConfirmedEnjoymentNegative()
                    showReviewFeedbackPrompt = true
                }
            )
            .alert(
                reviewFeedbackTitle,
                isPresented: $showReviewFeedbackPrompt
            ) {
                Button(reviewFeedbackLaterLabel, role: .cancel) {
                    HapticFeedback.buttonTap()
                    showReviewFeedbackPrompt = false
                    presentUpdateAlertIfReady()
                }
                Button(reviewFeedbackSendLabel) {
                    HapticFeedback.buttonTap()
                    openReviewFeedbackEmail()
                    showReviewFeedbackPrompt = false
                    presentUpdateAlertIfReady()
                }
            } message: {
                Text(reviewFeedbackMessage)
            }
            .alert(
                updateAlertTitle,
                isPresented: $showUpdateAlert,
                presenting: pendingRelease
            ) { _ in
                Button(updateLaterLabel) {
                    HapticFeedback.buttonTap()
                    showUpdateAlert = false
                }
                Button(updateNowLabel) {
                    HapticFeedback.buttonTap()
                    AppUpdateChecker.openAppStore()
                    showUpdateAlert = false
                }
            } message: { _ in
                Text(updateMessage)
            }
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
            .onReceive(NotificationCenter.default.publisher(for: .masjidlyShowUpdatePrompt)) { _ in
                showingTimetable = false
                showingSettings = false
                presentTestUpdateAlert()
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
                checkForUpdateIfNeeded()
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
                checkForUpdateIfNeeded()
                presentUpdateAlertIfReady()
            }
            .onChange(of: onboarding.isActive) { _, isActive in
                guard !isActive else { return }
                reviewPrompt.considerPresentingEnjoymentPromptIfEligible(
                    isOnboardingBlocking: enjoymentReviewFlowBlocked
                )
                presentUpdateAlertIfReady()
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
                } else if model.isLoadingDisplayedDate || model.loadState == .loading || model.loadState == .idle {
                    ProgressView()
                        .tint(currentAppearance.textColor)
                } else if shouldShowMissingCurrentMonthTimes {
                    missingCurrentMonthTimesView(metrics: metrics)
                } else {
                    loadErrorRecoveryView(metrics: metrics)
                }

                VStack(spacing: 0) {
                    ZStack {
                        HStack(alignment: .center) {
                            calendarButton
                                .padding(.leading, metrics.leadingChromeInset)

                            Spacer(minLength: 0)

                            settingsButton
                                .padding(.trailing, metrics.trailingChromeInset)
                        }

                        dateDisplay
                    }
                    .padding(.top, metrics.topChromeInset)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                onboardingOverlay
            }
            .contentShape(Rectangle())
            .simultaneousGesture(homeDaySwipeGesture)
        )
    }

    private var homeDaySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 56 else { return }
                if horizontal > 0 {
                    model.goToPreviousDay()
                } else {
                    model.goToNextDay()
                }
            }
    }

    private var shouldShowMissingCurrentMonthTimes: Bool {
        model.selectedMosque != nil
            && !model.isLoadingDisplayedDate
            && (model.loadState == .loaded || model.loadState == .empty)
    }

    private func loadErrorRecoveryView(metrics: HomeViewportMetrics) -> some View {
        VStack(spacing: 18) {
            Button {
                HapticFeedback.buttonTap()
                Task {
                    if model.selectedMosque != nil {
                        await model.manualRefresh()
                    } else {
                        await model.load()
                    }
                }
            } label: {
                Text(homeLS("action.retry", locale: locale))
                    .appFont(size: 16, weight: .semibold)
                    .foregroundStyle(currentAppearance.usesLightForeground ? Color.black : Color.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(currentAppearance.textColor.opacity(0.92)))
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Home.LoadError.RetryButton")
        }
        .padding(.horizontal, 32)
        .padding(.top, metrics.topChromeInset + 56)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func missingCurrentMonthTimesView(metrics: HomeViewportMetrics) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.exclamationmark")
                .appFont(size: 44, weight: .light)
                .foregroundStyle(currentAppearance.textColor.opacity(0.9))

            Text(homeLS("home.current_month_times_missing", locale: locale))
                .appFont(size: 22, weight: .semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(currentAppearance.textColor)

            Text(currentMissingMonthTitle)
                .appFont(size: 15, weight: .regular)
                .foregroundStyle(currentAppearance.textColor.opacity(0.72))

            if model.hasAvailablePrayerTimesFallback {
                Button {
                    model.goToLastAvailablePrayerDate()
                } label: {
                    Text(homeLS("home.go_to_available_times_button", locale: locale))
                        .appFont(size: 16, weight: .semibold)
                        .foregroundStyle(currentAppearance.usesLightForeground ? Color.black : Color.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(currentAppearance.textColor.opacity(0.92)))
                }
                .buttonStyle(.hapticPlain)
                .accessibilityIdentifier("Home.MissingTimes.AvailableTimesButton")
            }

            Button {
                openMissingTimesEmail()
            } label: {
                Text(homeLS("home.request_times_button", locale: locale))
                    .appFont(size: 15, weight: .semibold)
                    .foregroundStyle(currentAppearance.textColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().strokeBorder(currentAppearance.textColor.opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Home.MissingTimes.EmailButton")
        }
        .padding(.horizontal, 32)
        .padding(.top, metrics.topChromeInset + 56)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var currentMissingMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = PrayerTimesEngine.sheffieldTimeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: model.displayedDate)
    }

    private func openMissingTimesEmail() {
        let context = MasjidlySupportMail.currentContext(mosqueName: model.selectedMosque?.name)
        guard let url = MasjidlySupportMail.missingPrayerTimesURL(
            locale: locale,
            context: context,
            monthDisplay: currentMissingMonthTitle
        ) else { return }
        openURL(url)
    }

    private func homePrayerPage(for daily: DailyPrayerTimes) -> AnyView {
        let isFriday = isFridayInSheffield(model.displayedDate)
        let jummahTime = displayJummahTime(raw: model.iqamahTimes?.jummah, fallbackDhuhr: daily.dhuhr)
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
        let iqSubtitle: String? = {
            switch prayer.canonical {
            case "Sunrise":
                return duhaSubtitleLine(daily: daily)
            case "Jummah":
                guard settings.showIqamahTime else { return nil }
                return secondJummahSubtitleLine(raw: model.iqamahTimes?.jummah)
            default:
                guard settings.showIqamahTime else { return nil }
                return iqamahSubtitleLine(
                    prayerName: prayer.canonical,
                    adhanRaw: prayer.time,
                    daily: daily,
                    iq: model.iqamahTimes,
                    mosqueSlug: slug
                )
            }
        }()
        let displayName = PrayerLocalization.displayName(canonicalEnglish: prayer.canonical, locale: locale)
        let labels = prayers.map { PrayerLocalization.displayName(canonicalEnglish: $0.canonical, locale: locale) }

        return AnyView(
            MinimalistPrayerPage(
                prayerName: displayName,
                prayerTime: prayerTimeDisplay,
                iqamahTime: iqSubtitle,
                appearance: currentAppearance,
                showQiblaCompass: !settings.hideQiblaCompass,
                qiblaRotationDegrees: qiblaDirectionProvider.displayedRotationDegrees,
                qiblaOnboardingHighlighted: onboarding.currentStep == .qibla || onboarding.currentStep == .qiblaCountdown,
                mosqueSlug: slug,
                dailyPrayerTimes: daily,
                dailyIqamahTimes: model.iqamahTimes,
                asrIqamahPreference: settings.asrIqamahPreference,
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
                } else if isTodayInSheffield(model.displayedDate), let ishaIndex = prayers.firstIndex(where: { $0.canonical == "Isha" }) {
                    model.selectedPrayerIndex = ishaIndex
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
                    
                    let whatsNewSky = currentAppearance.sky
                    LinearGradient(
                        colors: whatsNewSky.baseColors.map { $0.opacity(0.55) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    if let glow = whatsNewSky.glowColor {
                        RadialGradient(
                            colors: [glow.opacity(0.4 * whatsNewSky.glowBaseAlpha), glow.opacity(0.15 * whatsNewSky.glowBaseAlpha), .clear],
                            center: UnitPoint(x: 0.5, y: 0.82),
                            startRadius: 0,
                            endRadius: 500
                        )
                        .blendMode(.screen)
                    }
                }
                .ignoresSafeArea()
                .onTapGesture {
                    HapticFeedback.buttonTap()
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
        presentUpdateAlertIfReady()
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
        let sky = currentAppearance.sky

        AtmosphericSkyBackground(sky: sky, height: metrics.height)
            .animation(.easeInOut(duration: 0.8), value: model.selectedPrayerIndex)
            .animation(.easeInOut(duration: 0.8), value: settings.fixedTheme)
            .animation(.easeInOut(duration: 0.8), value: settings.themeMode)
            .animation(.easeInOut(duration: 0.8), value: settings.skyGradientSet(for: currentTheme).rawValue)
            .animation(.easeInOut(duration: 0.8), value: settings.customGradientColors(for: currentTheme).topHex)
            .animation(.easeInOut(duration: 0.8), value: settings.customGradientColors(for: currentTheme).bottomHex)
            .ignoresSafeArea()
    }

    private var settingsButton: some View {
        Button {
            onboarding.handleSettingsOpened()
            showingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .appFont(size: 20, weight: .light)
                .foregroundColor(currentAppearance.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.hapticPlain)
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
                .foregroundColor(currentAppearance.textColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.hapticPlain)
        .onboardingHighlight(onboarding.currentStep == .openTimetable, timeTheme: currentTheme)
        .accessibilityLabel(Text(homeLS("accessibility.timetable", locale: locale)))
    }

    @ViewBuilder private var onboardingOverlay: some View {
        switch onboarding.currentStep {
        case .chooseLanguage:
            LanguageSelectionOnboardingView(
                timeTheme: currentTheme,
                selectedLanguage: Binding(
                    get: { onboarding.selectedLanguage },
                    set: { onboarding.selectedLanguage = $0 }
                ),
                onContinue: { language in
                    onboarding.selectLanguage(language)
                }
            )
        case .chooseMosque:
            MosqueSelectionOnboardingView(
                mosques: model.mosques,
                timeTheme: currentTheme,
                selectedMosqueId: Binding(
                    get: { onboarding.selectedMosqueId },
                    set: { onboarding.selectedMosqueId = $0 }
                ),
                isContinuing: onboarding.isSelectingMosque,
                onContinue: { mosque in
                    Task { await onboarding.selectMosque(mosque) }
                }
            )
        case .prayerShortcut:
            ZStack(alignment: .bottom) {
                OnboardingCoachMarkView(
                    title: homeLS("onboarding.shortcut.title", locale: locale),
                    message: homeLS("onboarding.shortcut.message_format", locale: locale),
                    timeTheme: currentTheme,
                    variant: .aboveShortcutRow
                )
                .allowsHitTesting(false)

                Button {
                    onboarding.skipToTutorialEnd()
                } label: {
                    Text("Skip tutorial")
                        .appFont(size: 15, weight: .semibold)
                        .foregroundColor(currentAppearance.textColor.opacity(0.7))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(
                            Capsule()
                                .strokeBorder(currentAppearance.textColor.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.hapticPlain)
                .accessibilityIdentifier("Onboarding.SkipTutorial")
                .padding(.bottom, 32)
            }
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
        HStack(spacing: 10) {
            dateNavStepButton(
                systemName: "chevron.left",
                accessibilityKey: "accessibility.previous_day",
                action: model.goToPreviousDay
            )

            Button {
                datePickerSelection = model.displayedDate
                showingDatePicker = true
            } label: {
                VStack(alignment: .center, spacing: 2) {
                    Text(dateString(for: model.displayedDate))
                        .appFont(size: 13, weight: .semibold)
                        .foregroundColor(currentAppearance.textColor.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(hijriDateString(for: model.displayedDate))
                        .appFont(size: 10, weight: .medium)
                        .foregroundColor(currentAppearance.textColor.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(currentAppearance.textColor.opacity(0.12), lineWidth: 0.5)
                )
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel(Text(homeLS("accessibility.pick_date", locale: locale)))
            .accessibilityHint(Text(homeLS("accessibility.pick_date_hint", locale: locale)))

            dateNavStepButton(
                systemName: "chevron.right",
                accessibilityKey: "accessibility.next_day",
                action: model.goToNextDay
            )
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func dateNavStepButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appFont(size: 16, weight: .semibold)
                .foregroundColor(currentAppearance.textColor.opacity(0.72))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(Text(homeLS(accessibilityKey, locale: locale)))
    }

    @ViewBuilder
    private func datePickerSheet() -> some View {
        NavigationStack {
            DatePicker(
                homeLS("home.pick_date_title", locale: locale),
                selection: $datePickerSelection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.timeZone, PrayerTimesEngine.sheffieldTimeZone)
            .padding(.horizontal, 12)
            .navigationTitle(homeLS("home.pick_date_title", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(homeLS("action.cancel", locale: locale)) {
                        showingDatePicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(homeLS("settings.done", locale: locale)) {
                        model.goToDate(datePickerSelection)
                        showingDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }

    private func hijriDateString(for date: Date) -> String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamicCalendar
        formatter.locale = locale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func checkWhatsNew() {
        let currentBuild = WhatsNew.fullVersionString
        guard settings.lastSeenBuildVersion != currentBuild else { return }
        guard settings.hasCompletedOnboarding else { return }
        guard !onboarding.isActive else { return }
        showingWhatsNew = true
    }

    private func checkForUpdateIfNeeded() {
        guard !hasCheckedForUpdate else { return }
        guard settings.hasCompletedOnboarding else { return }
        hasCheckedForUpdate = true

        Task {
            let status = await AppUpdateChecker.checkForUpdate()
            switch status {
            case .updateAvailable(let release):
                pendingRelease = release
                presentUpdateAlertIfReady()
            case .upToDate, .checkFailed:
                break
            }
        }
    }

    private func presentTestUpdateAlert() {
        Task {
            pendingRelease = await AppUpdateChecker.fetchLatestRelease() ?? MasjidlyRelease.testRelease
            presentUpdateAlertIfReady()
        }
    }

    private func presentUpdateAlertIfReady() {
        guard pendingRelease != nil else { return }
        guard settings.hasCompletedOnboarding else { return }
        guard !onboarding.isActive else { return }
        guard !showingWhatsNew else { return }
        guard !reviewPrompt.showEnjoymentPrompt else { return }
        guard !showReviewFeedbackPrompt else { return }
        guard !showingSettings else { return }
        guard !showingTimetable else { return }
        showUpdateAlert = true
    }

    private func openReviewFeedbackEmail() {
        let mosqueName: String? = {
            guard let id = settings.selectedMosqueId else { return nil }
            return model.mosques.first { $0.id == id }?.name
        }()
        let context = MasjidlySupportMail.currentContext(mosqueName: mosqueName)
        guard let url = MasjidlySupportMail.mailtoURL(category: .feedback, locale: locale, context: context) else { return }
        openURL(url)
    }

    private var reviewFeedbackTitle: String {
        homeLS("review.feedback.title", locale: locale)
    }

    private var reviewFeedbackMessage: String {
        homeLS("review.feedback.message", locale: locale)
    }

    private var reviewFeedbackSendLabel: String {
        homeLS("review.feedback.send", locale: locale)
    }

    private var reviewFeedbackLaterLabel: String {
        homeLS("review.feedback.later", locale: locale)
    }

    private var updateAlertTitle: String {
        switch settings.appLanguage {
        case .arabic: return "تحديث متوفر"
        case .urdu: return "اپ ڈیٹ دستیاب ہے"
        case .indonesian: return "Pembaruan Tersedia"
        default: return "Update Available"
        }
    }

    private var updateNowLabel: String {
        switch settings.appLanguage {
        case .arabic: return "فتح المتجر"
        case .urdu: return "اسٹور کھولیں"
        case .indonesian: return "Buka App Store"
        default: return "Open App Store"
        }
    }

    private var updateLaterLabel: String {
        switch settings.appLanguage {
        case .arabic: return "لاحقاً"
        case .urdu: return "بعد میں"
        case .indonesian: return "Nanti"
        default: return "Later"
        }
    }

    private var updateMessage: String {
        switch settings.appLanguage {
        case .arabic: return "نسخة أحدث من مسجدلي جاهزة للتثبيت."
        case .urdu: return "مسجدلی کا نیا ورژن انسٹال کرنے کے لیے تیار ہے۔"
        case .indonesian: return "Versi baru Masjidly siap dipasang."
        default: return "A newer version of Masjidly is ready."
        }
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
        settings.selectedCountryGroupingKey = MosqueDefaults.countryGroupingKey(for: mosque)
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

    private func isTodayInSheffield(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.isDate(date, inSameDayAs: Date())
    }

    private func secondJummahSubtitleLine(raw: String?) -> String? {
        let slots = PrayerTimesEngine.splitJummahIqamahTimes(raw)
        guard slots.count >= 2 else { return nil }
        let base = PrayerLocalization.displayName(canonicalEnglish: "Jummah", locale: locale)
        return "\(base) 2: \(formatTime(slots[1]))"
    }

    private func displayJummahTime(raw: String?, fallbackDhuhr: String) -> String {
        let slots = PrayerTimesEngine.splitJummahIqamahTimes(raw)
        return slots.first ?? fallbackDhuhr
    }

    private func wallClockToday(_ time: String, now: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: cal.startOfDay(for: now))
    }

    private func iqamahString(for prayerName: String, daily: DailyPrayerTimes, iq: DailyIqamahTimes?, mosqueSlug: String) -> String? {
        guard let iq else { return nil }
        let date = model.displayedDate
        switch prayerName {
        case "Fajr":
            return PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: daily.fajr, iqamahTimes: iq)
        case "Sunrise":
            return nil
        case "Dhuhr":
            if isFridayInSheffield(date) { return nil }
            return PrayerTimesEngine.getDisplayIqamah(
                prayer: "dhuhr", adhanTime: daily.dhuhr, iqamahTimes: iq,
                mosqueSlug: mosqueSlug, date: date, maghribAdhan: daily.maghrib
            )
        case "Jummah":
            return nil
        case "Asr":
            return PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhanTime: daily.asr, preference: settings.asrIqamahPreference)
        case "Maghrib":
            return PrayerTimesEngine.getDisplayIqamah(
                prayer: "maghrib", adhanTime: daily.maghrib, iqamahTimes: iq,
                mosqueSlug: mosqueSlug, date: date, maghribAdhan: daily.maghrib
            )
        case "Isha":
            return PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: mosqueSlug,
                date: date,
                ishaAdhan: daily.isha,
                iqamahTimes: iq,
                maghribAdhan: daily.maghrib
            )
        default:
            return nil
        }
    }

    private func duhaSubtitleLine(daily: DailyPrayerTimes) -> String? {
        guard settings.showDuhaTime else { return nil }
        guard let window = PrayerTimesEngine.duhaWindow(sunrise: daily.sunrise, dhuhr: daily.dhuhr) else { return nil }
        let start = formatTime(window.start)
        let end = formatTime(window.end)
        let format = homeLS("home.duha_format", locale: locale)
        return String(format: format, locale: locale, arguments: [start, end])
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
        let iqFormatted: String
        iqFormatted = formatTime(raw)
        let displayTime = iqFormatted == adhanFormatted ? adhanFormatted : iqFormatted
        let format = homeLS("home.iqamah_format", locale: locale)
        return String(format: format, locale: locale, arguments: [displayTime])
    }
}

private extension View {
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
            Button(loveTitle) {
                HapticFeedback.buttonTap()
                onLoveIt()
            }
            Button(notReallyTitle, role: .cancel) {
                HapticFeedback.buttonTap()
                onNotReally()
            }
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

