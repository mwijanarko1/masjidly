import re

with open("Masjidly - Official Masjid Prayer Times/Features/Home/TimetableView.swift", "r") as f:
    code = f.read()

# Replace monthData with currentMonthData everywhere
code = code.replace("monthData.", "currentMonthData.")
code = code.replace("(monthData:", "(initialMonthData:")

# Replace the struct declaration and top properties
struct_decl = """struct TimetableView: View {
    @State private var currentMonthData: MonthPrayerData
    let initialMonthData: MonthPrayerData
    let mosqueName: String
    let mosqueSlug: String
    let timeTheme: HomeDesign.TimeTheme
    let model: HomeViewModel

    @State private var currentMonth: Int
    @State private var currentYear: Int
    @State private var isLoadingMonth = false

    @Environment(\\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(\\.locale) private var locale

    @State private var selectedDate: Int = 1

    init(initialMonthData: MonthPrayerData, mosqueName: String, mosqueSlug: String, timeTheme: HomeDesign.TimeTheme, model: HomeViewModel) {
        self.initialMonthData = initialMonthData
        self._currentMonthData = State(initialValue: initialMonthData)
        self.mosqueName = mosqueName
        self.mosqueSlug = mosqueSlug
        self.timeTheme = timeTheme
        self.model = model
        
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

    private var currentDayOfSystem: Int {"""

code = re.sub(r"struct TimetableView: View \{[\s\S]*?private var currentDayOfSystem: Int \{", struct_decl, code)

# Replace body
body_old = """    var body: some View {
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
                    .padding(.bottom, 32)

                dateStrip
                    .padding(.bottom, 40)

                if let currentPrayerTime = currentMonthData.prayerTimes.first(where: { $0.date == selectedDate }) {
                    prayersStack(for: currentPrayerTime)
                        .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            let today = currentDayOfSystem
            if currentMonthData.prayerTimes.contains(where: { $0.date == today }) {
                selectedDate = today
            } else if let first = currentMonthData.prayerTimes.first {
                selectedDate = first.date
            }
        }
    }"""

body_new = """    var body: some View {
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
        .onAppear {
            let today = currentDayOfSystem
            if currentMonthData.prayerTimes.contains(where: { $0.date == today }) {
                selectedDate = today
            } else if let first = currentMonthData.prayerTimes.first {
                selectedDate = first.date
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
    }"""

code = code.replace(body_old, body_new)

# Fix dateStrip proxy.scrollTo reference error if it triggers out of bounds
# Actually dateStrip already has ForEach(currentMonthData.prayerTimes, id: \.date). 
# We should probably update the ScrollView reader to scroll smoothly.

with open("Masjidly - Official Masjid Prayer Times/Features/Home/TimetableView.swift", "w") as f:
    f.write(code)
