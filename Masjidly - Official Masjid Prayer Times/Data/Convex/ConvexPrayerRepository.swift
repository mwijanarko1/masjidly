import ConvexMobile
import Foundation

final class ConvexPrayerRepository: PrayerRepository {
    private let service: ConvexService

    init(service: ConvexService) {
        self.service = service
    }

    private func mightBeRamadanDate(_ date: String) -> Bool {
        guard date.count >= 7,
              let month = Int(date.dropFirst(5).prefix(2)) else { return true }
        return (1...4).contains(month)
    }

    func listMosques() async throws -> [Mosque] {
        try await service.client.subscribeFirstValue(to: "mosques:list", with: [:], as: [Mosque].self)
    }

    func getDataRevision() async throws -> DataRevision {
        try await service.client.subscribeFirstValue(to: "prayerTimes:getDataRevision", with: [:], as: DataRevision.self)
    }

    func getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int) async throws -> PrayerDataVersions {
        try await service.client.subscribeFirstValue(
            to: "prayerTimes:getDataVersions",
            with: ["mosqueSlug": mosqueSlug, "month": month.rawValue, "year": Double(year)],
            as: PrayerDataVersions.self
        )
    }

    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        // Convex `v.number()` / float64 validators reject integer-encoded years from Swift; send as Double.
        try await service.client.subscribeFirstValue(
            to: "prayerTimes:getMonthly",
            with: ["mosqueSlug": mosqueSlug, "month": month.rawValue, "year": Double(year)],
            as: MonthPrayerData?.self
        )
    }

    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? {
        if let date {
            guard mightBeRamadanDate(date) else { return nil }
            return try await service.client.subscribeFirstValue(
                to: "prayerTimes:getRamadan",
                with: ["mosqueSlug": mosqueSlug, "date": date],
                as: RamadanPrayerData?.self
            )
        }
        return try await service.client.subscribeFirstValue(
            to: "prayerTimes:getRamadan",
            with: ["mosqueSlug": mosqueSlug],
            as: RamadanPrayerData?.self
        )
    }

    func getUkDstDates() async throws -> UkDstCalendar? {
        try await service.client.subscribeFirstValue(to: "prayerTimes:getUkDstDates", with: [:], as: UkDstCalendar?.self)
    }
}
