package com.mikhailspeaks.masjidly.data.convex

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

@Serializable
data class ConvexQueryResponse(
    val status: String,
    val value: JsonElement? = null,
    val errorMessage: String? = null,
)

@Serializable
data class MosqueWire(
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
    @SerialName("is_hidden") val isHiddenSnake: Boolean? = null,
    @SerialName("city_slug") val citySlugSnake: String? = null,
    @SerialName("city_name") val cityNameSnake: String? = null,
    @SerialName("country_code") val countryCodeSnake: String? = null,
    @SerialName("country_name") val countryNameSnake: String? = null,
)

@Serializable
data class PrayerTimeWire(
    val date: Double,
    val fajr: String,
    val shurooq: String,
    val dhuhr: String,
    val asr: String,
    @SerialName("asr_mithl2") val asrMithl2: String? = null,
    val maghrib: String,
    val isha: String,
)

@Serializable
data class IqamahTimeRangeWire(
    @SerialName("date_range") val dateRange: String,
    val fajr: JsonElement,
    val dhuhr: JsonElement,
    val asr: JsonElement,
    val maghrib: JsonElement? = null,
    val isha: JsonElement,
    val jummah: JsonElement? = null,
)

@Serializable
data class MonthPrayerDataWire(
    val month: String,
    @SerialName("prayer_times") val prayerTimes: List<PrayerTimeWire>,
    @SerialName("iqamah_times") val iqamahTimes: List<IqamahTimeRangeWire>,
    @SerialName("jummah_iqamah") val jummahIqamah: String,
)

@Serializable
data class RamadanPrayerDayWire(
    @SerialName("ramadan_day") val ramadanDay: Double,
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
data class RamadanPrayerDataWire(
    val month: String,
    @SerialName("gregorian_start") val gregorianStart: String,
    @SerialName("gregorian_end") val gregorianEnd: String,
    @SerialName("prayer_times") val prayerTimes: List<RamadanPrayerDayWire>,
    @SerialName("iqamah_times") val iqamahTimes: List<IqamahTimeRangeWire>,
    @SerialName("jummah_iqamah") val jummahIqamah: String,
)

@Serializable
data class UkDstYearWire(
    val year: Double,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String,
)

@Serializable
data class UkDstCalendarWire(
    @SerialName("uk_dst_dates") val ukDstDates: List<UkDstYearWire>,
)

fun decodeIqamahValue(element: JsonElement): String {
    if (element is JsonNull) return ""
    return when (element) {
        is JsonPrimitive -> element.contentOrNull ?: ""
        is JsonArray -> element.mapNotNull { it.jsonPrimitive.contentOrNull }.joinToString(", ")
        else -> element.toString()
    }
}
