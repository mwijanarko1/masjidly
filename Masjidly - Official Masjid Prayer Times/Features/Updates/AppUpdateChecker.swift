import Foundation

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

    /// Returns the current app version and build
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var currentBuild: Int {
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return Int(raw) ?? 1
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
    /// On iOS, compares the build number against the manifest's iOS build number.
    static func checkForUpdate() async -> AppUpdateStatus {
        guard let release = await fetchLatestRelease() else {
            return .checkFailed("Could not reach version server.")
        }

        // Compare iOS build numbers
        let current = currentBuild
        if release.ios.build > current {
            return .updateAvailable(release: release)
        }

        return .upToDate
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
