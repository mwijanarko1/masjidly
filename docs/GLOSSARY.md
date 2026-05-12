# Glossary — Masjidly

Shared domain vocabulary for the Masjidly prayer-times app. Terms are used consistently across native iOS, Expo Android, documentation, and tests.

---

## Mosque

A place of worship with an official prayer timetable. In the Convex backend, each mosque has a unique `slug`, `name`, `address`, and geographic coordinates (`lat`, `lng`). Some mosques may be `isHidden` and are excluded from user-facing lists.

## Selected Mosque

The mosque whose prayer times are currently displayed. Persisted as `selectedMosqueId` + `selectedMosqueSlug`. Resolution precedence:
1. Visible mosque by persisted `id`
2. Visible mosque by persisted `slug`
3. Visible mosque with default slug (`muslim-welfare-house`)
4. First visible mosque

## Prayer Time

Also called **Adhan** time. The canonical time for a daily prayer as published by the selected mosque. Prayers are: Fajr, Sunrise (Shurooq), Dhuhr, Asr, Maghrib, Isha.

## Adhan

The call to prayer. In the app, "adhan time" refers to the published start time for each prayer.

## Iqamah

The congregation time when the prayer actually begins inside the mosque. Iqamah may be expressed as:
- An absolute time (`13:30`)
- Relative to adhan (`adhan + 5 mins`, `5 minutes after adhan`)
- Special values (`sunset`, `Entry Time`, `Straight after Maghrib`, `Various`)

## Jummah

The Friday congregational prayer that replaces Dhuhr. In next-prayer and notification logic, Friday Dhuhr is treated as Jummah. The timetable still shows a Jummah row every day (with `-` on non-Fridays), matching native iOS behavior.

## Ramadan Timetable

A special prayer schedule used during Ramadan. Overrides regular monthly prayer times for days within the Ramadan date range. Includes separate iqamah ranges and may have different adhan times.

## UK DST Calendar

A record of UK Daylight Saving Time start/end dates per year. Used by `PrayerTimesEngine` to:
- Detect March/October DST transition weeks
- Remap embedded DST timetables (e.g., Masjid Al-Huda)
- Adjust iqamah lookups to April/November rows during transition periods

## PrayerTimesEngine

The core calculation module (Swift enum / TypeScript namespace) that:
- Resolves daily prayer times from monthly or Ramadan data
- Computes iqamah times with DST mapping
- Determines the next upcoming prayer and countdown
- Formats times to 12-hour or 24-hour display
- Handles Masjid Risalah special cases and summer Isha overrides

## Qibla Direction

The bearing from a location toward the Kaaba in Makkah. In the native iOS home screen, the Qibla indicator uses the device location and heading when permission is granted, and falls back to selected mosque coordinates when current location is unavailable.

## MonthPrayerData

A month's worth of prayer times and iqamah ranges from Convex. Contains:
- `prayerTimes`: sparse array of `PrayerTime` rows (not every day may be present)
- `iqamahTimes`: array of `IqamahTimeRange` covering date ranges within the month
- `jummahIqamah`: fallback Jummah time string

## DailyPrayerTimes / DailyIqamahTimes

Resolved per-day objects after engine processing. `DailyPrayerTimes` includes all six canonical prayers. `DailyIqamahTimes` includes iqamah for Fajr, Dhuhr, Asr, Maghrib, Isha, and Jummah.

## NextPrayerCountdownResult

The engine's output for the next upcoming prayer. Contains:
- `nextName`: prayer name (e.g., "Asr" or "Jummah")
- `nextTime`: the adhan or iqamah time string
- `totalSeconds`: seconds until that time
- `isIqamah`: true if the next event is iqamah rather than adhan
- `isJummah`: true if the next prayer is Jummah
