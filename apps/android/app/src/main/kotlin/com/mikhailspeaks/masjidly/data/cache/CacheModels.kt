package com.mikhailspeaks.masjidly.data.cache

import com.mikhailspeaks.masjidly.domain.IqamahTimeRange
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerTime
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.RamadanPrayerDay
import com.mikhailspeaks.masjidly.domain.UkDstCalendar
import com.mikhailspeaks.masjidly.domain.UkDstYear
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class MosqueCache(
    val id: String,
    val name: String,
    val address: String,
    val lat: Double,
    val lng: Double,
    val slug: String,
    val citySlug: String? = null,
    val cityName: String? = null,
    val countryCode: String? = null,
    val countryName: String? = null,
    val timezone: String? = null,
    val website: String? = null,
    val isHidden: Boolean? = null,
)

@Serializable
data class PrayerTimeCache(
    val date: Int,
    val fajr: String,
    val shurooq: String,
    val dhuhr: String,
    val asr: String,
    @SerialName("asr_mithl2") val asrMithl2: String? = null,
    val maghrib: String,
    val isha: String,
)

@Serializable
data class IqamahTimeRangeCache(
    @SerialName("date_range") val dateRange: String,
    val fajr: String,
    val dhuhr: String,
    val asr: String,
    val maghrib: String? = null,
    val isha: String,
    val jummah: String? = null,
)

@Serializable
data class MonthPrayerDataCache(
    val month: String,
    @SerialName("prayer_times") val prayerTimes: List<PrayerTimeCache>,
    @SerialName("iqamah_times") val iqamahTimes: List<IqamahTimeRangeCache>,
    @SerialName("jummah_iqamah") val jummahIqamah: String,
)

@Serializable
data class RamadanPrayerDayCache(
    @SerialName("ramadan_day") val ramadanDay: Int,
    val gregorian: String,
    val fajr: String,
    val shurooq: String,
    val dhuhr: String,
    val asr: String,
    @SerialName("asr_mithl2") val asrMithl2: String? = null,
    val maghrib: String,
    val isha: String,
)

@Serializable
data class RamadanPrayerDataCache(
    val month: String,
    @SerialName("gregorian_start") val gregorianStart: String,
    @SerialName("gregorian_end") val gregorianEnd: String,
    @SerialName("prayer_times") val prayerTimes: List<RamadanPrayerDayCache>,
    @SerialName("iqamah_times") val iqamahTimes: List<IqamahTimeRangeCache>,
    @SerialName("jummah_iqamah") val jummahIqamah: String,
)

@Serializable
data class UkDstYearCache(
    val year: Int,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String,
)

@Serializable
data class UkDstCalendarCache(
    @SerialName("uk_dst_dates") val ukDstDates: List<UkDstYearCache>,
)

fun Mosque.toCache() = MosqueCache(
    id = id, name = name, address = address, lat = lat, lng = lng, slug = slug,
    citySlug = citySlug, cityName = cityName, countryCode = countryCode,
    countryName = countryName, timezone = timezone, website = website, isHidden = isHidden,
)

fun MosqueCache.toDomain() = Mosque(
    id = id, name = name, address = address, lat = lat, lng = lng, slug = slug,
    citySlug = citySlug, cityName = cityName, countryCode = countryCode,
    countryName = countryName, timezone = timezone, website = website, isHidden = isHidden,
)

fun PrayerTime.toCache() = PrayerTimeCache(
    date = date, fajr = fajr, shurooq = shurooq, dhuhr = dhuhr, asr = asr,
    asrMithl2 = asrMithl2, maghrib = maghrib, isha = isha,
)

fun PrayerTimeCache.toDomain() = PrayerTime(
    date = date, fajr = fajr, shurooq = shurooq, dhuhr = dhuhr, asr = asr,
    asrMithl2 = asrMithl2, maghrib = maghrib, isha = isha,
)

fun IqamahTimeRange.toCache() = IqamahTimeRangeCache(
    dateRange = dateRange, fajr = fajr, dhuhr = dhuhr, asr = asr,
    maghrib = maghrib, isha = isha, jummah = jummah,
)

fun IqamahTimeRangeCache.toDomain() = IqamahTimeRange(
    dateRange = dateRange, fajr = fajr, dhuhr = dhuhr, asr = asr,
    maghrib = maghrib, isha = isha, jummah = jummah,
)

fun MonthPrayerData.toCache() = MonthPrayerDataCache(
    month = month,
    prayerTimes = prayerTimes.map { it.toCache() },
    iqamahTimes = iqamahTimes.map { it.toCache() },
    jummahIqamah = jummahIqamah,
)

fun MonthPrayerDataCache.toDomain() = MonthPrayerData(
    month = month,
    prayerTimes = prayerTimes.map { it.toDomain() },
    iqamahTimes = iqamahTimes.map { it.toDomain() },
    jummahIqamah = jummahIqamah,
)

fun RamadanPrayerDay.toCache() = RamadanPrayerDayCache(
    ramadanDay = ramadanDay, gregorian = gregorian, fajr = fajr, shurooq = shurooq,
    dhuhr = dhuhr, asr = asr, asrMithl2 = asrMithl2, maghrib = maghrib, isha = isha,
)

fun RamadanPrayerDayCache.toDomain() = RamadanPrayerDay(
    ramadanDay = ramadanDay, gregorian = gregorian, fajr = fajr, shurooq = shurooq,
    dhuhr = dhuhr, asr = asr, asrMithl2 = asrMithl2, maghrib = maghrib, isha = isha,
)

fun RamadanPrayerData.toCache() = RamadanPrayerDataCache(
    month = month, gregorianStart = gregorianStart, gregorianEnd = gregorianEnd,
    prayerTimes = prayerTimes.map { it.toCache() },
    iqamahTimes = iqamahTimes.map { it.toCache() },
    jummahIqamah = jummahIqamah,
)

fun RamadanPrayerDataCache.toDomain() = RamadanPrayerData(
    month = month, gregorianStart = gregorianStart, gregorianEnd = gregorianEnd,
    prayerTimes = prayerTimes.map { it.toDomain() },
    iqamahTimes = iqamahTimes.map { it.toDomain() },
    jummahIqamah = jummahIqamah,
)

fun UkDstYear.toCache() = UkDstYearCache(year = year, startDate = startDate, endDate = endDate)

fun UkDstYearCache.toDomain() = UkDstYear(year = year, startDate = startDate, endDate = endDate)

fun UkDstCalendar.toCache() = UkDstCalendarCache(ukDstDates = ukDstDates.map { it.toCache() })

fun UkDstCalendarCache.toDomain() = UkDstCalendar(ukDstDates = ukDstDates.map { it.toDomain() })
