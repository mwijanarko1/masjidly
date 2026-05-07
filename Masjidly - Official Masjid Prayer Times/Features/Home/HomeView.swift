import SwiftUI

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(SettingsViewModel.self) private var settingsViewModel

    @State private var showingSettings = false
    @State private var showingTimetable = false

    private var currentTheme: HomeDesign.TimeTheme {
        return .weather // Force weather theme for the new look
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background Base (Clean Light Theme)
            ZStack {
                LinearGradient(gradient: currentTheme.gradient, startPoint: .top, endPoint: .bottom)
                
                // Subtle Top Shine
                Circle()
                    .fill(Color(hex: "47A6FF").opacity(0.05))
                    .frame(width: 400, height: 400)
                    .offset(x: 200, y: -100)
                    .blur(radius: 80)
            }
            .ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 32) { 
                    headerBar
                        .padding(.top, 60)
                    
                    if let d = model.displayedPrayerTimes, let next = model.nextCountdown {
                        VStack(spacing: 0) {
                            HeroIllustration(nextPrayerName: next.nextName)
                            
                            HeroContent(
                                prayerName: next.nextName,
                                prayerTime: formatTime(next.nextTime),
                                countdown: "Updating",
                                gregorianDate: gregorianLine(for: d.date),
                                hijriDate: DateUtils.hijriDateString(for: Date())
                            )
                        }
                        
                        // Info Row (Prayer Stats)
                        HStack(spacing: 16) {
                            QuickInfoItem(icon: "sunrise.fill", value: formatTime(d.sunrise), label: "Sunrise")
                            QuickInfoItem(icon: "person.2.fill", value: jamaahTime(for: next.nextName, times: d), label: "Jama'ah")
                            QuickInfoItem(icon: "clock.arrow.2.circlepath", value: "05:15", label: "Next Change")
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                Spacer(minLength: 20)
                
                // Today Section
                if let d = model.displayedPrayerTimes {
                    todaySection(d: d)
                        .padding(.bottom, 30)
                }
            }
        }
            .ignoresSafeArea(edges: .top)
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
        .sheet(isPresented: $showingTimetable) {
            if let monthData = model.monthData, let mosque = model.selectedMosque {
                TimetableView(monthData: monthData, mosqueName: mosque.name, timeTheme: currentTheme)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: settingsViewModel)
                .environment(settings)
        }
    }

    private var headerBar: some View {
        HStack {
            // Placeholder for left balance
            Spacer()
                .frame(width: 48)
            
            Spacer()
            
            // Centered mosque dropdown
            Menu {
                ForEach(model.mosques) { mosque in
                    Button {
                        selectMosque(mosque)
                    } label: {
                        HStack {
                            Text(mosque.name)
                            if model.selectedMosque?.id == mosque.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(model.selectedMosque?.name ?? "Select Mosque")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HomeDesign.Colors.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HomeDesign.Colors.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())
                .customShadow(HomeDesign.Shadows.softCard)
                .overlay(Capsule().stroke(Color(hex: "F0F0F0"), lineWidth: 1))
            }
            .accessibilityIdentifier("HomeMosquePicker")
            .accessibilityLabel(Text("Current mosque"))
            .accessibilityHint(Text("Shows a menu to change mosque"))
            
            Spacer()
            
            // Right Settings Button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(HomeDesign.Colors.primary)
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
                    .customShadow(HomeDesign.Shadows.softCard)
                    .overlay(Circle().stroke(Color(hex: "F0F0F0"), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
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

    @ViewBuilder
    private func todaySection(d: DailyPrayerTimes) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(HomeDesign.Colors.primary)
                Spacer()
                Button {
                    showingTimetable = true
                } label: {
                    HStack(spacing: 4) {
                        Text("7 days")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeDesign.Colors.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let prayers = [
                        ("Fajr", d.fajr, "sunrise.fill"),
                        ("Dhuhr", d.dhuhr, "sun.max.fill"),
                        ("Asr", d.asr, "cloud.sun.fill"),
                        ("Maghrib", d.maghrib, "moon.stars.fill"),
                        ("Isha", d.isha, "moon.fill")
                    ]
                    
                    ForEach(prayers, id: \.0) { p in
                        PrayerCarouselItem(
                            name: p.0,
                            time: formatTime(p.1),
                            icon: p.2,
                            isSelected: model.nextCountdown?.nextName == p.0
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func gregorianLine(for iso: String) -> String {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return iso }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return iso
        }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        f.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return f.string(from: date)
    }

    private func jamaahTime(for prayer: String, times: DailyPrayerTimes) -> String {
        guard let iq = model.iqamahTimes else { return "--:--" }
        let adhan = switch prayer.lowercased() {
            case "fajr": times.fajr
            case "dhuhr", "jummah": times.dhuhr
            case "asr": times.asr
            case "maghrib": times.maghrib
            case "isha": times.isha
            default: ""
        }
        
        let raw = if prayer.lowercased() == "isha" {
            PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: model.selectedMosque?.slug ?? "",
                date: Date(),
                ishaAdhan: times.isha,
                iqamahTimes: iq,
                maghribAdhan: times.maghrib
            )
        } else {
            PrayerTimesEngine.getIqamahTime(prayer: prayer, adhanTime: adhan, iqamahTimes: iq)
        }
        
        return formatTime(raw)
    }

    private func formatTime(_ t: String) -> String {
        settings.uses24HourTime ? t : PrayerTimesEngine.formatTo12Hour(t)
    }
}

#Preview {
    let settings = SettingsStore()
    let repo = ConvexPrayerRepository(service: ConvexService())
    let scheduler = PrayerNotificationScheduler(repository: repo)
    let homeVM = HomeViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    let settingsVM = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    return NavigationStack {
        HomeView(model: homeVM)
            .environment(settings)
            .environment(settingsVM)
    }
}

