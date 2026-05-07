import SwiftUI

struct TimetableView: View {
    let monthData: MonthPrayerData
    let mosqueName: String
    let timeTheme: HomeDesign.TimeTheme

    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    private enum Layout {
        static let horizontalInset: CGFloat = 24
        static let cardPadding: CGFloat = 16
        static let headerIconCol: CGFloat = 45
        static let headerPrayerCol: CGFloat = 55
    }

    private var primaryTextColor: Color {
        timeTheme == .weather ? HomeDesign.Colors.primary : .white
    }

    private var secondaryTextColor: Color {
        timeTheme == .weather ? HomeDesign.Colors.secondary : .white.opacity(0.7)
    }

    private var dividerColor: Color {
        timeTheme == .weather ? Color.black.opacity(0.08) : Color.white.opacity(0.12)
    }

    private var cardBackground: some View {
        ZStack {
            if timeTheme == .weather {
                Color.white
            } else {
                Color(hex: "0A1220").opacity(0.85)
                HomeDesign.Colors.glassBackground.opacity(0.1)
            }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: timeTheme.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(timeTheme.glowColor)
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -100, y: -140)

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, Layout.horizontalInset)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                timetableCard
                    .padding(.horizontal, Layout.horizontalInset)
                    .padding(.bottom, 24)
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthData.month.capitalized)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                Text(mosqueName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(secondaryTextColor)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primaryTextColor.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(HomeDesign.Colors.glassBackground))
                    .overlay(
                        Circle()
                            .stroke(HomeDesign.Colors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close timetable"))
        }
    }

    private var timetableCard: some View {
        VStack(spacing: 0) {
            columnHeaders
                .padding(.horizontal, Layout.cardPadding)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.15))

            Divider()
                .background(dividerColor)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(monthData.prayerTimes.enumerated()), id: \.element.date) { index, time in
                        row(for: time)
                            .padding(.horizontal, Layout.cardPadding)
                            .frame(minHeight: 44)

                        if index < monthData.prayerTimes.count - 1 {
                            Divider()
                                .background(dividerColor)
                                .padding(.leading, Layout.cardPadding)
                        }
                    }
                }
            }
        }
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HomeDesign.Colors.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .customShadow(HomeDesign.Shadows.warmGlow)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            headerCell("Date", width: Layout.headerIconCol)
            headerCell("Fajr", width: Layout.headerPrayerCol)
            headerCell("Shu", width: Layout.headerPrayerCol)
            headerCell("Dhu", width: Layout.headerPrayerCol)
            headerCell("Asr", width: Layout.headerPrayerCol)
            headerCell("Mag", width: Layout.headerPrayerCol)
            headerCell("Ish", width: Layout.headerPrayerCol)
        }
    }

    private func row(for time: PrayerTime) -> some View {
        HStack(spacing: 0) {
            rowCell("\(time.date)", width: Layout.headerIconCol, emphasis: .primary)
            rowCell(formatTime(time.fajr), width: Layout.headerPrayerCol)
            rowCell(formatTime(time.shurooq), width: Layout.headerPrayerCol)
            rowCell(formatTime(time.dhuhr), width: Layout.headerPrayerCol)
            rowCell(formatTime(time.asr), width: Layout.headerPrayerCol)
            rowCell(formatTime(time.maghrib), width: Layout.headerPrayerCol)
            rowCell(formatTime(time.isha), width: Layout.headerPrayerCol)
        }
    }

    private func formatTime(_ t: String) -> String {
        settings.uses24HourTime ? t : PrayerTimesEngine.formatTo12Hour(t)
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(secondaryTextColor.opacity(0.7))
            .frame(width: width, alignment: .leading)
    }

    private enum CellEmphasis {
        case primary
        case secondary
    }

    private func rowCell(_ text: String, width: CGFloat, emphasis: CellEmphasis = .secondary) -> some View {
        Text(text)
            .font(.system(size: 15, weight: emphasis == .primary ? .semibold : .regular))
            .foregroundStyle(emphasis == .primary ? primaryTextColor : primaryTextColor.opacity(0.9))
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

#Preview {
    TimetableView(
        monthData: MonthPrayerData(
            month: "May 2026",
            prayerTimes: [
                PrayerTime(date: 1, fajr: "03:45", shurooq: "05:20", dhuhr: "13:05", asr: "17:15", maghrib: "20:45", isha: "22:15"),
                PrayerTime(date: 2, fajr: "03:43", shurooq: "05:18", dhuhr: "13:05", asr: "17:16", maghrib: "20:47", isha: "22:17")
            ],
            iqamahTimes: [],
            jummahIqamah: "13:15"
        ),
        mosqueName: "Madina Masjid",
        timeTheme: .dusk
    )
    .environment(SettingsStore())
}
