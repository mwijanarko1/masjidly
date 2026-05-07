import ConvexMobile
import Foundation

final class ConvexPrayerRepository: PrayerRepository {
    private let service: ConvexService

    init(service: ConvexService) {
        self.service = service
    }

    func listMosques() async throws -> [Mosque] {
        try await service.client.subscribeFirstValue(to: "mosques:list", with: [:], as: [Mosque].self)
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
