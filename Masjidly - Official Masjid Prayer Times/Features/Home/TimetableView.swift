import SwiftUI

private func ttLS(_ key: String, locale: Locale) -> String {
    LocaleBundle.string(forKey: key, locale: locale)
}

private enum TimetableTimeColumns {
    /// Adhan / Iqamah — 105pt accommodates bold 18pt 12-hour strings
    /// (e.g. `10:07 PM`) even with Arabic (1.20×) or Urdu (1.25×) font scaling.
    /// Width increased from 94 to prevent minimumScaleFactor from shrinking
    /// the next-prayer row's bold text below the nominal 18pt.
    static let width: CGFloat = 105

    /// Shared row font size for prayer name, adhan, and iqamah.
    /// Uniform for all rows/dates; time column width accommodates this size.
    static let rowFontSize: CGFloat = 18
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
    @State private var noDataForCurrentMonth = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding
    /// Derived from the observable store so language changes re-localize immediately.
    private var locale: Locale { settings.resolvedLocale }

    private var appearance: HomeDesign.ResolvedTheme {
        settings.resolvedAppearance(for: timeTheme)
    }

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
            AtmosphericSkyBackground(sky: appearance.sky)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                monthSwitcher
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                if !noDataForCurrentMonth {
                    dateStrip
                        .padding(.bottom, 32)
                }

                if isLoadingMonth {
                    Spacer()
                    ProgressView()
                        .tint(appearance.textColor)
                    Spacer()
                } else if noDataForCurrentMonth {
                    missingMonthMessage
                    Spacer()
                } else if let currentPrayerTime = currentMonthData.prayerTimes.first(where: { $0.date == selectedDate }) {
                    prayersStack(for: currentPrayerTime)
                        .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                } else {
                    missingMonthMessage
                    Spacer()
                }
            }
        }
        .preferredColorScheme(appearance.usesLightForeground ? .dark : .light)
        .onAppear {
            noDataForCurrentMonth = currentMonthData.prayerTimes.isEmpty
            let today = currentDayOfSystem
            if currentMonthData.prayerTimes.contains(where: { $0.date == today }) {
                selectedDate = today
            } else if let first = currentMonthData.prayerTimes.first {
                selectedDate = first.date
            }
        }
        .overlay {
            Group {
                if onboarding.currentStep == .exploreTimetable {
                    OnboardingCoachMarkView(
                        title: ttLS("onboarding.explore_timetable.title", locale: locale),
                        message: ttLS("onboarding.explore_timetable.message", locale: locale),
                        timeTheme: timeTheme,
                        variant: .floatingBottom,
                        primaryButtonTitle: ttLS("onboarding.continue", locale: locale),
                        onPrimaryButton: {
                            onboarding.acknowledgeTimetableExplore()
                        },
                        primaryButtonAccessibilityIdentifier: "Onboarding.TimetableExploreContinue"
                    )
                } else if onboarding.currentStep == .closeTimetable {
                    OnboardingCoachMarkView(
                        title: ttLS("onboarding.close_timetable.title", locale: locale),
                        message: ttLS("onboarding.close_timetable.message", locale: locale),
                        timeTheme: timeTheme,
                        variant: .belowTopChrome
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                Task { await changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .appFont(size: 16, weight: .medium)
                    .foregroundStyle(appearance.textColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.hapticPlain)
            .disabled(isLoadingMonth)
            
            Spacer()

            Text(monthSwitcherTitle)
                .appFont(size: 18, weight: .medium)
                .foregroundStyle(appearance.textColor)

            Spacer()
            
            Button {
                Task { await changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .appFont(size: 16, weight: .medium)
                    .foregroundStyle(appearance.textColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.hapticPlain)
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
        
        let newData = await model.fetchMonthData(mosqueSlug: mosqueSlug, month: m, year: y)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentMonth = m
            currentYear = y

            guard let newData, !newData.prayerTimes.isEmpty else {
                noDataForCurrentMonth = true
                selectedDate = 1
                isLoadingMonth = false
                return
            }

            currentMonthData = newData
            noDataForCurrentMonth = false

            let systemMonth = Calendar.current.component(.month, from: Date())
            let systemYear = Calendar.current.component(.year, from: Date())

            if m == systemMonth && y == systemYear && newData.prayerTimes.contains(where: { $0.date == currentDayOfSystem }) {
                selectedDate = currentDayOfSystem
            } else {
                selectedDate = newData.prayerTimes.first?.date ?? 1
            }
            isLoadingMonth = false
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedSelectedDateWithHijri(day: selectedDate))
                    .appFont(size: 18, weight: .light)
                    .foregroundStyle(appearance.textColor)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(mosqueName)
                    .appFont(size: 14, weight: .regular)
                    .foregroundStyle(appearance.textColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .appFont(size: 16, weight: .bold)
                    .foregroundColor(appearance.textColor)
                    .padding(8)
                    .background(Circle().fill(appearance.textColor.opacity(0.1)))
            }
            .buttonStyle(.hapticPlain)
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
                                .appFont(size: 10, weight: .semibold)
                                .foregroundStyle(isSelected ? appearance.textColor : appearance.textColor.opacity(0.4))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(localizedDayNumber(time.date))
                                .appFont(size: 20, weight: isSelected ? .medium : .regular)
                                .foregroundStyle(isSelected ? appearance.textColor : appearance.textColor.opacity(0.5))
                            
                            if isToday {
                                Circle()
                                    .fill(appearance.textColor)
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
                                .fill(isSelected ? appearance.textColor.opacity(0.12) : Color.clear)
                        )
                        .onTapGesture {
                            HapticFeedback.buttonTap()
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

    private var missingMonthMessage: some View {
        VStack(spacing: 16) {
            Text(ttLS("timetable.missing_month", locale: locale))
                .appFont(size: 16, weight: .regular)
                .foregroundStyle(appearance.textColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                openMissingTimesEmail()
            } label: {
                Text(ttLS("home.request_times_button", locale: locale))
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(appearance.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(appearance.textColor.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(appearance.textColor.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Timetable.MissingTimes.EmailButton")
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func openMissingTimesEmail() {
        let context = MasjidlySupportMail.currentContext(mosqueName: mosqueName)
        guard let url = MasjidlySupportMail.missingPrayerTimesURL(
            locale: locale,
            context: context,
            monthDisplay: monthSwitcherTitle
        ) else { return }
        openURL(url)
    }

    private func prayersStack(for time: PrayerTime) -> some View {
        let dailyIqamah = try? PrayerTimesEngine.getIqamahTimesForDate(dayOfMonth: time.date, iqamahRanges: currentMonthData.iqamahTimes)
        let isToday = (selectedDate == currentDayOfSystem)
        let prayerDate = PrayerTimesEngine.sheffieldNoonUTC(year: currentYear, month: currentMonth, day: time.date)

        var rows: [RowData] = []
        
        let fAdhan = formatTime(time.fajr)
        let fIqamah = resolveIqamahString(id: "fajr", adhan: time.fajr, iqamahRaw: dailyIqamah, maghrib: time.maghrib, for: prayerDate)
        rows.append(RowData(id: "fajr", name: ttLS("timetable.header.fajr", locale: locale), adhanSortKey: time.fajr, adhanDisplay: fAdhan, iqamahDisplay: fIqamah))
        
        rows.append(RowData(id: "sunrise", name: ttLS("timetable.header.shu", locale: locale), adhanSortKey: time.shurooq, adhanDisplay: formatTime(time.shurooq), iqamahDisplay: "-"))

        let dAdhan = formatTime(time.dhuhr)
        if isFriday(dayOfMonth: time.date) {
            rows.append(contentsOf: fridayJummahRowsReplacingDhuhr(time: time, dhuhrAdhanFormatted: dAdhan, dailyIqamah: dailyIqamah))
        } else {
            let dIqamah = resolveIqamahString(id: "dhuhr", adhan: time.dhuhr, iqamahRaw: dailyIqamah, maghrib: time.maghrib, for: prayerDate)
            rows.append(RowData(id: "dhuhr", name: ttLS("timetable.header.dhu", locale: locale), adhanSortKey: time.dhuhr, adhanDisplay: dAdhan, iqamahDisplay: dIqamah))
        }

        let aAdhan = formatTime(time.asr)
        let aIqamah = resolveIqamahString(id: "asr", adhan: time.asr, iqamahRaw: dailyIqamah, maghrib: time.maghrib, for: prayerDate)
        rows.append(RowData(id: "asr", name: ttLS("timetable.header.asr", locale: locale), adhanSortKey: time.asr, adhanDisplay: aAdhan, iqamahDisplay: aIqamah))

        let mAdhan = formatTime(time.maghrib)
        let mIqamah = resolveIqamahString(id: "maghrib", adhan: time.maghrib, iqamahRaw: dailyIqamah, maghrib: time.maghrib, for: prayerDate)
        rows.append(RowData(id: "maghrib", name: ttLS("timetable.header.mag", locale: locale), adhanSortKey: time.maghrib, adhanDisplay: mAdhan, iqamahDisplay: mIqamah))

        let iAdhan = formatTime(time.isha)
        let iIqamah = resolveIqamahString(id: "isha", adhan: time.isha, iqamahRaw: dailyIqamah, maghrib: time.maghrib, for: prayerDate)
        rows.append(RowData(id: "isha", name: ttLS("timetable.header.ish", locale: locale), adhanSortKey: time.isha, adhanDisplay: iAdhan, iqamahDisplay: iIqamah))

        // Compute next prayer BEFORE adding midnight/lastThird (informational rows)
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

        // Midnight & Last Third of the Night (informational — excluded from next-prayer)
        let nextDayFajr: String? = {
            let sorted = currentMonthData.prayerTimes.sorted { $0.date < $1.date }
            guard let currentIndex = sorted.firstIndex(where: { $0.date == time.date }),
                  currentIndex + 1 < sorted.count else { return nil }
            return sorted[currentIndex + 1].fajr
        }()
        let nightPeriods = PrayerTimesEngine.computeMidnightAndLastThird(
            maghrib: time.maghrib, nextDayFajr: nextDayFajr)
        if let midnight = nightPeriods.midnight {
            rows.append(RowData(
                id: "midnight",
                name: ttLS("timetable.header.midnight", locale: locale),
                adhanSortKey: midnight,
                adhanDisplay: formatTime(midnight),
                iqamahDisplay: "-"))
        }
        if let lastThird = nightPeriods.lastThird {
            rows.append(RowData(
                id: "lastThird",
                name: ttLS("timetable.header.lastThird", locale: locale),
                adhanSortKey: lastThird,
                adhanDisplay: formatTime(lastThird),
                iqamahDisplay: "-"))
        }

        return VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(ttLS("timetable.header.prayer", locale: locale))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ttLS("timetable.header.adhan", locale: locale))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: TimetableTimeColumns.width, alignment: .trailing)
                Text(ttLS("timetable.header.iqamah", locale: locale))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: TimetableTimeColumns.width, alignment: .trailing)
            }
            .appFont(size: 13, weight: .medium)
            .foregroundStyle(appearance.textColor.opacity(0.5))
            .padding(.horizontal, 24)
            .padding(.bottom, 4)

            ForEach(rows) { r in
                prayerRow(
                    name: r.name,
                    adhanDisplay: r.adhanDisplay,
                    iqamahDisplay: r.iqamahDisplay,
                    isNext: r.id == nextId,
                    isPast: isToday && isTimePast(r.adhanSortKey, now: currentHHMM, isNextDayRow: r.id == "midnight" || r.id == "lastThird")
                )
            }
        }
    }

    /// Friday only: one row per Jummah slot — Dhuhr adhan + Jummah iqāmah (replaces the normal Dhuhr row).
    private func fridayJummahRowsReplacingDhuhr(
        time: PrayerTime,
        dhuhrAdhanFormatted: String,
        dailyIqamah: DailyIqamahTimes?
    ) -> [RowData] {
        let label = PrayerLocalization.displayName(canonicalEnglish: "Jummah", locale: locale)
        let rawJummah = resolvedRawJummahString(dailyIqamah: dailyIqamah)
        let jTimes = PrayerTimesEngine.splitJummahIqamahTimes(rawJummah)

        var out: [RowData] = []
        if jTimes.isEmpty {
            out.append(RowData(
                id: "jummah_0",
                name: numberedJummahLabel(base: label, index: 0, total: 1),
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
                    name: numberedJummahLabel(base: label, index: idx, total: jTimes.count),
                    adhanSortKey: time.dhuhr,
                    adhanDisplay: dhuhrAdhanFormatted,
                    iqamahDisplay: iqamahCell
                ))
            }
        }
        return out
    }

    private func numberedJummahLabel(base: String, index: Int, total: Int) -> String {
        total > 1 ? "\(base) \(index + 1)" : base
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
                .appFont(size: TimetableTimeColumns.rowFontSize, weight: weight)
                .foregroundStyle(appearance.textColor.opacity(opacity))
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(isNext ? 1.0 : 0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Text(adhanDisplay)
                .appFont(size: TimetableTimeColumns.rowFontSize, weight: weight)
                .monospacedDigit()
                .foregroundStyle(appearance.textColor.opacity(opacity * 0.75))
                .lineLimit(1)
                .minimumScaleFactor(isNext ? 1.0 : 0.78)
                .multilineTextAlignment(.trailing)
                .frame(width: TimetableTimeColumns.width, alignment: .trailing)

            Text(iqamahDisplay)
                .appFont(size: TimetableTimeColumns.rowFontSize, weight: iqamahWeight)
                .monospacedDigit()
                .foregroundStyle(appearance.textColor.opacity(opacity))
                .lineLimit(1)
                .minimumScaleFactor(isNext ? 1.0 : 0.78)
                .multilineTextAlignment(.trailing)
                .frame(width: TimetableTimeColumns.width, alignment: .trailing)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isNext ? appearance.textColor.opacity(0.08) : Color.clear)
        )
    }

    private var monthSwitcherTitle: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let d = cal.date(from: DateComponents(year: currentYear, month: currentMonth, day: 15)) else {
            return currentMonthData.month.capitalized
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = PrayerTimesEngine.sheffieldTimeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: d)
    }

    private func localizedDayNumber(_ day: Int) -> String {
        let n = NSNumber(value: day)
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .none
        return f.string(from: n) ?? "\(day)"
    }

    private func formatTime(_ t: String) -> String {
        PrayerTimesEngine.formatPrayerTimeForDisplay(t, uses24Hour: settings.uses24HourTime, locale: locale)
    }

    private func formatSystemTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = PrayerTimesEngine.sheffieldTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    /// Compare two HH:mm strings with next-day awareness for cross-midnight times.
    /// For `isNextDayRow` times (midnight/lastThird), if `now` is in PM (>= 12:00)
    /// the time belongs to the next day and hasn't happened yet.
    private func isTimePast(_ time: String, now: String, isNextDayRow: Bool = false) -> Bool {
        guard let tMin = PrayerTimesEngine.timeToMinutes(time),
              let nMin = PrayerTimesEngine.timeToMinutes(now) else {
            return false
        }
        if isNextDayRow && nMin >= 720 {
            return false
        }
        return tMin <= nMin
    }

    private func dateFor(day: Int) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.date(from: DateComponents(year: currentYear, month: currentMonth, day: day))
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

    private func hijriDateString(for date: Date) -> String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamicCalendar
        formatter.locale = locale
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formattedSelectedDateWithHijri(day: Int) -> String {
        let gregorian = formattedSelectedDate(day: day)
        guard let date = dateFor(day: day) else { return gregorian }
        let hijri = hijriDateString(for: date)
        guard !hijri.isEmpty else { return gregorian }
        return "\(gregorian) · \(hijri)"
    }
    
    private func resolveIqamahString(id: String, adhan: String, iqamahRaw: DailyIqamahTimes?, maghrib: String, for date: Date) -> String {
        if id == "sunrise" { return "-" }
        guard let iq = iqamahRaw else { return "-" }
        let resolved = id == "asr"
            ? PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhanTime: adhan, preference: settings.asrIqamahPreference)
            : PrayerTimesEngine.getDisplayIqamah(
                prayer: id,
                adhanTime: adhan,
                iqamahTimes: iq,
                mosqueSlug: mosqueSlug,
                date: date,
                maghribAdhan: maghrib
            )
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
        locale: Locale,
        asrIqamahPreference: AsrIqamahPreference
    ) async throws {}
    func cancelAllPrayerNotifications() async {}
}

#Preview {
    let settings = SettingsStore()
    let cache = PrayerTimesDiskCache()
    let homeVM = HomeViewModel(
        repository: TimetablePreviewPrayerRepository(),
        settings: settings,
        notificationScheduler: TimetablePreviewNotificationScheduler(),
        diskCache: cache
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
