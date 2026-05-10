import SwiftUI

private func ttLS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

struct TimetableView: View {
    @State private var currentMonthData: MonthPrayerData
    let initialMonthData: MonthPrayerData
    let mosqueName: String
    let mosqueSlug: String
    let timeTheme: HomeDesign.TimeTheme
    let model: HomeViewModel
    var onDismiss: (() -> Void)? = nil

    @State private var currentMonth: Int
    @State private var currentYear: Int
    @State private var isLoadingMonth = false

    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding
    @Environment(\.locale) private var locale

    @State private var selectedDate: Int = 1

    init(
        initialMonthData: MonthPrayerData,
        mosqueName: String,
        mosqueSlug: String,
        timeTheme: HomeDesign.TimeTheme,
        model: HomeViewModel,
        onDismiss: (() -> Void)? = nil
    ) {
        self.initialMonthData = initialMonthData
        self._currentMonthData = State(initialValue: initialMonthData)
        self.mosqueName = mosqueName
        self.mosqueSlug = mosqueSlug
        self.timeTheme = timeTheme
        self.model = model
        self.onDismiss = onDismiss
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        var m = Calendar.current.component(.month, from: Date())
        var y = Calendar.current.component(.year, from: Date())
        
        if let d = formatter.date(from: initialMonthData.month) {
            m = Calendar.current.component(.month, from: d)
            y = Calendar.current.component(.year, from: d)
        } else {
            formatter.dateFormat = "MMM yyyy"
            if let d = formatter.date(from: initialMonthData.month) {
                m = Calendar.current.component(.month, from: d)
                y = Calendar.current.component(.year, from: d)
            }
        }
        
        self._currentMonth = State(initialValue: m)
        self._currentYear = State(initialValue: y)
    }

    private var currentDayOfSystem: Int {
        Calendar.current.component(.day, from: Date())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: timeTheme.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                monthSwitcher
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                dateStrip
                    .padding(.bottom, 32)

                if isLoadingMonth {
                    Spacer()
                    ProgressView()
                        .tint(timeTheme.textColor)
                    Spacer()
                } else if let currentPrayerTime = currentMonthData.prayerTimes.first(where: { $0.date == selectedDate }) {
                    prayersStack(for: currentPrayerTime)
                        .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                } else {
                    Spacer()
                }
            }
        }
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
        .onAppear {
            let today = currentDayOfSystem
            if currentMonthData.prayerTimes.contains(where: { $0.date == today }) {
                selectedDate = today
            } else if let first = currentMonthData.prayerTimes.first {
                selectedDate = first.date
            }
        }
        .overlay {
            if onboarding.currentStep == .closeTimetable {
                OnboardingCoachMarkView(
                    title: "Close the timetable",
                    message: "Tap the close button to return to the prayer times.",
                    timeTheme: timeTheme,
                    variant: .belowTopChrome
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                Task { await changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(HomeDesign.Typography.app(size: 16, weight: .medium))
                    .foregroundStyle(timeTheme.textColor)
                    .frame(width: 44, height: 44)
            }
            .disabled(isLoadingMonth)
            
            Spacer()
            
            Text(currentMonthData.month.capitalized)
                .font(HomeDesign.Typography.app(size: 18, weight: .medium))
                .foregroundStyle(timeTheme.textColor)
            
            Spacer()
            
            Button {
                Task { await changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(HomeDesign.Typography.app(size: 16, weight: .medium))
                    .foregroundStyle(timeTheme.textColor)
                    .frame(width: 44, height: 44)
            }
            .disabled(isLoadingMonth)
        }
    }

    private func changeMonth(by value: Int) async {
        guard !isLoadingMonth else { return }
        isLoadingMonth = true
        
        var m = currentMonth + value
        var y = currentYear
        
        if m < 1 {
            m = 12
            y -= 1
        } else if m > 12 {
            m = 1
            y += 1
        }
        
        if let newData = await model.fetchMonthData(mosqueSlug: mosqueSlug, month: m, year: y) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentMonthData = newData
                currentMonth = m
                currentYear = y
                
                let systemMonth = Calendar.current.component(.month, from: Date())
                let systemYear = Calendar.current.component(.year, from: Date())
                
                if m == systemMonth && y == systemYear {
                    selectedDate = currentDayOfSystem
                } else {
                    selectedDate = 1
                }
            }
        }
        isLoadingMonth = false
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedSelectedDate(day: selectedDate))
                    .font(HomeDesign.Typography.app(size: 24, weight: .light))
                    .foregroundStyle(timeTheme.textColor)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(mosqueName)
                    .font(HomeDesign.Typography.app(size: 15, weight: .regular))
                    .foregroundStyle(timeTheme.textColor.opacity(0.7))
            }
            Spacer()
            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(HomeDesign.Typography.app(size: 14, weight: .light))
                    .foregroundStyle(timeTheme.textColor.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(timeTheme.textColor.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .onboardingHighlight(onboarding.currentStep == .closeTimetable, timeTheme: timeTheme)
            .accessibilityIdentifier("Onboarding.TimetableClose")
            .accessibilityLabel(Text(ttLS("timetable.close_a11y", locale: locale)))
        }
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currentMonthData.prayerTimes, id: \.date) { time in
                        let isSelected = time.date == selectedDate
                        let isToday = time.date == currentDayOfSystem
                        
                        VStack(spacing: 4) {
                            Text(shortWeekday(for: time.date).uppercased())
                                .font(HomeDesign.Typography.app(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? timeTheme.textColor : timeTheme.textColor.opacity(0.4))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text("\(time.date)")
                                .font(HomeDesign.Typography.app(size: 20, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(isSelected ? timeTheme.textColor : timeTheme.textColor.opacity(0.5))
                            
                            if isToday {
                                Circle()
                                    .fill(timeTheme.textColor)
                                    .frame(width: 4, height: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(width: 48, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? timeTheme.textColor.opacity(0.12) : Color.clear)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = time.date
                            }
                        }
                        .id(time.date)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(selectedDate, anchor: .center)
                    }
                }
            }
        }
    }

    private struct RowData: Identifiable {
        let id: String
        let name: String
        let adhanSortKey: String
        let adhanDisplay: String
        let iqamahDisplay: String
    }

    private func prayersStack(for time: PrayerTime) -> some View {
        let dailyIqamah = try? PrayerTimesEngine.getIqamahTimesForDate(dayOfMonth: time.date, iqamahRanges: currentMonthData.iqamahTimes)
        let isToday = (selectedDate == currentDayOfSystem)

        var rows: [RowData] = []
        
        let fAdhan = formatTime(time.fajr)
        let fIqamah = resolveIqamahString(id: "fajr", adhan: time.fajr, iqamahRaw: dailyIqamah, maghrib: time.maghrib)
        rows.append(RowData(id: "fajr", name: ttLS("timetable.header.fajr", locale: locale), adhanSortKey: time.fajr, adhanDisplay: fAdhan, iqamahDisplay: fIqamah))
        
        rows.append(RowData(id: "sunrise", name: ttLS("timetable.header.shu", locale: locale), adhanSortKey: time.shurooq, adhanDisplay: formatTime(time.shurooq), iqamahDisplay: "-"))

        let dAdhan = formatTime(time.dhuhr)
        if isFriday(dayOfMonth: time.date) {
            rows.append(contentsOf: fridayJummahRowsReplacingDhuhr(time: time, dhuhrAdhanFormatted: dAdhan, dailyIqamah: dailyIqamah))
        } else {
            let dIqamah = resolveIqamahString(id: "dhuhr", adhan: time.dhuhr, iqamahRaw: dailyIqamah, maghrib: time.maghrib)
            rows.append(RowData(id: "dhuhr", name: ttLS("timetable.header.dhu", locale: locale), adhanSortKey: time.dhuhr, adhanDisplay: dAdhan, iqamahDisplay: dIqamah))
        }

        let aAdhan = formatTime(time.asr)
        let aIqamah = resolveIqamahString(id: "asr", adhan: time.asr, iqamahRaw: dailyIqamah, maghrib: time.maghrib)
        rows.append(RowData(id: "asr", name: ttLS("timetable.header.asr", locale: locale), adhanSortKey: time.asr, adhanDisplay: aAdhan, iqamahDisplay: aIqamah))

        let mAdhan = formatTime(time.maghrib)
        let mIqamah = resolveIqamahString(id: "maghrib", adhan: time.maghrib, iqamahRaw: dailyIqamah, maghrib: time.maghrib)
        rows.append(RowData(id: "maghrib", name: ttLS("timetable.header.mag", locale: locale), adhanSortKey: time.maghrib, adhanDisplay: mAdhan, iqamahDisplay: mIqamah))

        let iAdhan = formatTime(time.isha)
        let iIqamah = resolveIqamahString(id: "isha", adhan: time.isha, iqamahRaw: dailyIqamah, maghrib: time.maghrib)
        rows.append(RowData(id: "isha", name: ttLS("timetable.header.ish", locale: locale), adhanSortKey: time.isha, adhanDisplay: iAdhan, iqamahDisplay: iIqamah))

        let currentHHMM = formatSystemTime() 
        var nextId: String? = nil
        
        if isToday {
            for r in rows {
                if r.adhanSortKey > currentHHMM {
                    nextId = r.id
                    break
                }
            }
        }

        return VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(ttLS("Prayer", locale: locale))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ttLS("Adhan", locale: locale))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 65, alignment: .trailing)
                Text(ttLS("Iqamah", locale: locale))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 65, alignment: .trailing)
            }
            .font(HomeDesign.Typography.app(size: 13, weight: .medium))
            .foregroundStyle(timeTheme.textColor.opacity(0.5))
            .padding(.horizontal, 24)
            .padding(.bottom, 4)

            ForEach(rows) { r in
                prayerRow(
                    name: r.name,
                    adhanDisplay: r.adhanDisplay,
                    iqamahDisplay: r.iqamahDisplay,
                    isNext: r.id == nextId,
                    isPast: isToday && (r.adhanSortKey <= currentHHMM)
                )
            }
        }
    }

    /// Friday only: one row per Jumuah slot — Dhuhr adhan + Jumuah iqāmah (replaces the normal Dhuhr row).
    private func fridayJummahRowsReplacingDhuhr(
        time: PrayerTime,
        dhuhrAdhanFormatted: String,
        dailyIqamah: DailyIqamahTimes?
    ) -> [RowData] {
        let label = PrayerLocalization.displayName(canonicalEnglish: "Jummah", locale: locale)
        let rawJummah = resolvedRawJummahString(dailyIqamah: dailyIqamah)
        let jTimes = rawJummah.components(separatedBy: CharacterSet(charactersIn: ",/&|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [RowData] = []
        if jTimes.isEmpty {
            out.append(RowData(
                id: "jummah_0",
                name: label,
                adhanSortKey: time.dhuhr,
                adhanDisplay: dhuhrAdhanFormatted,
                iqamahDisplay: "-"
            ))
        } else {
            for (idx, jTime) in jTimes.enumerated() {
                let parts = jTime.components(separatedBy: CharacterSet.whitespaces).filter { !$0.isEmpty }
                let iqamahCell: String
                if parts.count >= 2 {
                    iqamahCell = "\(formatTime(parts[0])) · \(formatTime(parts[1]))"
                } else {
                    iqamahCell = formatTime(parts[0])
                }
                out.append(RowData(
                    id: "jummah_\(idx)",
                    name: label,
                    adhanSortKey: time.dhuhr,
                    adhanDisplay: dhuhrAdhanFormatted,
                    iqamahDisplay: iqamahCell
                ))
            }
        }
        return out
    }

    private func resolvedRawJummahString(dailyIqamah: DailyIqamahTimes?) -> String {
        let fromRange = dailyIqamah?.jummah.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromRange.isEmpty { return fromRange }
        return currentMonthData.jummahIqamah.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isFriday(dayOfMonth: Int) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let date = cal.date(from: DateComponents(year: currentYear, month: currentMonth, day: dayOfMonth)) else {
            return false
        }
        return cal.component(.weekday, from: date) == 6
    }

    private func prayerRow(name: String, adhanDisplay: String, iqamahDisplay: String, isNext: Bool, isPast: Bool) -> some View {
        let opacity = isPast ? 0.35 : 1.0
        let weight: Font.Weight = isNext ? .semibold : .regular
        let iqamahWeight: Font.Weight = isNext ? .bold : .medium

        return HStack(alignment: .top, spacing: 12) {
            Text(name)
                .font(HomeDesign.Typography.app(size: 18, weight: weight))
                .foregroundStyle(timeTheme.textColor.opacity(opacity))
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Text(adhanDisplay)
                .font(HomeDesign.Typography.app(size: 18, weight: weight).monospacedDigit())
                .foregroundStyle(timeTheme.textColor.opacity(opacity * 0.75))
                .frame(width: 65, alignment: .trailing)
            
            Text(iqamahDisplay)
                .font(HomeDesign.Typography.app(size: 18, weight: iqamahWeight).monospacedDigit())
                .foregroundStyle(timeTheme.textColor.opacity(opacity))
                .frame(width: 65, alignment: .trailing)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isNext ? timeTheme.textColor.opacity(0.08) : Color.clear)
        )
    }

    private func formatTime(_ t: String) -> String {
        settings.uses24HourTime ? t : PrayerTimesEngine.formatTo12Hour(t)
    }
    
    private func formatSystemTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func dateFor(day: Int) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy"
        if let d = formatter.date(from: "\(day) \(currentMonthData.month)") { return d }
        formatter.dateFormat = "d MMM yyyy"
        if let d = formatter.date(from: "\(day) \(currentMonthData.month)") { return d }
        let year = Calendar.current.component(.year, from: Date())
        formatter.dateFormat = "d MMMM yyyy"
        if let d = formatter.date(from: "\(day) \(currentMonthData.month) \(year)") { return d }
        return nil
    }

    private func shortWeekday(for day: Int) -> String {
        guard let date = dateFor(day: day) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func formattedSelectedDate(day: Int) -> String {
        guard let date = dateFor(day: day) else { return currentMonthData.month.capitalized }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE · d MMMM"
        return formatter.string(from: date)
    }
    
    private func resolveIqamahString(id: String, adhan: String, iqamahRaw: DailyIqamahTimes?, maghrib: String) -> String {
        if id == "sunrise" { return "-" }
        guard let iq = iqamahRaw else { return "-" }
        let resolved = PrayerTimesEngine.getIqamahTime(prayer: id, adhanTime: adhan, iqamahTimes: iq, maghribAdhan: maghrib)
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "no iqamah" { return "-" }
        return formatTime(resolved)
    }
}

private final class TimetablePreviewPrayerRepository: PrayerRepository {
    func listMosques() async throws -> [Mosque] { [] }
    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? { nil }
    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? { nil }
    func getUkDstDates() async throws -> UkDstCalendar? { nil }
}

private final class TimetablePreviewNotificationScheduler: PrayerNotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool { false }
    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale
    ) async throws {}
    func cancelAllPrayerNotifications() async {}
}

#Preview {
    let settings = SettingsStore()
    let homeVM = HomeViewModel(
        repository: TimetablePreviewPrayerRepository(),
        settings: settings,
        notificationScheduler: TimetablePreviewNotificationScheduler()
    )
    return TimetableView(
        initialMonthData: MonthPrayerData(
            month: "May 2026",
            prayerTimes: [
                PrayerTime(date: 1, fajr: "03:45", shurooq: "05:20", dhuhr: "13:05", asr: "17:15", maghrib: "20:45", isha: "22:15"),
                PrayerTime(date: 2, fajr: "03:43", shurooq: "05:18", dhuhr: "13:05", asr: "17:16", maghrib: "20:47", isha: "22:17"),
                PrayerTime(date: 10, fajr: "03:43", shurooq: "05:18", dhuhr: "13:05", asr: "17:16", maghrib: "20:47", isha: "22:17")
            ],
            iqamahTimes: [],
            jummahIqamah: "13:15"
        ),
        mosqueName: "Madina Masjid",
        mosqueSlug: "madina-masjid",
        timeTheme: .dhuhr,
        model: homeVM
    )
    .environment(settings)
}
