# Swift MVP Plan — Sheffield Masjids App

## Summary

Build the Swift-only MVP as a native SwiftUI app with two tabs:

- **Home**: selected mosque’s daily prayer dashboard, powered by the same Sheffield-Masjids Convex backend.
- **Settings**: mosque selector, 12/24-hour format toggle, and real local prayer notification controls.

Expo stays untouched for now.

## Key Decisions

- Use the deployed Sheffield-Masjids backend, not the older `Masjid-Risalah-App` Convex backend.
- Use Convex Swift via SPM package `https://github.com/get-convex/convex-swift`, product `ConvexMobile`.
- Use:
  - Debug: `https://upbeat-goat-583.eu-west-1.convex.cloud`
  - Release: `https://zany-mockingbird-207.eu-west-1.convex.cloud`
- Default mosque: `muslim-welfare-house`, matching the website.
- No legal links in Settings.
- Notifications are real local iOS notifications, not placeholders.
- No Expo work in this phase.

## Backend Contract

Use existing Convex public queries from `/Users/mikhail/Documents/CURSOR CODES/Deployed/Sheffield-Masjids`:

- `mosques:list`
  - Args: `{}`
  - Returns visible and hidden mosque records; app filters hidden mosques client-side.
- `prayerTimes:getMonthly`
  - Args: `{ mosqueSlug: String, month: String, year: Int? }`
  - Month values: lowercase English names, e.g. `may`.
- `prayerTimes:getRamadan`
  - Args: `{ mosqueSlug: String, date: String? }`
  - Date format: `YYYY-MM-DD`.
- `prayerTimes:getUkDstDates`
  - Args: `{}`

Swift models must mirror the website Convex return shapes:

- `Mosque`
- `MonthPrayerData`
- `RamadanPrayerData`
- `PrayerTime`
- `IqamahTimeRange`
- `DailyPrayerTimes`
- `DailyIqamahTimes`
- `UkDstCalendar`

## Swift App Structure

Create feature-first folders inside the Swift target:

- `App/`
  - `MasjidlyApp.swift`
  - `AppEnvironment.swift`
  - `ConvexConfiguration.swift`
- `Features/Home/`
  - `HomeView.swift`
  - `HomeViewModel.swift`
  - `PrayerTimesEngine.swift`
  - `SunPathView.swift` if included in MVP polish
- `Features/Settings/`
  - `SettingsView.swift`
  - `SettingsViewModel.swift`
- `Features/Notifications/`
  - `PrayerNotificationScheduler.swift`
  - `NotificationSettings.swift`
- `Data/Convex/`
  - `ConvexService.swift`
  - `ConvexPrayerRepository.swift`
- `Data/Persistence/`
  - `SettingsStore.swift`
  - optional `PrayerCacheStore.swift`
- `Domain/`
  - shared models and date/time helpers

Use SwiftUI Observation or `@Observable` view models if the project toolchain supports it; otherwise use `ObservableObject` conservatively.

## Public Interfaces

Add protocol boundaries for testability:

```swift
protocol PrayerRepository {
    func listMosques() async throws -> [Mosque]
    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData?
    func getRamadanTimetable(mosqueSlug: String, date: LocalDate?) async throws -> RamadanPrayerData?
    func getUkDstDates() async throws -> UkDstCalendar?
}

protocol SettingsPersisting {
    var selectedMosqueId: String? { get set }
    var uses24HourTime: Bool { get set }
    var notifications: NotificationSettings { get set }
}

protocol PrayerNotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings
    ) async throws
    func cancelAllPrayerNotifications() async
}
```

## Home MVP Behavior

Home should:

- Load mosque list from Convex.
- Pick persisted mosque if valid; otherwise default to `muslim-welfare-house`; otherwise first visible mosque.
- Fetch monthly prayer data for selected mosque and today’s Sheffield month/year.
- Fetch Ramadan timetable for selected mosque using today’s `YYYY-MM-DD`.
- Fetch UK DST dates and apply the website’s DST rules.
- Display:
  - selected mosque name
  - Gregorian date
  - optional Hijri date if implementable without adding risky dependencies
  - next prayer or iqamah countdown
  - daily rows for Fajr, Sunrise, Dhuhr/Jummah, Asr, Maghrib, Isha
  - adhan and iqamah columns
  - loading, offline/cache, empty, and error states
- Support manual refresh.

## Settings MVP Behavior

Settings should include:

- Primary mosque picker populated from Convex `mosques:list`, excluding `isHidden == true`.
- 12/24-hour time toggle.
- Master notifications toggle.
- Per-prayer toggles:
  - Fajr
  - Dhuhr/Jummah
  - Asr
  - Maghrib
  - Isha
- When notifications are enabled:
  - request iOS notification permission
  - schedule the next 7 days of local notifications from selected mosque prayer data
  - reschedule when selected mosque, time data, or notification preferences change
- When notifications are disabled:
  - cancel scheduled prayer notifications.

No legal links for MVP.

## Local Persistence

Use `UserDefaults` for non-sensitive MVP settings:

- selected mosque ID
- selected mosque slug if useful for migration
- 12/24-hour preference
- notification master/per-prayer toggles
- last successful mosque list cache timestamp if implemented

Use a small JSON cache for last successful prayer data if time allows. Cache is useful because the website has static fallback, but the Swift app will be Convex-first.

## Implementation Steps

1. Remove starter SwiftData sample model usage from the app shell.
2. Add Convex Swift SPM dependency.
3. Add Debug/Release Convex URL configuration.
4. Build domain models matching Sheffield-Masjids Convex responses.
5. Build `ConvexPrayerRepository`.
6. Port the website prayer-time engine into Swift:
   - Sheffield timezone handling
   - monthly vs Ramadan selection
   - iqamah range resolution
   - Jummah handling
   - special Isha display rules
   - DST adjustments
7. Build settings persistence.
8. Build Home view model and UI.
9. Build Settings view model and UI.
10. Add local notification scheduler.
11. Wire tab navigation with Home and Settings only.
12. Add focused tests before production behavior changes.
13. Run iOS build and simulator smoke test.

## Tests

Use Swift Testing for new unit tests.

Required tests:

- Decoding:
  - `Mosque` decodes Convex mosque records.
  - monthly prayer data decodes website backend shape.
  - Ramadan timetable decodes website backend shape.
- Prayer engine:
  - resolves exact date prayer times.
  - falls back to closest previous sparse row when needed, matching website behavior.
  - resolves iqamah ranges.
  - handles Jummah on Friday.
  - handles special values: `sunset`, `Entry Time`, `Straight after Maghrib`, `After Maghrib`.
  - applies Masjid Risalah Isha special period.
  - applies DST correction rules using `ukDstCalendar`.
- Settings:
  - selected mosque persists and reloads.
  - invalid persisted mosque falls back to website default.
  - 12/24-hour setting changes formatting.
- Notifications:
  - disabled master switch cancels scheduled notifications.
  - per-prayer toggles only schedule enabled prayers.
  - next 7 days scheduling uses selected mosque data.

UI smoke tests:

- App launches to Home.
- Settings tab opens.
- Mosque selector changes selected mosque.
- Home reflects selected mosque after returning from Settings.

## Acceptance Criteria

- Swift app compiles and launches.
- Only Home and Settings are visible.
- Home data comes from Sheffield-Masjids Convex.
- Changing mosque in Settings changes Home prayer times.
- Time format toggle changes displayed times.
- Notification permission flow works.
- Enabled prayer notifications are scheduled locally for the selected mosque.
- Expo app remains untouched.

## Assumptions

- The Swift target remains iOS-only for MVP.
- No authentication is required because current Sheffield-Masjids read queries are public.
- Hidden mosques should not appear in the selector.
- The app should prefer live Convex data and only cache locally as resilience, not as a separate source of truth.
- Convex Swift `ConvexClient` subscriptions are suitable for live query updates, per official Convex Swift docs: https://docs.convex.dev/client/swift
