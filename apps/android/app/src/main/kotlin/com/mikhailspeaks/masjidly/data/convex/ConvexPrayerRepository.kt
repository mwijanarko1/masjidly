package com.mikhailspeaks.masjidly.data.convex

import com.mikhailspeaks.masjidly.domain.IqamahTimeRange
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTime
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.RamadanPrayerDay
import com.mikhailspeaks.masjidly.domain.UkDstCalendar
import com.mikhailspeaks.masjidly.domain.UkDstYear
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.decodeFromJsonElement

/**
 * Convex-backed repository — mirrors iOS `ConvexPrayerRepository.swift` query names/args.
 */
class ConvexPrayerRepository(
    private val client: ConvexHttpClient,
    private val json: Json = Json { ignoreUnknownKeys = true },
) : PrayerRepository {

    override suspend fun listMosques(): List<Mosque> {
        val value = client.query("mosques:list", emptyMap())
        val wire = json.decodeFromJsonElement<List<MosqueWire>>(value)
        return wire.map { it.toDomain() }
    }

    override suspend fun getMonthlyPrayerTimes(
        mosqueSlug: String,
        month: MonthName,
        year: Int,
    ): MonthPrayerData? {
        val value = client.query(
            "prayerTimes:getMonthly",
            client.jsonArgs {
                putString("mosqueSlug", mosqueSlug)
                putString("month", month.rawValue)
                // Convex `v.number()` rejects integer-encoded years from some clients; send as Double (iOS parity).
                putDouble("year", year.toDouble())
            },
        )
        if (value is JsonNull) return null
        return json.decodeFromJsonElement<MonthPrayerDataWire>(value).toDomain()
    }

    override suspend fun getRamadanTimetable(
        mosqueSlug: String,
        date: String?,
    ): RamadanPrayerData? {
        val value = client.query(
            "prayerTimes:getRamadan",
            if (date != null) {
                client.jsonArgs {
                    putString("mosqueSlug", mosqueSlug)
                    putString("date", date)
                }
            } else {
                client.jsonArgs { putString("mosqueSlug", mosqueSlug) }
            },
        )
        if (value is JsonNull) return null
        return json.decodeFromJsonElement<RamadanPrayerDataWire>(value).toDomain()
    }

    override suspend fun getUkDstDates(): UkDstCalendar? {
        val value = client.query("prayerTimes:getUkDstDates", emptyMap())
        if (value is JsonNull) return null
        return json.decodeFromJsonElement<UkDstCalendarWire>(value).toDomain()
    }
}

private fun MosqueWire.toDomain(): Mosque {
    val hidden = isHidden ?: isHiddenSnake ?: false
    return Mosque(
        id = id,
        name = name,
        address = address,
        lat = lat,
        lng = lng,
        slug = slug,
        citySlug = citySlug ?: citySlugSnake ?: "sheffield",
        cityName = cityName ?: cityNameSnake ?: "Sheffield",
        countryCode = countryCode ?: countryCodeSnake ?: "GB",
        countryName = countryName ?: countryNameSnake ?: "United Kingdom",
        timezone = timezone ?: "Europe/London",
        website = website,
        isHidden = hidden,
    )
}

private fun PrayerTimeWire.toDomain() = PrayerTime(
    date = date.toInt(),
    fajr = fajr,
    shurooq = shurooq,
    dhuhr = dhuhr,
    asr = asr,
    asrMithl2 = asrMithl2,
    maghrib = maghrib,
    isha = isha,
)

private fun IqamahTimeRangeWire.toDomain() = IqamahTimeRange(
    dateRange = dateRange,
    fajr = decodeIqamahValue(fajr),
    dhuhr = decodeIqamahValue(dhuhr),
    asr = decodeIqamahValue(asr),
    maghrib = maghrib?.let(::decodeIqamahValue),
    isha = decodeIqamahValue(isha),
    jummah = jummah?.let(::decodeIqamahValue),
)

private fun MonthPrayerDataWire.toDomain() = MonthPrayerData(
    month = month,
    prayerTimes = prayerTimes.map { it.toDomain() },
    iqamahTimes = iqamahTimes.map { it.toDomain() },
    jummahIqamah = jummahIqamah,
)

private fun RamadanPrayerDayWire.toDomain() = RamadanPrayerDay(
    ramadanDay = ramadanDay.toInt(),
    gregorian = gregorian,
    fajr = fajr,
    shurooq = shurooq,
    dhuhr = dhuhr,
    asr = asr,
    asrMithl2 = asrMithl2,
    maghrib = maghrib,
    isha = isha,
)

private fun RamadanPrayerDataWire.toDomain() = RamadanPrayerData(
    month = month,
    gregorianStart = gregorianStart,
    gregorianEnd = gregorianEnd,
    prayerTimes = prayerTimes.map { it.toDomain() },
    iqamahTimes = iqamahTimes.map { it.toDomain() },
    jummahIqamah = jummahIqamah,
)

private fun UkDstCalendarWire.toDomain() = UkDstCalendar(
    ukDstDates = ukDstDates.map {
        UkDstYear(year = it.year.toInt(), startDate = it.startDate, endDate = it.endDate)
    },
)
