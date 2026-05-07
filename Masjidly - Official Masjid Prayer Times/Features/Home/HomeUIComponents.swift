import SwiftUI

// MARK: - Components

struct StatusChip: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .foregroundColor(Color(hex: "58D66D"))
            Circle()
                .fill(Color(hex: "58D66D"))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: "58D66D").opacity(0.5), radius: 3)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }
}

struct HeroIllustration: View {
    /// Next salat name from `NextPrayerCountdownResult.nextName` (e.g. Fajr, Dhuhr, Jummah, Asr).
    let nextPrayerName: String

    private var assetName: String {
        switch nextPrayerName {
        case "Fajr": "FajrIllustration"
        case "Dhuhr", "Jummah": "DhuhrIllustration"
        case "Asr": "AsrIllustration"
        case "Maghrib": "MaghribIllustration"
        case "Isha": "IshaIllustration"
        default: "FajrIllustration"
        }
    }

    private var accessibilityLabelText: String {
        switch nextPrayerName {
        case "Fajr": "Fajr illustration"
        case "Dhuhr": "Dhuhr illustration"
        case "Jummah": "Jummah illustration"
        case "Asr": "Asr illustration"
        case "Maghrib": "Maghrib illustration"
        case "Isha": "Isha illustration"
        default: "Prayer illustration"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 200, height: 160)
            .accessibilityLabel(accessibilityLabelText)
            .frame(height: 200)
    }
}

struct HeroContent: View {
    let prayerName: String
    let prayerTime: String
    let countdown: String
    let gregorianDate: String
    let hijriDate: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Main Time
            Text(prayerTime)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundColor(HomeDesign.Colors.primary)
            
            Text(prayerName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(HomeDesign.Colors.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

struct QuickInfoItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(HomeDesign.Colors.primary)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(HomeDesign.Colors.primary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HomeDesign.Colors.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(24)
        .customShadow(HomeDesign.Shadows.softCard)
    }
}

struct PrayerCarouselItem: View {
    let name: String
    let time: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(time)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.primary)
            
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.accent)
                .symbolVariant(.fill)
            
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.secondary)
        }
        .frame(width: 80, height: 110)
        .background(
            ZStack {
                if isSelected {
                    HomeDesign.Colors.activeGradient
                        .customShadow(HomeDesign.Shadows.intenseGlow)
                } else {
                    Color.white
                }
            }
        )
        .cornerRadius(24)
        .customShadow(isSelected ? Shadow(color: .clear, radius: 0, x: 0, y: 0) : HomeDesign.Shadows.softCard)
    }
}

// MARK: - Utilities

enum DateUtils {
    static func hijriDateString(for date: Date) -> String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamicCalendar
        formatter.dateFormat = "d MMMM yyyy 'AH'"
        return formatter.string(from: date)
    }
    
    static func currentLocalTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
