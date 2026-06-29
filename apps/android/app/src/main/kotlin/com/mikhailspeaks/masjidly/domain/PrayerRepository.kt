package com.mikhailspeaks.masjidly.domain

interface PrayerRepository {
    suspend fun listMosques(): List<Mosque>
    suspend fun getDataRevision(): DataRevision = DataRevision(0.0, 0.0)
    suspend fun getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int): PrayerDataVersions =
        PrayerDataVersions(0.0, 0.0, 0.0, 0.0)
    suspend fun getMonthlyPrayerTimes(
        mosqueSlug: String,
        month: MonthName,
        year: Int,
    ): MonthPrayerData?

    suspend fun getRamadanTimetable(
        mosqueSlug: String,
        date: String?,
    ): RamadanPrayerData?

    suspend fun getUkDstDates(): UkDstCalendar?
}
