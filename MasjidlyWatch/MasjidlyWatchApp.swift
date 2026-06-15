import SwiftUI

// MARK: - Watch Design System (mirrors HomeDesign from iOS)

private enum WD {
    static let accent = Color(hex: "47A6FF")
    static let accentDeep = Color(hex: "2E8DFF")
    static let accentGradient = LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)

    enum SkyTheme {
        case fajr, sunrise, dhuhr, asr, maghrib, isha

        var baseColors: [Color] {
            switch self {
            case .fajr:    [Color(hex: "020326"), Color(hex: "06114F"), Color(hex: "0B1E6D"), Color(hex: "3B2A5A")]
            case .sunrise: [Color(hex: "6B7280"), Color(hex: "C084FC"), Color(hex: "FB923C"), Color(hex: "F59E0B")]
            case .dhuhr:   [Color(hex: "E0F2FE"), Color(hex: "7DD3FC"), Color(hex: "38BDF8")]
            case .asr:     [Color(hex: "93C5FD"), Color(hex: "FDE68A"), Color(hex: "FDBA74")]
            case .maghrib: [Color(hex: "6D3FA9"), Color(hex: "A855F7"), Color(hex: "F472B6"), Color(hex: "FB7185")]
            case .isha:    [Color(hex: "000000"), Color(hex: "020617"), Color(hex: "0F172A")]
            }
        }
        var gradient: Gradient { Gradient(colors: baseColors) }

        var textColor: Color {
            switch self {
            case .fajr, .maghrib, .isha: return .white
            default: return Color(hex: "111111")
            }
        }
        var usesLightForeground: Bool {
            switch self {
            case .fajr, .maghrib, .isha: return true
            default: return false
            }
        }
        var glassBackground: Color { usesLightForeground ? .white.opacity(0.12) : .white.opacity(0.22) }
        var glassBorder: Color { usesLightForeground ? .white.opacity(0.15) : .white.opacity(0.28) }
        var secondaryText: Color { textColor.opacity(0.6) }
        var tertiaryText: Color { textColor.opacity(0.4) }
        var rowBackground: Color { usesLightForeground ? .white.opacity(0.08) : .white.opacity(0.14) }

        static func from(prayerName: String) -> SkyTheme {
            switch prayerName.lowercased() {
            case "fajr": return .fajr
            case "sunrise", "shurooq": return .sunrise
            case "dhuhr", "jummah": return .dhuhr
            case "asr": return .asr
            case "maghrib": return .maghrib
            case "isha": return .isha
            default: return .dhuhr
            }
        }
    }
}

// MARK: - App Entry

@main
struct MasjidlyWatchApp: App {
    @State private var store = WatchPrayerStore()

    var body: some Scene {
        WindowGroup {
            WatchPrayerDashboard(store: store)
                .task { store.activate() }
        }
    }
}

// MARK: - Main Dashboard

struct WatchPrayerDashboard: View {
    @Bindable var store: WatchPrayerStore

    private var theme: WD.SkyTheme {
        WD.SkyTheme.from(prayerName: store.state.prayerName)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch store.state.kind {
                case .content: contentView
                case .missing:  setupView
                case .stale:    unavailableView
                }
            }
        }
    }

    // MARK: - Content View (swipeable pages, sky-theme, size-adaptive)

    private var contentView: some View {
        ZStack {
            LinearGradient(gradient: theme.gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width

                // Responsive sizing
                let heroTimeSz   = max(40, min(60, w * 0.16))
                let heroNameSz   = max(20, min(28, w * 0.075))
                let mosqueNameSz = max(10, min(13, w * 0.034))
                let badgeSz      = max(9,  min(13, w * 0.032))
                let labelSz      = max(13, min(17, w * 0.045))
                let dotSz        = max(4,  min(7,  w * 0.018))
                let rowHPad      = max(8,  min(14, w * 0.035))
                let rowVPad      = max(6,  min(10, w * 0.022))
                let rowCorner    = max(10, min(14, w * 0.038))
                let rowVS        = max(5,  min(8,  w * 0.018))
                let pagePad      = max(8,  min(14, w * 0.035))

                TabView {
                    // ─── Page 1: Next Prayer ───
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: max(2, w * 0.008)) {
                            Text(store.state.mosqueName)
                                .font(.system(size: mosqueNameSz, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)

                            Text(store.state.prayerName)
                                .font(.system(size: heroNameSz, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.textColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(store.state.adhanTime)
                                .font(.system(size: heroTimeSz, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.textColor)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)

                            HStack(spacing: max(6, w * 0.02)) {
                                Label(store.state.isIqamah ? "Iqamah" : "Adhan", systemImage: store.state.isIqamah ? "bell.badge.fill" : "bell.fill")
                                    .font(.system(size: badgeSz, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.secondaryText)

                                if !store.state.iqamahTime.isEmpty {
                                    Text("Iqamah \(store.state.iqamahTime)")
                                        .font(.system(size: badgeSz, weight: .regular, design: .rounded))
                                        .foregroundStyle(theme.tertiaryText)
                                }
                            }
                        }
                        .padding(.horizontal, pagePad + 4)

                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, max(8, w * 0.025))
                    .accessibilityLabel("\(store.state.mosqueName), \(store.state.prayerName) at \(store.state.adhanTime)")
                    .tag(0)

                    // ─── Page 2: All Prayer Times ───
                    ScrollView {
                        VStack(spacing: rowVS) {
                            ForEach(store.state.rows) { row in
                                HStack(spacing: max(4, w * 0.016)) {
                                    Circle()
                                        .fill(row.isNext ? WD.accent : .clear)
                                        .frame(width: dotSz, height: dotSz)
                                        .overlay(Circle().stroke(row.isPassed ? theme.tertiaryText : theme.secondaryText, lineWidth: row.isNext ? 0 : 1))

                                    Text(row.name)
                                        .font(.system(size: labelSz, weight: row.isNext ? .bold : .regular, design: .rounded))
                                        .foregroundStyle(row.isPassed ? theme.tertiaryText : theme.textColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)

                                    Spacer(minLength: 2)

                                    Text(row.adhan)
                                        .font(.system(size: labelSz, weight: row.isNext ? .bold : .regular, design: .rounded))
                                        .foregroundStyle(row.isNext ? WD.accent : theme.textColor.opacity(row.isPassed ? 0.4 : 0.8))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .padding(.horizontal, rowHPad)
                                .padding(.vertical, rowVPad)
                                .background(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).fill(row.isNext ? WD.accent.opacity(0.12) : theme.rowBackground))
                                .overlay(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).stroke(row.isNext ? WD.accent.opacity(0.2) : theme.glassBorder, lineWidth: 0.5))
                            }
                        }
                        .padding(.horizontal, pagePad)
                        .padding(.vertical, max(6, w * 0.018))
                    }
                    .accessibilityLabel("All prayer times")
                    .tag(1)

                    // ─── Page 3: Settings ───
                    ScrollView {
                        VStack(alignment: .leading, spacing: max(8, w * 0.024)) {
                            VStack(alignment: .leading, spacing: max(2, w * 0.008)) {
                                Text("Settings")
                                    .font(.system(size: max(17, min(22, w * 0.058)), weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.textColor)
                                    .lineLimit(1)

                                Text("Choose what the watch shows")
                                    .font(.system(size: max(10, min(13, w * 0.034)), weight: .regular, design: .rounded))
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            currentMosqueSettingsCard(
                                w: w,
                                rowHPad: rowHPad,
                                rowVPad: rowVPad,
                                rowCorner: rowCorner
                            )

                            VStack(spacing: rowVS) {
                                settingsButton(
                                    icon: "globe",
                                    label: "Change country",
                                    w: w, rowHPad: rowHPad, rowVPad: rowVPad, rowCorner: rowCorner
                                ) {
                                    store.goToChangeCountry()
                                }

                                settingsButton(
                                    icon: "building.2",
                                    label: "Change city",
                                    w: w, rowHPad: rowHPad, rowVPad: rowVPad, rowCorner: rowCorner
                                ) {
                                    store.goToChangeCity()
                                }

                                settingsButton(
                                    icon: "building.columns.fill",
                                    label: "Change mosque",
                                    w: w, rowHPad: rowHPad, rowVPad: rowVPad, rowCorner: rowCorner
                                ) {
                                    store.goToChangeMosque()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, pagePad)
                        .padding(.top, max(8, w * 0.024))
                        .padding(.bottom, max(10, w * 0.03))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .accessibilityLabel("Settings")
                    .tag(2)
                }
                .tabViewStyle(.page)
                .overlay {
                    if store.isRefreshing {
                        ProgressView().tint(theme.textColor).controlSize(.small)
                            .padding(max(6, w * 0.02))
                            .background(RoundedRectangle(cornerRadius: max(8, w * 0.025), style: .continuous).fill(theme.glassBackground))
                    }
                }
            }
        }
        .preferredColorScheme(theme.usesLightForeground ? .dark : .light)
    }

    // MARK: - Setup Picker (full-screen, compact)

    private var setupView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let rowFontSz  = max(14, min(18, w * 0.048))
            let detailSz   = max(10, min(13, w * 0.034))
            let iconSz     = max(12, min(15, w * 0.04))
            let rowHPad    = max(10, min(16, w * 0.04))
            let rowVPad    = max(10, min(14, w * 0.035))
            let corner     = max(12, min(16, w * 0.042))
            let rowVS      = max(6,  min(10, w * 0.024))

            ZStack {
                LinearGradient(colors: [WD.accent.opacity(0.15), WD.accentDeep.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                if store.isRefreshing || store.isLoadingMosques {
                    VStack(spacing: max(8, w * 0.025)) {
                        ProgressView().tint(WD.accent)
                        Text(store.isRefreshing ? "Downloading prayer times…" : "Loading mosques…")
                            .font(.system(size: detailSz, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else if store.mosqueOptions.isEmpty, store.setupError == nil, store.setupPhase == .loading {
                    // Internet prompt — centered
                    VStack(spacing: max(8, w * 0.03)) {
                        Spacer()
                        Image(systemName: "wifi").font(.system(size: max(24, w * 0.065))).foregroundStyle(WD.accent)
                        Text("Connect to internet")
                            .font(.system(size: max(15, w * 0.042), weight: .semibold, design: .rounded))
                        Button("Load mosques") { store.loadMosques() }
                            .buttonStyle(.borderedProminent).tint(WD.accent)
                        Spacer()
                    }
                } else {
                    // Full-screen picker layout
                    VStack(spacing: 0) {
                        // Title bar
                        Text(headerTitle)
                            .font(.system(size: max(15, w * 0.045), weight: .semibold, design: .rounded))
                            .foregroundStyle(WD.accentGradient)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, rowHPad)
                            .padding(.vertical, max(6, w * 0.018))

                        // Error
                        if let error = store.setupError {
                            errorCard(error, w: w, detailSz: detailSz)
                                .padding(.horizontal, rowHPad)
                        }

                        // Scrollable picker rows — fills remaining space
                        ScrollView {
                            VStack(spacing: rowVS) {
                                switch store.setupPhase {
                                case .loading: EmptyView()
                                case .pickCountry: countryContent(w: w, rowFontSz: rowFontSz, iconSz: iconSz, rowHPad: rowHPad, rowVPad: rowVPad, cr: corner)
                                case .pickCity:     cityContent(w: w, rowFontSz: rowFontSz, iconSz: iconSz, rowHPad: rowHPad, rowVPad: rowVPad, cr: corner)
                                case .pickMosque:   mosqueContent(w: w, rowFontSz: rowFontSz, detailSz: detailSz, rowHPad: rowHPad, rowVPad: rowVPad, cr: corner)
                                }
                            }
                            .padding(.horizontal, rowHPad)
                            .padding(.vertical, max(4, w * 0.01))
                        }

                        // Back button pinned at bottom
                        Group {
                            switch store.setupPhase {
                            case .loading, .pickCountry: EmptyView()
                            case .pickCity:  backBtn("Change country", w: w, backFontSz: detailSz, hPad: rowHPad, action: store.goToCountryPicker)
                            case .pickMosque: backBtn("Change city",   w: w, backFontSz: detailSz, hPad: rowHPad, action: store.goToCityPicker)
                            }
                        }
                        .padding(.horizontal, rowHPad)
                        .padding(.bottom, max(6, w * 0.018))
                    }
                }
            }
        }
    }

    private var headerTitle: String {
        switch store.setupPhase {
        case .loading: return ""
        case .pickCountry: return "Select country"
        case .pickCity: return "Select city"
        case .pickMosque: return "Select mosque"
        }
    }

    // MARK: - Picker Content Builders

    private func countryContent(w: CGFloat, rowFontSz: CGFloat, iconSz: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, cr: CGFloat) -> some View {
        ForEach(store.countryKeys, id: \.self) { key in
            pickerRow(
                icon: "globe", iconSz: iconSz,
                label: countryLabel(for: key),
                labelSz: rowFontSz,
                w: w, rowHPad: rowHPad, rowVPad: rowVPad, cr: cr,
                action: { store.selectCountry(key) }
            )
        }
    }

    private func cityContent(w: CGFloat, rowFontSz: CGFloat, iconSz: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, cr: CGFloat) -> some View {
        ForEach(store.cityKeys, id: \.self) { key in
            pickerRow(
                icon: "building.2", iconSz: iconSz,
                label: cityLabel(for: key),
                labelSz: rowFontSz,
                w: w, rowHPad: rowHPad, rowVPad: rowVPad, cr: cr,
                action: { store.selectCity(key) }
            )
        }
    }

    private func mosqueContent(w: CGFloat, rowFontSz: CGFloat, detailSz: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, cr: CGFloat) -> some View {
        ForEach(store.mosquesInCity) { mosque in
            Button { store.selectMosque(mosque) } label: {
                HStack(spacing: max(6, w * 0.024)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mosque.name)
                            .font(.system(size: rowFontSz, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if !mosque.address.isEmpty {
                            Text(mosque.address)
                                .font(.system(size: detailSz, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: max(8, w * 0.025), weight: .semibold))
                        .foregroundStyle(WD.accent.opacity(0.5))
                }
                .responsiveRow(rowHPad: rowHPad, rowVPad: rowVPad, cr: cr, accent: WD.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shared Picker Row

    private func pickerRow(icon: String, iconSz: CGFloat, label: String, labelSz: CGFloat, w: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, cr: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: max(6, w * 0.024)) {
                Image(systemName: icon)
                    .font(.system(size: iconSz))
                    .foregroundStyle(WD.accentGradient)
                    .frame(width: iconSz * 1.6)
                Text(label)
                    .font(.system(size: labelSz, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: max(8, w * 0.025), weight: .semibold))
                    .foregroundStyle(WD.accent.opacity(0.5))
            }
            .responsiveRow(rowHPad: rowHPad, rowVPad: rowVPad, cr: cr, accent: WD.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func currentMosqueSettingsCard(w: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, rowCorner: CGFloat) -> some View {
        HStack(spacing: max(6, w * 0.024)) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: max(12, w * 0.036), weight: .semibold))
                .foregroundStyle(WD.accent)
                .frame(width: max(18, w * 0.05))

            VStack(alignment: .leading, spacing: 2) {
                Text("Current mosque")
                    .font(.system(size: max(9, min(12, w * 0.032)), weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Text(store.state.mosqueName)
                    .font(.system(size: max(12, w * 0.036), weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 2)
        }
        .padding(.horizontal, rowHPad)
        .padding(.vertical, max(rowVPad, w * 0.028))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).fill(theme.glassBackground))
        .overlay(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).stroke(theme.glassBorder, lineWidth: 0.5))
    }

    private func settingsButton(icon: String, label: String, w: CGFloat, rowHPad: CGFloat, rowVPad: CGFloat, rowCorner: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: max(6, w * 0.024)) {
                Image(systemName: icon)
                    .font(.system(size: max(12, w * 0.036), weight: .semibold))
                    .foregroundStyle(WD.accent)
                    .frame(width: max(18, w * 0.05))
                Text(label)
                    .font(.system(size: max(13, w * 0.038), weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: max(8, w * 0.025), weight: .semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .padding(.horizontal, rowHPad)
            .padding(.vertical, rowVPad)
            .frame(maxWidth: .infinity, minHeight: max(38, w * 0.105), alignment: .leading)
            .background(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).fill(theme.rowBackground))
            .overlay(RoundedRectangle(cornerRadius: rowCorner, style: .continuous).stroke(theme.glassBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func errorCard(_ message: String, w: CGFloat, detailSz: CGFloat) -> some View {
        VStack(spacing: max(4, w * 0.014)) {
            Text(message)
                .font(.system(size: detailSz, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") { store.loadMosques() }
                .font(.system(size: detailSz, weight: .semibold))
                .buttonStyle(.borderedProminent).tint(WD.accent)
        }
        .padding(max(8, w * 0.035))
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: max(10, w * 0.035), style: .continuous).fill(.red.opacity(0.08)))
    }

    private func backBtn(_ title: String, w: CGFloat, backFontSz: CGFloat, hPad: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: max(4, w * 0.014)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: max(8, w * 0.025), weight: .semibold))
                Text(title)
                    .font(.system(size: backFontSz, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(WD.accent)
            .padding(.horizontal, hPad)
            .padding(.vertical, max(6, w * 0.02))
            .background(RoundedRectangle(cornerRadius: max(8, w * 0.025), style: .continuous).fill(WD.accent.opacity(0.10)))
        }
    }

    private var unavailableView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(spacing: max(8, w * 0.03)) {
                Image(systemName: "applewatch.and.arrow.forward")
                    .font(.system(size: max(18, w * 0.055)))
                    .foregroundStyle(WD.accent)
                Text("Refresh needed")
                    .font(.system(size: max(14, w * 0.04), weight: .semibold, design: .rounded))
                Text("Connect to the internet to refresh prayer times.")
                    .font(.system(size: max(10, w * 0.03), design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(w * 0.04)
            .frame(width: geo.size.width)
        }
    }

    // MARK: - Labels

    private func countryLabel(for key: String) -> String {
        store.mosqueOptions.first { $0.countryGroupingKey == key }?.countryDisplayName ?? key
    }

    private func cityLabel(for key: String) -> String {
        store.mosquesInCountry.first { $0.cityGroupingKey == key }?.cityDisplayName ?? key
    }
}

// MARK: - Responsive Row Modifier

private extension View {
    @ViewBuilder
    func responsiveRow(rowHPad: CGFloat, rowVPad: CGFloat, cr: CGFloat, accent: Color) -> some View {
        self
            .padding(.horizontal, rowHPad)
            .padding(.vertical, rowVPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: cr, style: .continuous).fill(accent.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).stroke(accent.opacity(0.20), lineWidth: 0.5))
    }
}

// MARK: - Color Hex

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(red: Double((rgb & 0xFF0000) >> 16) / 255,
                  green: Double((rgb & 0x00FF00) >> 8) / 255,
                  blue: Double(rgb & 0x0000FF) / 255)
    }
}
