import Foundation
import Observation

@Observable
@MainActor
final class CompareViewModel {
    static let maxMasjids = 10

    struct Row: Equatable, Identifiable {
        let mosque: Mosque
        let isYours: Bool
        let state: CompareDataStore.State
        let times: CompareDayTimes?
        let deltas: [ComparePrayer: Int]

        var id: String { mosque.id }
    }

    private let mosques: [Mosque]
    private let homeMosque: Mosque?
    private let settings: SettingsStore
    private let store: CompareDataStore
    private let now: () -> Date

    private(set) var date: Date
    private(set) var sort: (prayer: ComparePrayer, ascending: Bool)?
    /// Which time the Masjids grid emphasises, sorts by and diffs against yours.
    var gridTimeType: CompareTimeType = .jamaat

    var cityKey: String
    var query: CompareFindQuery {
        didSet {
            if query.minutes != autoMinutes { minutesCustomized = true }
        }
    }
    private var autoMinutes: Int
    private var minutesCustomized = false

    init(
        mosques: [Mosque],
        homeMosque: Mosque?,
        settings: SettingsStore,
        store: CompareDataStore,
        initialDate: Date,
        now: @escaping () -> Date = { Date() }
    ) {
        let visible = MosqueDefaults.visibleMosques(mosques)
        self.mosques = visible
        self.homeMosque = homeMosque
        self.settings = settings
        self.store = store
        self.now = now

        let parts = PrayerTimesEngine.getDateInSheffield(initialDate)
        let normalized = PrayerTimesEngine.sheffieldNoonUTC(year: parts.year, month: parts.month, day: parts.day)
        self.date = normalized

        let options = MosqueDefaults.cityOptions(from: visible)
        if let key = settings.selectedCityGroupingKey, options.contains(where: { $0.key == key }) {
            self.cityKey = key
        } else if let key = homeMosque?.cityGroupingKey, options.contains(where: { $0.key == key }) {
            self.cityKey = key
        } else {
            self.cityKey = options.first?.key ?? ""
        }

        let isToday = Self.sameSheffieldDay(normalized, now())
        let minutes = CompareFindQuery.defaultMinutes(isToday: isToday, now: now())
        self.autoMinutes = minutes
        self.query = CompareFindQuery(prayer: nil, type: .jamaat, direction: .after, minutes: minutes)
    }

    var mode: CompareMode {
        get { settings.compareMode }
        set { settings.compareMode = newValue }
    }

    var yoursId: String? { homeMosque?.id }

    // MARK: - Day

    var isToday: Bool { Self.sameSheffieldDay(date, now()) }

    var isFriday: Bool { CompareDayResolver.isFridayInSheffield(date) }

    func stepDay(_ delta: Int) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let next = utc.date(byAdding: .day, value: delta, to: date) else { return }
        date = next
        if !minutesCustomized {
            let minutes = CompareFindQuery.defaultMinutes(isToday: isToday, now: now())
            autoMinutes = minutes
            query.minutes = minutes
            minutesCustomized = false
        }
    }

    private static func sameSheffieldDay(_ a: Date, _ b: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return cal.isDate(a, inSameDayAs: b)
    }

    // MARK: - Masjids mode

    /// Your home masjid is always first and always present. The masjids you add follow it.
    var listedMosques: [Mosque] {
        let byId = Dictionary(mosques.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var ordered: [Mosque] = []
        if let home = homeMosque {
            seen.insert(home.id)
            ordered.append(home)
        }
        for id in settings.compareMosqueIds {
            guard let mosque = byId[id], seen.insert(id).inserted else { continue }
            ordered.append(mosque)
        }
        return ordered
    }

    func isYours(_ mosque: Mosque) -> Bool { mosque.id == homeMosque?.id }

    var canAddMore: Bool { listedMosques.count < Self.maxMasjids }

    @discardableResult
    func add(_ mosque: Mosque) -> Bool {
        let current = listedMosques.map(\.id)
        if current.contains(mosque.id) { return true }
        guard current.count < Self.maxMasjids else { return false }
        let stored = settings.compareMosqueIds.filter { id in mosques.contains { $0.id == id } }
        settings.compareMosqueIds = stored + [mosque.id]
        return true
    }

    func remove(_ mosque: Mosque) {
        guard !isYours(mosque) else { return }
        settings.compareMosqueIds = settings.compareMosqueIds.filter { $0 != mosque.id }
    }

    func isListed(_ mosque: Mosque) -> Bool {
        isYours(mosque) || settings.compareMosqueIds.contains(mosque.id)
    }

    func tapHeader(_ prayer: ComparePrayer) {
        guard let current = sort, current.prayer == prayer else {
            sort = (prayer, true)
            return
        }
        sort = current.ascending ? (prayer, false) : nil
    }

    var rows: [Row] {
        let asr = settings.asrIqamahPreference
        let listed = listedMosques
        var resolved: [(mosque: Mosque, state: CompareDataStore.State, times: CompareDayTimes?)] = listed.map { mosque in
            let state = store.state(for: mosque, date: date)
            var times: CompareDayTimes?
            if case let .loaded(monthly, ramadan) = state {
                times = CompareDayResolver.resolve(
                    mosque: mosque, date: date, monthly: monthly, ramadan: ramadan, asrPreference: asr
                )
            }
            return (mosque, state, times)
        }

        if let sort {
            let pinned = resolved.filter { $0.mosque.id == yoursId }
            let rest = resolved.filter { $0.mosque.id != yoursId }
            let keyed = rest.enumerated().map { index, row -> (Int, Int?, (mosque: Mosque, state: CompareDataStore.State, times: CompareDayTimes?)) in
                (index, row.times.flatMap { sortMinutes($0, prayer: sort.prayer) }, row)
            }
            let ordered = keyed.sorted { a, b in
                switch (a.1, b.1) {
                case let (x?, y?):
                    if x != y { return sort.ascending ? x < y : x > y }
                    return a.0 < b.0
                case (nil, nil): return a.0 < b.0
                case (_?, nil): return true
                case (nil, _?): return false
                }
            }
            resolved = pinned + ordered.map(\.2)
        }

        let yours = resolved.first { $0.mosque.id == yoursId }
        return resolved.map { entry in
            var deltas: [ComparePrayer: Int] = [:]
            if let yours, let yoursTimes = yours.times, let times = entry.times,
               entry.mosque.id != yours.mosque.id,
               CompareDelta.isComparable(yours.mosque, entry.mosque) {
                for prayer in ComparePrayer.allCases {
                    if let minutes = deltaMinutes(yours: yoursTimes, other: times, prayer: prayer) {
                        deltas[prayer] = minutes
                    }
                }
            }
            return Row(
                mosque: entry.mosque,
                isYours: entry.mosque.id == yoursId,
                state: entry.state,
                times: entry.times,
                deltas: deltas
            )
        }
    }

    private func adhanMinutes(_ times: CompareDayTimes, prayer: ComparePrayer) -> Int? {
        times.adhan[prayer].flatMap { CompareSlot(engineValue: $0) }?.minutes
    }

    private func sortMinutes(_ times: CompareDayTimes, prayer: ComparePrayer) -> Int? {
        switch gridTimeType {
        case .jamaat: return times.iqamah[prayer]?.compactMap(\.minutes).min()
        case .adhan: return adhanMinutes(times, prayer: prayer)
        }
    }

    private func deltaMinutes(yours: CompareDayTimes, other: CompareDayTimes, prayer: ComparePrayer) -> Int? {
        switch gridTimeType {
        case .jamaat:
            return CompareDelta.minutes(yours: yours.homeIqamah[prayer], other: other.iqamah[prayer] ?? [])
        case .adhan:
            guard let base = adhanMinutes(yours, prayer: prayer), let value = adhanMinutes(other, prayer: prayer) else { return nil }
            return value - base
        }
    }

    func loadMasjids() async {
        await store.load(listedMosques, date: date)
    }

    // MARK: - By time mode

    var cityOptions: [(key: String, label: String)] {
        MosqueDefaults.cityOptions(from: mosques)
    }

    var cityLabel: String {
        cityOptions.first { $0.key == cityKey }?.label ?? ""
    }

    private var cityMosques: [Mosque] {
        MosqueDefaults.mosques(inCityGroupingKey: cityKey, mosques: mosques)
    }

    var findResult: CompareFindResult {
        let asr = settings.asrIqamahPreference
        let entries: [CompareFinder.Entry] = cityMosques.compactMap { mosque in
            guard case let .loaded(monthly, ramadan) = store.state(for: mosque, date: date),
                  let times = CompareDayResolver.resolve(
                    mosque: mosque, date: date, monthly: monthly, ramadan: ramadan, asrPreference: asr
                  ) else { return nil }
            return CompareFinder.Entry(mosque: mosque, times: times)
        }
        return CompareFinder.search(query: query, entries: entries)
    }

    var loadProgress: (loaded: Int, total: Int) {
        let list = cityMosques
        let loaded = list.filter { mosque in
            if case .loaded = store.state(for: mosque, date: date) { return true }
            return false
        }.count
        return (loaded, list.count)
    }

    var failedCount: Int {
        cityMosques.filter { mosque in
            switch store.state(for: mosque, date: date) {
            case .failed, .offline: return true
            default: return false
            }
        }.count
    }

    var isLoadingFind: Bool {
        cityMosques.contains { mosque in
            switch store.state(for: mosque, date: date) {
            case .idle, .loading: return true
            default: return false
            }
        }
    }

    /// The jamaat clock time Home shows for your masjid and `prayer` on the chosen day, when known.
    func yourJamaatMinutes(for prayer: ComparePrayer) -> Int? {
        guard let home = homeMosque,
              case let .loaded(monthly, ramadan) = store.state(for: home, date: date),
              let times = CompareDayResolver.resolve(
                mosque: home, date: date, monthly: monthly, ramadan: ramadan, asrPreference: settings.asrIqamahPreference
              ) else { return nil }
        return times.homeIqamah[prayer]?.minutes
    }

    func nudgeMinutes(_ delta: Int) {
        query.minutes = min(1439, max(0, query.minutes + delta))
    }

    /// Searches for jamaats strictly later than your masjid's for the chosen prayer.
    func searchLaterThanYours() {
        guard let prayer = query.prayer, let yours = yourJamaatMinutes(for: prayer) else { return }
        query.type = .jamaat
        query.direction = .after
        query.minutes = min(1439, yours + 1)
    }

    func loadFind() async {
        await store.load(cityMosques, date: date)
    }

    func cancelLoading() {
        store.cancel()
    }

    /// Minutes between `now` and a hit on today's date; nil on other days.
    func relativeMinutes(for hit: CompareFindHit) -> Int? {
        guard isToday else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let parts = cal.dateComponents([.hour, .minute], from: now())
        let current = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return hit.minutes - current
    }
}
