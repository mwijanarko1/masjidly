import Foundation
import UIKit

// MARK: - Release Manifest Models

struct MasjidlyRelease: Codable, Equatable {
    let android: AndroidRelease
    let ios: IOSRelease
    let pubDate: String
    let notes: LocalizedNotes

    enum CodingKeys: String, CodingKey {
        case android, ios
        case pubDate = "pub_date"
        case notes
    }
}

struct AndroidRelease: Codable, Equatable {
    let version: String
    let versionCode: Int
    let url: String
    let sha256: String
    let minVersionCode: Int
}

struct IOSRelease: Codable, Equatable {
    let version: String
    let build: Int
    let appStoreUrl: String
}

struct LocalizedNotes: Codable, Equatable {
    let en: String
    let ar: String
    let ur: String
    let id: String
}

// MARK: - Update Result

enum AppUpdateStatus: Equatable {
    /// No update available — app is current
    case upToDate
    /// A newer version is available
    case updateAvailable(release: MasjidlyRelease)
    /// Failed to check (network error, parse error, etc.)
    case checkFailed(String)
}

// MARK: - App Update Checker

/// Checks `latest.json` from the website to see if a newer version of Masjidly
/// is available.
final class AppUpdateChecker {

    private static let latestJsonUrl = URL(string: "https://sheffieldmasjids.com/masjidly/latest.json")!
    private static let timeout: TimeInterval = 10

    // MARK: - Public API

    /// Returns the current marketing version (CFBundleShortVersionString), e.g. "1.1.1".
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Fetches the latest release manifest from the website.
    /// Returns `nil` on network or parse failure.
    static func fetchLatestRelease() async -> MasjidlyRelease? {
        var request = URLRequest(url: latestJsonUrl, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(MasjidlyRelease.self, from: data)
    }

    /// Checks whether a newer version is available for the current platform.
    /// On iOS, compares the marketing version (`CFBundleShortVersionString`) against
    /// the manifest's `ios.version`. Build numbers are ignored.
    static func checkForUpdate() async -> AppUpdateStatus {
        guard let release = await fetchLatestRelease() else {
            return .checkFailed("Could not reach version server.")
        }

        if isVersion(release.ios.version, newerThan: currentVersion) {
            return .updateAvailable(release: release)
        }

        return .upToDate
    }

    /// Numeric dotted-version comparison for values like "1", "1.1", "1.1.1".
    /// Missing components are treated as zero, so "1.2" equals "1.2.0".
    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = numericVersionParts(candidate)
        let currentParts = numericVersionParts(current)
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let candidateValue = index < candidateParts.count ? candidateParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if candidateValue > currentValue { return true }
            if candidateValue < currentValue { return false }
        }

        return false
    }

    private static func numericVersionParts(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let numericPrefix = part.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }

    /// Opens the App Store page for Masjidly.
    static func openAppStore() {
        guard let url = URL(string: "https://apps.apple.com/gb/app/masjidly-masjid-prayer-times/id6767841833") else {
            return
        }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}
