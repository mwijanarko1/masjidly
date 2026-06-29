import Foundation
import Observation
import WatchConnectivity

private enum WatchPrayerConfig {
    static let snapshotDefaultsKey = "widgetPrayerSnapshot.v1.data"
    static let selectedMosqueDefaultsKey = "watchSelectedMosque.v1"
    static let snapshotPayloadKey = "widgetPrayerSnapshot.v1.data"
    static let snapshotRequestKey = "widgetPrayerSnapshot.v1.request"
    static let sheffieldTimeZone = TimeZone(identifier: "Europe/London") ?? .current
    static let directRefreshDays = 7

    static var convexDeploymentURL: URL {
        #if DEBUG
        URL(string: "https://upbeat-goat-583.eu-west-1.convex.cloud")!
        #else
        URL(string: "https://zany-mockingbird-207.eu-west-1.convex.cloud")!
        #endif
    }
}

struct WatchMosqueSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
}

struct WatchMosqueOption: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let slug: String
    let citySlug: String?
    let cityName: String?
    let countryCode: String?
    let countryName: String?
    let isHidden: Bool?

    var isVisible: Bool { !(isHidden ?? false) }
    var snapshot: WatchMosqueSnapshot { WatchMosqueSnapshot(id: id, name: name, slug: slug) }

    var cityGroupingKey: String {
        if let s = citySlug, !s.isEmpty { return "slug:\(s)" }
        let label = cityName ?? ""
        return "name:\(label.lowercased())"
    }

    var countryGroupingKey: String {
        let code = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return code.isEmpty ? "unknown" : code.uppercased()
    }

    var countryDisplayName: String { countryName ?? countryCode ?? "Other" }
    var cityDisplayName: String { cityName ?? "City" }
}

struct WatchPrayerDaySnapshot: Codable, Equatable, Sendable {
    let date: String
    let prayers: WatchDailyPrayerTimes
    let iqamah: WatchDailyIqamahTimes
}

struct WatchPrayerSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let mosque: WatchMosqueSnapshot
    let days: [WatchPrayerDaySnapshot]
    let uses24HourTime: Bool
    let appLanguageRawValue: String
    let asrIqamahPreference: String?
}

struct WatchDailyPrayerTimes: Codable, Equatable, Sendable {
    var date: String
    var fajr: String
    var sunrise: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
}

struct WatchDailyIqamahTimes: Codable, Equatable, Sendable {
    var fajr: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
    var jummah: String
}

struct WatchPrayerRow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let adhan: String
    let isPassed: Bool
    let isNext: Bool
}

enum WatchPrayerStateKind: Equatable, Sendable {
    case content
    case missing
    case stale
}

struct WatchPrayerState: Equatable, Sendable {
    let kind: WatchPrayerStateKind
    let mosqueName: String
    let prayerName: String
    let adhanTime: String
    let iqamahTime: String
    let isIqamah: Bool
    let rows: [WatchPrayerRow]

    static let missing = WatchPrayerState(kind: .missing, mosqueName: "Masjidly", prayerName: "Open Masjidly", adhanTime: "--:--", iqamahTime: "", isIqamah: false, rows: [])
    static let stale = WatchPrayerState(kind: .stale, mosqueName: "Masjidly", prayerName: "Refresh needed", adhanTime: "--:--", iqamahTime: "", isIqamah: false, rows: [])

    var accessibilityLabel: String {
        "\(mosqueName), \(prayerName), \(isIqamah ? "iqamah" : "adhan") \(adhanTime)"
    }
}

@Observable
final class WatchPrayerStore: NSObject, WCSessionDelegate {
    private(set) var state: WatchPrayerState = .missing
    private(set) var mosqueOptions: [WatchMosqueOption] = []
    private(set) var countryKeys: [String] = []
    private(set) var cityKeys: [String] = []
    private(set) var selectedCountryKey: String = ""
    private(set) var selectedCityKey: String = ""
    private(set) var mosquesInCountry: [WatchMosqueOption] = []
    private(set) var mosquesInCity: [WatchMosqueOption] = []
    private(set) var isLoadingMosques = false
    private(set) var isRefreshing = false
    private(set) var setupError: String?
    private(set) var setupPhase: WatchSetupPhase = .loading

    enum WatchSetupPhase: Equatable, Sendable {
        case loading
        case pickCountry
        case pickCity
        case pickMosque
    }

    private let decoder = JSONDecoder()
    private let defaults: UserDefaults
    private let directRefreshService = WatchDirectPrayerRefreshService()
    private var pendingSetupPhaseAfterMosques: WatchSetupPhase?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        reloadFromDisk()
    }

    func activate() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            requestSnapshotFromPhone()
        }

        refreshDirectlyFromNetwork()
        if state.kind == .missing {
            loadMosques()
        }
    }

    private func requestSnapshotFromPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let request = [WatchPrayerConfig.snapshotRequestKey: true]
        session.sendMessage(request) { [weak self] reply in
            guard let data = reply[WatchPrayerConfig.snapshotPayloadKey] as? Data else { return }
            Task { @MainActor in
                self?.persistSnapshotData(data)
            }
        } errorHandler: { _ in
            // Best effort only. The iPhone app will also push application context
            // when it launches or refreshes prayer data.
        }
    }

    func reloadFromDisk(now: Date = Date()) {
        guard let data = defaults.data(forKey: WatchPrayerConfig.snapshotDefaultsKey),
              let snapshot = try? decoder.decode(WatchPrayerSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else {
            state = .missing
            if setupPhase == .loading, !mosqueOptions.isEmpty {
                setupPhase = .pickCountry
            }
            return
        }
        state = WatchPrayerResolver.resolve(snapshot: snapshot, now: now)
    }

    private func persistSnapshotData(_ data: Data) {
        defaults.set(data, forKey: WatchPrayerConfig.snapshotDefaultsKey)
        if let snapshot = try? decoder.decode(WatchPrayerSnapshot.self, from: data) {
            persistSelectedMosque(snapshot.mosque)
        }
        reloadFromDisk()
        setupPhase = .pickCountry
    }

    func loadMosques(targetPhase: WatchSetupPhase = .pickCountry) {
        if isLoadingMosques {
            pendingSetupPhaseAfterMosques = targetPhase
            return
        }
        pendingSetupPhaseAfterMosques = targetPhase
        isLoadingMosques = true
        setupError = nil
        setupPhase = .loading

        Task { [weak self, directRefreshService] in
            do {
                let all = try await directRefreshService.listMosques()
                    .filter(\.isVisible)
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                await MainActor.run {
                    guard let self else { return }
                    self.mosqueOptions = all
                    self.countryKeys = self.computeCountryKeys(from: all)
                    self.configureSelectionForLoadedMosques()
                    self.isLoadingMosques = false
                    self.setupPhase = self.availableSetupPhase(self.pendingSetupPhaseAfterMosques ?? .pickCountry)
                    self.pendingSetupPhaseAfterMosques = nil
                }
            } catch {
                await MainActor.run {
                    self?.isLoadingMosques = false
                    self?.setupPhase = .pickCountry
                    self?.setupError = "Could not load mosques. Check internet and try again."
                    self?.pendingSetupPhaseAfterMosques = nil
                }
            }
        }
    }

    func selectCountry(_ key: String) {
        selectedCountryKey = key
        updateCountry()
        setupPhase = .pickCity
    }

    func selectCity(_ key: String) {
        selectedCityKey = key
        updateCity()
        setupPhase = .pickMosque
    }

    func selectMosque(_ mosque: WatchMosqueOption) {
        persistSelectedMosque(mosque.snapshot)
        isRefreshing = true
        setupError = nil

        Task { [weak self, directRefreshService] in
            do {
                let snapshot = try await directRefreshService.refreshSnapshot(for: mosque.snapshot, basedOn: nil)
                let data = try JSONEncoder().encode(snapshot)
                await MainActor.run {
                    self?.isRefreshing = false
                    self?.persistSnapshotData(data)
                }
            } catch {
                await MainActor.run {
                    self?.isRefreshing = false
                    self?.setupError = "Could not download prayer times. Try again."
                }
            }
        }
    }

    func goToCountryPicker() {
        setupPhase = .pickCountry
    }

    func goToCityPicker() {
        setupPhase = .pickCity
    }

    func goToChangeCountry() {
        state = .missing
        guard !mosqueOptions.isEmpty else {
            loadMosques(targetPhase: .pickCountry)
            return
        }
        countryKeys = computeCountryKeys(from: mosqueOptions)
        if selectedCountryKey.isEmpty {
            selectedCountryKey = countryKeys.first ?? ""
        }
        updateCountry()
        setupPhase = .pickCountry
    }

    func goToChangeCity() {
        state = .missing
        guard !mosqueOptions.isEmpty else {
            loadMosques(targetPhase: .pickCity)
            return
        }
        guard let currentMosque = findCurrentMosqueOption() else {
            goToChangeCountry()
            return
        }
        countryKeys = computeCountryKeys(from: mosqueOptions)
        selectedCountryKey = currentMosque.countryGroupingKey
        updateCountry()
        setupPhase = .pickCity
    }

    func goToChangeMosque() {
        state = .missing
        guard !mosqueOptions.isEmpty else {
            loadMosques(targetPhase: .pickMosque)
            return
        }
        guard let currentMosque = findCurrentMosqueOption() else {
            goToChangeCountry()
            return
        }
        countryKeys = computeCountryKeys(from: mosqueOptions)
        selectedCountryKey = currentMosque.countryGroupingKey
        updateCountry()
        selectedCityKey = currentMosque.cityGroupingKey
        updateCity()
        setupPhase = .pickMosque
    }

    private func findCurrentMosqueOption() -> WatchMosqueOption? {
        guard let data = defaults.data(forKey: WatchPrayerConfig.selectedMosqueDefaultsKey),
              let selected = try? decoder.decode(WatchMosqueSnapshot.self, from: data) else { return nil }
        return mosqueOptions.first { $0.id == selected.id || $0.slug == selected.slug }
    }

    private func configureSelectionForLoadedMosques() {
        countryKeys = computeCountryKeys(from: mosqueOptions)
        guard let currentMosque = findCurrentMosqueOption() else {
            selectedCountryKey = countryKeys.first ?? ""
            updateCountry()
            return
        }

        selectedCountryKey = currentMosque.countryGroupingKey
        updateCountry()
        selectedCityKey = currentMosque.cityGroupingKey
        updateCity()
    }

    private func availableSetupPhase(_ preferredPhase: WatchSetupPhase) -> WatchSetupPhase {
        switch preferredPhase {
        case .loading:
            return .pickCountry
        case .pickCountry:
            return .pickCountry
        case .pickCity:
            return cityKeys.isEmpty ? .pickCountry : .pickCity
        case .pickMosque:
            return mosquesInCity.isEmpty ? (cityKeys.isEmpty ? .pickCountry : .pickCity) : .pickMosque
        }
    }

    func resetStandaloneSetup() {
        defaults.removeObject(forKey: WatchPrayerConfig.snapshotDefaultsKey)
        defaults.removeObject(forKey: WatchPrayerConfig.selectedMosqueDefaultsKey)
        state = .missing
        countryKeys = computeCountryKeys(from: mosqueOptions)
        selectedCountryKey = countryKeys.first ?? ""
        updateCountry()
        setupPhase = .pickCountry
    }

    private func computeCountryKeys(from mosques: [WatchMosqueOption]) -> [String] {
        let grouped = Dictionary(grouping: mosques, by: \.countryGroupingKey)
        return grouped.keys.sorted { lhs, rhs in
            let l = grouped[lhs]?.first?.countryDisplayName ?? lhs
            let r = grouped[rhs]?.first?.countryDisplayName ?? rhs
            return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
        }
    }

    private func countryLabel(for key: String) -> String {
        mosqueOptions.filter { $0.countryGroupingKey == key }.first?.countryDisplayName ?? key
    }

    private func cityLabel(for key: String) -> String {
        mosquesInCountry.filter { $0.cityGroupingKey == key }.first?.cityDisplayName ?? key
    }

    private func updateCountry() {
        let filtered = mosqueOptions.filter { $0.countryGroupingKey == selectedCountryKey }
        let cityGrouped = Dictionary(grouping: filtered, by: \.cityGroupingKey)
        cityKeys = cityGrouped.keys.sorted { lhs, rhs in
            let l = cityGrouped[lhs]?.first?.cityDisplayName ?? lhs
            let r = cityGrouped[rhs]?.first?.cityDisplayName ?? rhs
            return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
        }
        mosquesInCountry = filtered
        selectedCityKey = cityKeys.first ?? ""
        updateCity()
    }

    private func updateCity() {
        mosquesInCity = mosquesInCountry.filter { $0.cityGroupingKey == selectedCityKey }
    }

    private func persistSelectedMosque(_ mosque: WatchMosqueSnapshot) {
        guard let data = try? JSONEncoder().encode(mosque) else { return }
        defaults.set(data, forKey: WatchPrayerConfig.selectedMosqueDefaultsKey)
    }

    private func refreshDirectlyFromNetwork() {
        let currentSnapshot: WatchPrayerSnapshot?
        if let data = defaults.data(forKey: WatchPrayerConfig.snapshotDefaultsKey),
           let decoded = try? decoder.decode(WatchPrayerSnapshot.self, from: data),
           decoded.schemaVersion == 1 {
            currentSnapshot = decoded
        } else if let data = defaults.data(forKey: WatchPrayerConfig.selectedMosqueDefaultsKey),
                  let mosque = try? decoder.decode(WatchMosqueSnapshot.self, from: data) {
            currentSnapshot = WatchPrayerSnapshot(
                schemaVersion: 1,
                generatedAt: Date(),
                mosque: mosque,
                days: [],
                uses24HourTime: true,
                appLanguageRawValue: "en",
                asrIqamahPreference: "first"
            )
        } else {
            return
        }

        guard let currentSnapshot else { return }
        isRefreshing = state.kind != .content
        Task { [weak self, directRefreshService] in
            guard let refreshed = try? await directRefreshService.refreshSnapshot(from: currentSnapshot) else {
                await MainActor.run { self?.isRefreshing = false }
                return
            }
            guard let encoded = try? JSONEncoder().encode(refreshed) else {
                await MainActor.run { self?.isRefreshing = false }
                return
            }
            await MainActor.run {
                self?.isRefreshing = false
                self?.persistSnapshotData(encoded)
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        requestSnapshotFromPhone()
        refreshDirectlyFromNetwork()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(payload: applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(payload: userInfo)
    }

    private func receive(payload: [String: Any]) {
        guard let data = payload[WatchPrayerConfig.snapshotPayloadKey] as? Data else { return }
        Task { @MainActor in
            persistSnapshotData(data)
        }
    }
}

private final class WatchDirectPrayerRefreshService: Sendable {
    private struct ConvexQueryResponse<Value: Decodable>: Decodable {
        let status: String
        let value: Value?
        let errorMessage: String?
    }

    private struct MonthPrayerData: Decodable {
        let prayerTimes: [PrayerTime]
        let iqamahTimes: [IqamahTimeRange]
        let jummahIqamah: String

        enum CodingKeys: String, CodingKey {
            case prayerTimes = "prayer_times"
            case iqamahTimes = "iqamah_times"
            case jummahIqamah = "jummah_iqamah"
        }
    }

    private struct PrayerTime: Decodable {
        let date: Int
        let fajr: String
        let shurooq: String
        let dhuhr: String
        let asr: String
        let asrMithl2: String?
        let maghrib: String
        let isha: String

        enum CodingKeys: String, CodingKey {
            case date, fajr, shurooq, dhuhr, asr, maghrib, isha
            case asrMithl2 = "asr_mithl2"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try Self.decodeInt(container, forKey: .date)
            fajr = try container.decode(String.self, forKey: .fajr)
            shurooq = try container.decode(String.self, forKey: .shurooq)
            dhuhr = try container.decode(String.self, forKey: .dhuhr)
            asr = try container.decode(String.self, forKey: .asr)
            asrMithl2 = try container.decodeIfPresent(String.self, forKey: .asrMithl2)
            maghrib = try container.decode(String.self, forKey: .maghrib)
            isha = try container.decode(String.self, forKey: .isha)
        }

        private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int {
            if let int = try? container.decode(Int.self, forKey: key) { return int }
            if let double = try? container.decode(Double.self, forKey: key) { return Int(double) }
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: container.codingPath + [key], debugDescription: "Expected integer-compatible number"))
        }
    }

    private struct IqamahTimeRange: Decodable {
        let dateRange: String
        let fajr: String
        let dhuhr: String
        let asr: String
        let maghrib: String?
        let isha: String
        let jummah: String?

        enum CodingKeys: String, CodingKey {
            case dateRange = "date_range"
            case fajr, dhuhr, asr, maghrib, isha, jummah
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dateRange = try container.decode(String.self, forKey: .dateRange)
            fajr = try Self.decodeIqamahValue(container, forKey: .fajr)
            dhuhr = try Self.decodeIqamahValue(container, forKey: .dhuhr)
            asr = try Self.decodeIqamahValue(container, forKey: .asr)
            maghrib = try Self.decodeOptionalIqamahValue(container, forKey: .maghrib)
            isha = try Self.decodeIqamahValue(container, forKey: .isha)
            jummah = try Self.decodeOptionalIqamahValue(container, forKey: .jummah)
        }

        private static func decodeIqamahValue(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> String {
            if let value = try? container.decode(String.self, forKey: key) { return value }
            if let values = try? container.decode([String].self, forKey: key) { return values.joined(separator: ", ") }
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: container.codingPath + [key], debugDescription: "Expected string or string array"))
        }

        private static func decodeOptionalIqamahValue(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> String? {
            guard container.contains(key), !(try container.decodeNil(forKey: key)) else { return nil }
            if let value = try? container.decode(String.self, forKey: key) { return value }
            if let values = try? container.decode([String].self, forKey: key) { return values.joined(separator: ", ") }
            return nil
        }
    }

    private struct RamadanPrayerData: Decodable {
        let prayerTimes: [RamadanPrayerDay]
        let iqamahTimes: [IqamahTimeRange]
        let jummahIqamah: String

        enum CodingKeys: String, CodingKey {
            case prayerTimes = "prayer_times"
            case iqamahTimes = "iqamah_times"
            case jummahIqamah = "jummah_iqamah"
        }
    }

    private struct RamadanPrayerDay: Decodable {
        let ramadanDay: Int
        let gregorian: String
        let fajr: String
        let shurooq: String
        let dhuhr: String
        let asr: String
        let asrMithl2: String?
        let maghrib: String
        let isha: String

        enum CodingKeys: String, CodingKey {
            case ramadanDay = "ramadan_day"
            case gregorian, fajr, shurooq, dhuhr, asr, maghrib, isha
            case asrMithl2 = "asr_mithl2"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ramadanDay = try Self.decodeInt(container, forKey: .ramadanDay)
            gregorian = try container.decode(String.self, forKey: .gregorian)
            fajr = try container.decode(String.self, forKey: .fajr)
            shurooq = try container.decode(String.self, forKey: .shurooq)
            dhuhr = try container.decode(String.self, forKey: .dhuhr)
            asr = try container.decode(String.self, forKey: .asr)
            asrMithl2 = try container.decodeIfPresent(String.self, forKey: .asrMithl2)
            maghrib = try container.decode(String.self, forKey: .maghrib)
            isha = try container.decode(String.self, forKey: .isha)
        }

        private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Int {
            if let int = try? container.decode(Int.self, forKey: key) { return int }
            if let double = try? container.decode(Double.self, forKey: key) { return Int(double) }
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: container.codingPath + [key], debugDescription: "Expected integer-compatible number"))
        }
    }

    func listMosques() async throws -> [WatchMosqueOption] {
        try await query(path: "mosques:list", args: [:]) ?? []
    }

    func refreshSnapshot(from current: WatchPrayerSnapshot) async throws -> WatchPrayerSnapshot {
        try await refreshSnapshot(for: current.mosque, basedOn: current)
    }

    func refreshSnapshot(for mosque: WatchMosqueSnapshot, basedOn current: WatchPrayerSnapshot?) async throws -> WatchPrayerSnapshot {
        var monthlyCache: [String: MonthPrayerData?] = [:]
        var days: [WatchPrayerDaySnapshot] = []
        let now = Date()

        for offset in 0..<WatchPrayerConfig.directRefreshDays {
            let date = resolveDate(offsetByDays: offset, from: now)
            let parts = dateParts(for: date)
            guard let monthName = monthName(from: parts.month) else { continue }
            let dateString = isoDateString(year: parts.year, month: parts.month, day: parts.day)
            let ramadan = try await getRamadanTimetable(mosqueSlug: mosque.slug, date: dateString)

            if let ramadan, let ramadanDay = ramadan.prayerTimes.first(where: { $0.gregorian == dateString }) {
                let iqamah = try dailyIqamah(day: ramadanDay.ramadanDay, ranges: ramadan.iqamahTimes, jummahFallback: ramadan.jummahIqamah)
                let prayers = WatchDailyPrayerTimes(
                    date: dateString,
                    fajr: ramadanDay.fajr,
                    sunrise: ramadanDay.shurooq,
                    dhuhr: ramadanDay.dhuhr,
                    asr: selectAsrAdhan(asr: ramadanDay.asr, asrMithl2: ramadanDay.asrMithl2, preference: current?.asrIqamahPreference),
                    maghrib: ramadanDay.maghrib,
                    isha: ramadanDay.isha
                )
                days.append(WatchPrayerDaySnapshot(date: dateString, prayers: prayers, iqamah: resolvedIqamah(iqamah, prayers: prayers, mosqueSlug: mosque.slug, date: date, preference: current?.asrIqamahPreference)))
                continue
            }

            let cacheKey = "\(parts.year)-\(monthName)"
            let monthly: MonthPrayerData?
            if let cached = monthlyCache[cacheKey] {
                monthly = cached
            } else {
                let fetched = try await getMonthlyPrayerTimes(mosqueSlug: mosque.slug, month: monthName, year: parts.year)
                monthlyCache[cacheKey] = fetched
                monthly = fetched
            }

            guard let monthly, let day = findPrayerDay(monthly.prayerTimes, dayOfMonth: parts.day) else { continue }
            let rawIqamah = try dailyIqamah(day: parts.day, ranges: monthly.iqamahTimes, jummahFallback: monthly.jummahIqamah)
            let prayers = WatchDailyPrayerTimes(
                date: dateString,
                fajr: day.fajr,
                sunrise: day.shurooq,
                dhuhr: day.dhuhr,
                asr: selectAsrAdhan(asr: day.asr, asrMithl2: day.asrMithl2, preference: current?.asrIqamahPreference),
                maghrib: day.maghrib,
                isha: day.isha
            )
            days.append(WatchPrayerDaySnapshot(date: dateString, prayers: prayers, iqamah: resolvedIqamah(rawIqamah, prayers: prayers, mosqueSlug: mosque.slug, date: date, preference: current?.asrIqamahPreference)))
        }

        if let current, days.isEmpty { return current }
        guard !days.isEmpty else { throw URLError(.cannotParseResponse) }
        return WatchPrayerSnapshot(
            schemaVersion: current?.schemaVersion ?? 1,
            generatedAt: now,
            mosque: mosque,
            days: days,
            uses24HourTime: current?.uses24HourTime ?? true,
            appLanguageRawValue: current?.appLanguageRawValue ?? "en",
            asrIqamahPreference: current?.asrIqamahPreference ?? "first"
        )
    }

    private func getMonthlyPrayerTimes(mosqueSlug: String, month: String, year: Int) async throws -> MonthPrayerData? {
        try await query(path: "prayerTimes:getMonthly", args: ["mosqueSlug": mosqueSlug, "month": month, "year": Double(year)])
    }

    private func mightBeRamadanDate(_ date: String) -> Bool {
        guard date.count >= 7,
              let month = Int(date.dropFirst(5).prefix(2)) else { return true }
        return (1...4).contains(month)
    }

    private func getRamadanTimetable(mosqueSlug: String, date: String) async throws -> RamadanPrayerData? {
        guard mightBeRamadanDate(date) else { return nil }
        return try await query(path: "prayerTimes:getRamadan", args: ["mosqueSlug": mosqueSlug, "date": date])
    }

    private func query<Value: Decodable>(path: String, args: [String: Any]) async throws -> Value? {
        let url = WatchPrayerConfig.convexDeploymentURL.appendingPathComponent("api/query")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": path, "args": args, "format": "json"])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let envelope = try JSONDecoder().decode(ConvexQueryResponse<Value>.self, from: data)
        guard envelope.status == "success" else { throw URLError(.cannotParseResponse) }
        return envelope.value
    }

    private func resolveDate(offsetByDays offset: Int, from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        return calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }

    private func dateParts(for date: Date) -> (year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func isoDateString(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func monthName(from month: Int) -> String? {
        [1: "january", 2: "february", 3: "march", 4: "april", 5: "may", 6: "june", 7: "july", 8: "august", 9: "september", 10: "october", 11: "november", 12: "december"][month]
    }

    private func findPrayerDay(_ prayerTimes: [PrayerTime], dayOfMonth: Int) -> PrayerTime? {
        var closestPrevious: PrayerTime?
        var earliest: PrayerTime?
        for day in prayerTimes {
            if earliest == nil || day.date < (earliest?.date ?? day.date) { earliest = day }
            if day.date == dayOfMonth { return day }
            if day.date <= dayOfMonth, closestPrevious == nil || day.date > (closestPrevious?.date ?? 0) { closestPrevious = day }
        }
        return closestPrevious ?? earliest
    }

    private func dailyIqamah(day: Int, ranges: [IqamahTimeRange], jummahFallback: String) throws -> WatchDailyIqamahTimes {
        for range in ranges {
            let parts = range.dateRange.split(separator: "-").compactMap { Int($0) }
            guard let start = parts.first else { continue }
            let end = parts.count > 1 ? parts[1] : start
            if day >= start, day <= end {
                return WatchDailyIqamahTimes(
                    fajr: range.fajr,
                    dhuhr: range.dhuhr,
                    asr: range.asr,
                    maghrib: range.maghrib ?? "sunset",
                    isha: range.isha,
                    jummah: range.jummah?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? range.jummah ?? jummahFallback : jummahFallback
                )
            }
        }
        throw URLError(.cannotParseResponse)
    }

    private func resolvedIqamah(_ raw: WatchDailyIqamahTimes, prayers: WatchDailyPrayerTimes, mosqueSlug: String, date: Date, preference: String?) -> WatchDailyIqamahTimes {
        WatchDailyIqamahTimes(
            fajr: raw.fajr == "Various" ? prayers.fajr : resolveRelativeIqamah(raw.fajr, adhanTime: prayers.fajr),
            dhuhr: resolveRelativeIqamah(raw.dhuhr, adhanTime: prayers.dhuhr),
            asr: selectAsrIqamah(raw.asr, adhanTime: prayers.asr, preference: preference),
            maghrib: raw.maghrib == "sunset" ? prayers.maghrib : resolveRelativeIqamah(raw.maghrib, adhanTime: prayers.maghrib),
            isha: resolveIshaIqamah(raw.isha, prayers: prayers, mosqueSlug: mosqueSlug, date: date),
            jummah: raw.jummah
        )
    }

    private func selectAsrAdhan(asr: String, asrMithl2: String?, preference: String?) -> String {
        preference == "second" ? (asrMithl2?.isEmpty == false ? asrMithl2 ?? asr : asr) : asr
    }

    private func selectAsrIqamah(_ raw: String, adhanTime: String, preference: String?) -> String {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "entry time" { return adhanTime }
        let slots = splitIqamahTimes(raw).map { resolveRelativeIqamah($0, adhanTime: adhanTime) }
        guard slots.count > 1 else { return slots.first ?? resolveRelativeIqamah(raw, adhanTime: adhanTime) }
        return preference == "second" ? slots[1] : slots[0]
    }

    private func resolveIshaIqamah(_ raw: String, prayers: WatchDailyPrayerTimes, mosqueSlug: String, date: Date) -> String {
        if normalize(mosqueSlug) == "masjid-risalah", isRisalahIshaIqamahMatchesAdhanPeriod(date: date) { return prayers.isha }
        if normalize(mosqueSlug) == "muslim-welfare-house", isSummerIshaPeriod(date: date) { return "After Maghrib" }
        if raw == "Straight after Maghrib" { return prayers.maghrib }
        if raw == "Entry Time" { return prayers.isha }
        return resolveRelativeIqamah(raw, adhanTime: prayers.isha)
    }

    private func splitIqamahTimes(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let regex = try? NSRegularExpression(pattern: #"(\d{1,2}:\d{2})\s+(?=\d{1,2}:\d{2})"#)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let normalized = regex?.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "$1,") ?? trimmed
        return normalized.components(separatedBy: CharacterSet(charactersIn: ",/&|\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func resolveRelativeIqamah(_ value: String, adhanTime: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [#"^adhan\s*\+\s*(\d+)\s*(?:mins?|minutes?)?$"#, #"^(\d+)\s*(?:mins?|minutes?)\s*after\s*adhan$"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range), let minsRange = Range(match.range(at: 1), in: trimmed), let minutes = Int(trimmed[minsRange]) else { continue }
            return addMinutes(to: adhanTime, minutes: minutes) ?? value
        }
        return value
    }

    private func addMinutes(to time: String, minutes: Int) -> String? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let total = (((parts[0] * 60 + parts[1] + minutes) % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func isSummerIshaPeriod(date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        let year = calendar.component(.year, from: date)
        guard let may15 = calendar.date(from: DateComponents(year: year, month: 5, day: 15, hour: 12)),
              let aug15 = calendar.date(from: DateComponents(year: year, month: 8, day: 15, hour: 12)) else { return false }
        return date >= may15 && date <= aug15
    }

    private func isRisalahIshaIqamahMatchesAdhanPeriod(date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        let year = calendar.component(.year, from: date)
        guard let may1 = calendar.date(from: DateComponents(year: year, month: 5, day: 1, hour: 12)),
              let july31 = calendar.date(from: DateComponents(year: year, month: 7, day: 31, hour: 12)) else { return false }
        return date >= may1 && date <= july31
    }

    private func normalize(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private enum WatchPrayerResolver {
    static func resolve(snapshot: WatchPrayerSnapshot, now: Date) -> WatchPrayerState {
        let today = isoDateString(for: now)
        guard let day = snapshot.days.first(where: { $0.date == today }) else { return .stale }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        let dayStart = calendar.startOfDay(for: now)
        let isFriday = calendar.component(.weekday, from: now) == 6

        func date(_ time: String) -> Date? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: dayStart)
        }

        let names = localizedNames(rawLanguage: snapshot.appLanguageRawValue)
        let jummahSlots = split(day.iqamah.jummah)
        let dhuhrDisplayName = isFriday ? names.jummah : names.dhuhr
        let dhuhrIqamah = isFriday ? (jummahSlots.first ?? day.iqamah.dhuhr) : day.iqamah.dhuhr

        let prayers: [(id: String, name: String, adhan: String, iqamah: String)] = [
            ("fajr", names.fajr, day.prayers.fajr, day.iqamah.fajr),
            ("dhuhr", dhuhrDisplayName, day.prayers.dhuhr, dhuhrIqamah),
            ("asr", names.asr, day.prayers.asr, selectAsr(day.iqamah.asr, preference: snapshot.asrIqamahPreference)),
            ("maghrib", names.maghrib, day.prayers.maghrib, day.iqamah.maghrib),
            ("isha", names.isha, day.prayers.isha, day.iqamah.isha)
        ]

        var nextIndex = prayers.startIndex
        var nextIsIqamah = false
        var found = false

        for (index, prayer) in prayers.enumerated() {
            if let adhanDate = date(prayer.adhan), adhanDate > now {
                nextIndex = index
                found = true
                break
            }
            if let iqamahDate = date(prayer.iqamah), iqamahDate > now {
                nextIndex = index
                nextIsIqamah = true
                found = true
                break
            }
        }

        let next = found ? prayers[nextIndex] : prayers[0]
        let rows = prayers.enumerated().map { index, prayer in
            WatchPrayerRow(
                id: prayer.id,
                name: prayer.name,
                adhan: format(prayer.adhan, uses24HourTime: snapshot.uses24HourTime),
                isPassed: index < nextIndex && found,
                isNext: index == nextIndex
            )
        }

        return WatchPrayerState(
            kind: .content,
            mosqueName: snapshot.mosque.name,
            prayerName: next.name,
            adhanTime: format(nextIsIqamah ? next.iqamah : next.adhan, uses24HourTime: snapshot.uses24HourTime),
            iqamahTime: format(next.iqamah, uses24HourTime: snapshot.uses24HourTime),
            isIqamah: nextIsIqamah,
            rows: rows
        )
    }

    private static func isoDateString(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = WatchPrayerConfig.sheffieldTimeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func format(_ raw: String, uses24HourTime: Bool) -> String {
        guard !uses24HourTime else { return raw }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return raw }
        let hour = parts[0]
        let minute = parts[1]
        let suffix = hour >= 12 ? "pm" : "am"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", displayHour, minute, suffix)
    }

    private static func split(_ raw: String) -> [String] {
        raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func selectAsr(_ raw: String, preference: String?) -> String {
        let values = split(raw)
        guard values.count > 1 else { return raw }
        return preference == "second" ? values[1] : values[0]
    }

    private static func localizedNames(rawLanguage: String) -> (fajr: String, dhuhr: String, jummah: String, asr: String, maghrib: String, isha: String) {
        switch rawLanguage {
        case "arabic", "ar": return ("الفجر", "الظهر", "الجمعة", "العصر", "المغرب", "العشاء")
        case "urdu", "ur": return ("فجر", "ظہر", "جمعہ", "عصر", "مغرب", "عشاء")
        case "indonesian", "id", "id_ID", "id-ID": return ("Subuh", "Zuhur", "Jummah", "Asar", "Magrib", "Isya")
        default: return ("Fajr", "Dhuhr", "Jummah", "Asr", "Maghrib", "Isha")
        }
    }
}
