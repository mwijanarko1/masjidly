import Foundation
import Observation

/// Loads monthly and Ramadan payloads for many masjids with a concurrency cap.
/// Cached payloads render first; missing or stale ones are fetched and written to the disk cache.
@Observable
@MainActor
final class CompareDataStore {
    enum State: Equatable {
        case idle
        case loading
        case loaded(monthly: MonthPrayerData?, ramadan: RamadanPrayerData?)
        case failed
        case offline
    }

    private struct Job {
        let mosque: Mosque
        let date: Date
    }

    private let repository: any PrayerRepository
    private let diskCache: PrayerTimesDiskCache
    private let maxConcurrent: Int

    /// Bumped whenever any payload or status changes so observers re-read `state(for:date:)`.
    private(set) var revision = 0

    @ObservationIgnored private var monthlyMemory: [String: MonthPrayerData] = [:]
    @ObservationIgnored private var ramadanMemory: [String: RamadanPrayerData] = [:]
    @ObservationIgnored private var ramadanChecked: Set<String> = []
    @ObservationIgnored private var verifiedMonths: Set<String> = []
    @ObservationIgnored private var statuses: [String: State] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(repository: any PrayerRepository, diskCache: PrayerTimesDiskCache, maxConcurrent: Int = 6) {
        self.repository = repository
        self.diskCache = diskCache
        self.maxConcurrent = max(1, maxConcurrent)
    }

    // MARK: - Keys

    private struct DayParts {
        let monthName: MonthName
        let year: Int
        let iso: String
        let monthKey: String
        let ramadanKey: String
        let dayKey: String
    }

    private func parts(for mosque: Mosque, date: Date) -> DayParts? {
        let p = PrayerTimesEngine.getDateInSheffield(date)
        guard let monthName = MonthName.from(monthNumber: p.month) else { return nil }
        let iso = PrayerTimesEngine.isoDateString(year: p.year, month: p.month, day: p.day)
        return DayParts(
            monthName: monthName,
            year: p.year,
            iso: iso,
            monthKey: "\(mosque.slug)|\(p.year)|\(monthName.rawValue)",
            ramadanKey: "\(mosque.slug)|\(iso)",
            dayKey: "\(mosque.slug)|\(iso)"
        )
    }

    // MARK: - Reading

    func state(for mosque: Mosque, date: Date) -> State {
        _ = revision
        guard let p = parts(for: mosque, date: date) else { return .failed }
        if let monthly = cachedMonthly(mosque: mosque, parts: p) {
            return .loaded(monthly: monthly, ramadan: cachedRamadan(mosque: mosque, parts: p))
        }
        return statuses[p.dayKey] ?? .idle
    }

    private func cachedMonthly(mosque: Mosque, parts p: DayParts) -> MonthPrayerData? {
        if let memory = monthlyMemory[p.monthKey] { return memory }
        if let disk = diskCache.loadMonthly(slug: mosque.slug, month: p.monthName.rawValue, year: p.year) {
            monthlyMemory[p.monthKey] = disk
            return disk
        }
        return nil
    }

    private func cachedRamadan(mosque: Mosque, parts p: DayParts) -> RamadanPrayerData? {
        if let memory = ramadanMemory[p.ramadanKey] { return memory }
        if let disk = diskCache.loadRamadan(slug: mosque.slug, date: p.iso) {
            ramadanMemory[p.ramadanKey] = disk
            return disk
        }
        return nil
    }

    // MARK: - Loading

    func load(_ mosques: [Mosque], date: Date) async {
        cancel()
        let jobs = mosques.compactMap { mosque -> Job? in
            guard let p = parts(for: mosque, date: date), needsWork(mosque: mosque, parts: p) else { return nil }
            if case .loaded = state(for: mosque, date: date) {} else {
                statuses[p.dayKey] = .loading
            }
            return Job(mosque: mosque, date: date)
        }
        revision += 1
        guard !jobs.isEmpty else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.run(jobs)
        }
        loadTask = task
        await task.value
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        let hadLoading = statuses.values.contains(.loading)
        statuses = statuses.filter { $0.value != .loading }
        if hadLoading { revision += 1 }
    }

    private func needsWork(mosque: Mosque, parts p: DayParts) -> Bool {
        if cachedMonthly(mosque: mosque, parts: p) == nil { return true }
        if !verifiedMonths.contains(p.monthKey) { return true }
        return cachedRamadan(mosque: mosque, parts: p) == nil && !ramadanChecked.contains(p.ramadanKey)
    }

    private func run(_ jobs: [Job]) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = jobs.makeIterator()
            var inFlight = 0
            while inFlight < maxConcurrent, let job = iterator.next() {
                group.addTask { @MainActor [self] in await self.perform(job) }
                inFlight += 1
            }
            while await group.next() != nil {
                guard !Task.isCancelled else { continue }
                if let job = iterator.next() {
                    group.addTask { @MainActor [self] in await self.perform(job) }
                }
            }
        }
    }

    private func perform(_ job: Job) async {
        let mosque = job.mosque
        guard !Task.isCancelled, let p = parts(for: mosque, date: job.date) else { return }

        var monthly = cachedMonthly(mosque: mosque, parts: p)
        var fetchedNilMonthly = false

        if monthly != nil {
            if !verifiedMonths.contains(p.monthKey) {
                let versions = try? await repository.getPrayerDataVersions(mosqueSlug: mosque.slug, month: p.monthName, year: p.year)
                guard !Task.isCancelled else { return }
                let cachedVersions = diskCache.loadVersions(slug: mosque.slug, month: p.monthName.rawValue, year: p.year)
                if let versions, let cachedVersions, cachedVersions.versions == versions {
                    verifiedMonths.insert(p.monthKey)
                } else {
                    do {
                        let fresh = try await repository.getMonthlyPrayerTimes(mosqueSlug: mosque.slug, month: p.monthName, year: p.year)
                        guard !Task.isCancelled else { return }
                        store(fresh, mosque: mosque, parts: p, versions: versions)
                        monthly = Self.usable(fresh)
                        fetchedNilMonthly = monthly == nil
                    } catch {}
                }
                // A failed refresh keeps the cached payload; it is retried on the next load.
            }
        } else {
            do {
                let fresh = try await repository.getMonthlyPrayerTimes(mosqueSlug: mosque.slug, month: p.monthName, year: p.year)
                guard !Task.isCancelled else { return }
                store(fresh, mosque: mosque, parts: p, versions: nil)
                monthly = Self.usable(fresh)
                fetchedNilMonthly = monthly == nil
            } catch {
                guard !Task.isCancelled else { return }
                statuses[p.dayKey] = Self.classify(error)
                revision += 1
                return
            }
        }

        var ramadan = cachedRamadan(mosque: mosque, parts: p)
        if ramadan == nil, !ramadanChecked.contains(p.ramadanKey) {
            do {
                let fetched = try await repository.getRamadanTimetable(mosqueSlug: mosque.slug, date: p.iso)
                guard !Task.isCancelled else { return }
                ramadanChecked.insert(p.ramadanKey)
                if let fetched {
                    ramadan = fetched
                    try? diskCache.saveRamadan(slug: mosque.slug, date: p.iso, data: fetched)
                    ramadanMemory[p.ramadanKey] = fetched
                }
            } catch {}
        }

        if monthly == nil || fetchedNilMonthly {
            statuses[p.dayKey] = .loaded(monthly: nil, ramadan: ramadan)
        } else {
            statuses[p.dayKey] = nil
        }
        revision += 1
    }

    private func store(_ monthly: MonthPrayerData?, mosque: Mosque, parts p: DayParts, versions: PrayerDataVersions?) {
        if let monthly, !monthly.prayerTimes.isEmpty {
            try? diskCache.saveMonthly(slug: mosque.slug, month: p.monthName.rawValue, year: p.year, data: monthly)
            monthlyMemory[p.monthKey] = monthly
            if let versions {
                try? diskCache.saveVersions(slug: mosque.slug, month: p.monthName.rawValue, year: p.year, versions: versions)
            }
            verifiedMonths.insert(p.monthKey)
        } else {
            diskCache.removeMonthly(slug: mosque.slug, month: p.monthName.rawValue, year: p.year)
            monthlyMemory[p.monthKey] = nil
        }
    }

    private static func usable(_ monthly: MonthPrayerData?) -> MonthPrayerData? {
        guard let monthly, !monthly.prayerTimes.isEmpty else { return nil }
        return monthly
    }

    private static func classify(_ error: Error) -> State {
        let code: Int
        if let urlError = error as? URLError {
            code = urlError.code.rawValue
        } else if (error as NSError).domain == NSURLErrorDomain {
            code = (error as NSError).code
        } else {
            return .failed
        }
        let offlineCodes: Set<Int> = [
            URLError.notConnectedToInternet.rawValue,
            URLError.networkConnectionLost.rawValue,
            URLError.dataNotAllowed.rawValue,
        ]
        return offlineCodes.contains(code) ? .offline : .failed
    }
}

/// Creates the Compare data store on demand. A reference type, so a cover's content closure
/// always sees the same store and never a stale optional copy of view state.
@MainActor
final class CompareStoreHolder {
    private var store: CompareDataStore?

    func resolve(_ make: () -> CompareDataStore) -> CompareDataStore {
        if let store { return store }
        let created = make()
        store = created
        return created
    }

    func reset() {
        store?.cancel()
        store = nil
    }
}
