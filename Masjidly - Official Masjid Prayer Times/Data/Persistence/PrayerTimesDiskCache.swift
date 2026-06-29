import Foundation

/// Atomic JSON file cache for prayer data stored in Application Support.
///
/// Layout:
/// ```
/// Application Support/PrayerTimesCache/
///   mosques.json
///   data_revision.json
///   uk_dst.json
///   monthly_{slug}_{month}_{year}.json
///   ramadan_{slug}_{date}.json
///   versions_{slug}_{month}_{year}.json
/// ```
@MainActor
final class PrayerTimesDiskCache: Sendable {
    private let fileManager: FileManager
    private let cacheDir: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = support.appendingPathComponent("PrayerTimesCache", isDirectory: true)
    }

    // MARK: - Helpers

    private func ensureCacheDir() throws {
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }

    /// Sanitize a string so it is safe as a filename component (no path separators, no dots).
    static func safe(_ component: String) -> String {
        component.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ".", with: "_")
    }

    private func url(for filename: String) -> URL {
        cacheDir.appendingPathComponent(filename, isDirectory: false)
    }

    /// Atomically write `data` to `url` via a temporary file + `replaceItemAt`.
    private func atomicWrite(data: Data, to url: URL) throws {
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".tmp_\(UUID().uuidString)", isDirectory: false)
        try data.write(to: tmp, options: .atomic)
        _ = try fileManager.replaceItemAt(url, withItemAt: tmp)
    }

    private func loadJSON<T: Decodable>(from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try ensureCacheDir()
        let data = try JSONEncoder().encode(value)
        try atomicWrite(data: data, to: url)
    }

    // MARK: - Mosques

    private static let mosquesFile = "mosques.json"

    func loadMosques() -> [Mosque]? {
        loadJSON(from: url(for: Self.mosquesFile))
    }

    func saveMosques(_ mosques: [Mosque]) throws {
        try saveJSON(mosques, to: url(for: Self.mosquesFile))
    }

    // MARK: - Data revision

    private static let dataRevisionFile = "data_revision.json"

    func loadDataRevision() -> DataRevision? {
        loadJSON(from: url(for: Self.dataRevisionFile))
    }

    func saveDataRevision(_ revision: DataRevision) throws {
        try saveJSON(revision, to: url(for: Self.dataRevisionFile))
    }

    // MARK: - UK DST

    private static let ukDstFile = "uk_dst.json"

    func loadUkDst() -> UkDstCalendar? {
        loadJSON(from: url(for: Self.ukDstFile))
    }

    func saveUkDst(_ dst: UkDstCalendar) throws {
        try saveJSON(dst, to: url(for: Self.ukDstFile))
    }

    // MARK: - Versions

    private static func versionsFilename(slug: String, month: String, year: Int) -> String {
        "versions_\(Self.safe(slug))_\(month)_\(year).json"
    }

    func loadVersions(slug: String, month: String, year: Int) -> CachedPrayerDataVersions? {
        loadJSON(from: url(for: Self.versionsFilename(slug: slug, month: month, year: year)))
    }

    func saveVersions(slug: String, month: String, year: Int, versions: PrayerDataVersions) throws {
        try saveJSON(CachedPrayerDataVersions(versions: versions, checkedAt: Date()), to: url(for: Self.versionsFilename(slug: slug, month: month, year: year)))
    }

    // MARK: - Monthly

    private static func monthlyFilename(slug: String, month: String, year: Int) -> String {
        "monthly_\(Self.safe(slug))_\(month)_\(year).json"
    }

    func loadMonthly(slug: String, month: String, year: Int) -> MonthPrayerData? {
        loadJSON(from: url(for: Self.monthlyFilename(slug: slug, month: month, year: year)))
    }

    func saveMonthly(slug: String, month: String, year: Int, data: MonthPrayerData) throws {
        try saveJSON(data, to: url(for: Self.monthlyFilename(slug: slug, month: month, year: year)))
    }

    func removeMonthly(slug: String, month: String, year: Int) {
        let fileURL = url(for: Self.monthlyFilename(slug: slug, month: month, year: year))
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Ramadan

    private static func ramadanFilename(slug: String, date: String) -> String {
        "ramadan_\(Self.safe(slug))_\(Self.safe(date)).json"
    }

    func loadRamadan(slug: String, date: String) -> RamadanPrayerData? {
        loadJSON(from: url(for: Self.ramadanFilename(slug: slug, date: date)))
    }

    func saveRamadan(slug: String, date: String, data: RamadanPrayerData) throws {
        try saveJSON(data, to: url(for: Self.ramadanFilename(slug: slug, date: date)))
    }
}
