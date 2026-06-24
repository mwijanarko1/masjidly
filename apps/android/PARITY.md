# Android ↔ iOS Feature Parity Tracker

**Source of truth:** native iOS SwiftUI (`Masjidly - Official Masjid Prayer Times/`)  
**Backend:** Convex (same queries as iOS `ConvexPrayerRepository.swift`)

Status key: **done** · **partial** · **missing**

---

## Convex data contract (shared)

| Query | Args | Used by |
|-------|------|---------|
| `mosques:list` | `{}` | Home load, settings mosque list, onboarding |
| `prayerTimes:getMonthly` | `mosqueSlug`, `month` (string enum), `year` (number as double) | Home, timetable, notifications |
| `prayerTimes:getRamadan` | `mosqueSlug`, optional `date` (ISO) | Home, timetable (Ramadan rows) |
| `prayerTimes:getUkDstDates` | `{}` | Engine DST / iqamah mapping |

Android implementation: `ConvexHttpClient` → official Convex HTTP `/api/query` (same paths/args as iOS ConvexMobile). No alternate API.

---

## App shell & navigation

| iOS | Android | Status | Convex |
|-----|---------|--------|--------|
| `MasjidlyRootView` — locale, update alert, adhan mini-player inset | `MasjidlyApp` + `MainActivity` | **done** | — |
| `HomeView` full-screen root | `HomeScreen` | **partial** | live mosque + times |
| `TimetableView` full-screen cover | `TimetableScreen` | **done** | monthly fetch |
| `SettingsView` full-screen cover | `SettingsScreen` | **partial** | mosque list + pickers |
| `AdhanMiniPlayerBar` bottom inset | `AdhanMiniPlayerBar` | **done** | — |
| `WhatsNewModalView` overlay | `WhatsNewOverlay` | **done** | — |
| In-app update alert (`AppUpdateChecker`) | `UpdateChecker` + `UpdatePromptDialog` | **done** | fetches `latest.json` |

---

## Home (`HomeView` / `HomeViewModel`)

| Feature | iOS | Android | Status | Convex |
|---------|-----|---------|--------|--------|
| Load mosques + resolve selection | `HomeViewModel.load` | `HomeViewModel.load` | **done** | `mosques:list` |
| Monthly + Ramadan + UK DST fetch | `refreshPrayerPayload` | `refreshPrayerPayload` | **done** | all four queries |
| `PrayerTimesEngine` resolution | Swift engine | Kotlin port of Swift engine | **done** | — |
| Prayer hero + sky theme per selected prayer | `HomeDesign.TimeTheme` | `TimeTheme` + settings fixed/dynamic | **done** | — |
| Horizontal prayer carousel (6 incl. Sunrise) | `PrayerCarouselItem` | letter picker strip | **partial** | — |
| Hero countdown ring / progress | `heroCountdownPresentation` + tap/long-press | `QiblaPrayerIcon` + engine APIs | **done** | — |
| Date chrome (prev/next, calendar, hijri) | arrows + `dateDisplay` | top chrome grouped navigator + Umm al-Qura hijri | **done** | — |
| Qibla compass + `QiblaPrayerIcon` | rings always; pointer when location allowed | `QiblaPrayerIcon` + sensor provider | **done** | — |
| Quick info (midnight, last third) | `QuickInfoItem` | midnight / last-third cards | **partial** | — |
| Prayer illustrations (Fajr–Isha assets) | no separate hero assets in repo | Compose sun-phase art | **done** | — |
| Missing-month / error recovery UI | dedicated views | missing month + retry + email | **partial** | — |
| Disk cache SWR (`PrayerTimesDiskCache`) | yes | `PrayerTimesDiskCache` JSON | **done** | — |
| Foreground stale refresh | `refreshFromNetworkIfStale` | `ON_RESUME` in `MasjidlyApp` | **done** | — |
| Widget snapshot write | `WidgetPrayerSnapshotService` | `WidgetPrayerSnapshotService` | **done** | — |
| Enjoyment / App Store review prompts | `AppReviewPromptCoordinator` | soft prompt + Android review intent | **done** | — |
| Notification permission recovery modal | yes | — | **missing** | — |

---

## Timetable (`TimetableView`)

| Feature | iOS | Android | Status | Convex |
|---------|-----|---------|--------|--------|
| Month switcher + year | yes | yes | **done** | `getMonthly` per month |
| Date strip / day selection | yes | yes | **done** | — |
| Prayer rows (adhan + iqamah) | yes | yes | **done** | — |
| Ramadan timetable mode | yes | via engine on monthly rows | **partial** | `getRamadan` |
| Friday / Jummah iqamah slots | yes | yes | **done** | — |
| DST embedded timetable (Al-Huda) | engine | engine ported | **done** | — |
| Pull to refresh | yes | `PullToRefreshBox` | **done** | — |
| Next-prayer highlight / past dimming | yes | yes | **done** | — |
| Midnight / last third rows | yes | yes | **done** | — |
| Localized labels (en/ar/ur/id) | yes | `LocaleStrings` | **done** | — |
| Missing-month email CTA (styled) | yes | yes | **done** | — |
| Date strip scroll-to-selected | yes | yes | **done** | — |
| iOS layout (24dp chrome, 70dp cells) | yes | yes | **done** | — |

---

## Settings (`SettingsView` / `SettingsViewModel`)

| Feature | iOS | Android | Status | Convex |
|---------|-----|---------|--------|--------|
| Country picker | yes | yes | **done** | `mosques:list` |
| City picker | yes | yes | **done** | `mosques:list` |
| Mosque picker | yes | yes | **done** | `mosques:list` |
| Closest mosque (location) | yes | GPS/network location distance | **done** | `mosques:list` |
| 24-hour time toggle | yes | yes | **done** | — |
| Language (en/ar/ur/id) + RTL | yes | persisted + `LayoutDirection` | **partial** | — |
| Theme mode (dynamic / fixed) | yes | yes | **done** | — |
| Per-prayer sky gradients (Original / Modern) | yes | yes | **done** | — |
| Asr iqamah preference (1st/2nd) | yes | yes | **done** | — |
| Qibla hide / location recovery | yes | toggle + open settings; orb stays, pointer hidden | **done** | — |
| Per-prayer notification toggles | yes | persisted UI (no scheduler) | **partial** | — |
| Pre-reminder minutes | yes | yes | **done** | — |
| Adhan sound preview | `AdhanSoundPreviewPlayer` | toast stub | **partial** | — |
| Support email | `MasjidlySupportMail` | mailto buttons | **partial** | — |
| About / version | yes | yes | **done** | — |
| Developer test buttons | yes | test tutorial, notifications, what's new, update, review | **done** | — |
| `SettingsStore` persistence | UserDefaults | SharedPreferences + JSON notifications + review/what's-new state | **done** | — |

---

## Onboarding (`OnboardingFlowController`)

| Step | iOS | Android | Status | Convex |
|------|-----|---------|--------|--------|
| Language selection | `LanguageSelectionOnboardingView` | `LanguageSelectionOnboardingScreen` | **done** | — |
| Mosque selection | `MosqueSelectionOnboardingView` | `MosqueSelectionOnboardingScreen` | **done** | `mosques:list` |
| Prayer carousel coach marks | `OnboardingCoachMarkView` | `OnboardingCoachMarkView` | **done** | — |
| Qibla intro | coach mark | coach mark | **done** | — |
| Timetable tour | coach mark | `TimetableOnboardingOverlay` | **done** | — |
| Settings tour | coach mark | `SettingsOnboardingOverlay` | **done** | — |
| Notification setup | `OnboardingNotificationSetupView` | `OnboardingNotificationSetupScreen` | **done** | — |
| `hasCompletedOnboarding` flag | yes | yes | **done** | — |
| Dev restart tutorial | yes | yes | **done** | — |

---

## Notifications

| Feature | iOS | Android | Status | Convex |
|---------|-----|---------|--------|--------|
| Category/action IDs | `PrayerNotificationContent` | `PrayerNotificationContent.kt` | **done** | — |
| 7-day schedule (adhan + iqamah + reminders) | `PrayerNotificationScheduler` | `PrayerNotificationScheduler.kt` | **done** | monthly data |
| Snooze / quick actions | yes | notification actions + 10-min snooze | **done** | — |
| Reschedule on settings change | yes | yes | **done** | — |
| Android notification channels | N/A | `prayer-times` channel | **done** | — |

---

## Audio

| Feature | iOS | Android | Status |
|---------|-----|---------|--------|
| Adhan preview in settings | yes | bundled MediaPlayer preview | **done** |
| In-app adhan playback + mini player | `AdhanMiniPlayerBar` | **done** |
| Notification adhan sounds | iOS uses system default; full adhan in-app | Android uses system default; full adhan in-app | **done** |

---

## Widgets

| Feature | iOS | Android | Status | Convex |
|---------|-----|---------|--------|--------|
| Home screen widget (small / medium / large) | `MasjidlyWidgets` | `MasjidlyPrayerWidget` (Glance) | **done** | prayer payload |
| Widget timeline refresh | `WidgetPrayerSnapshotService` | `WidgetPrayerSnapshotService` | **done** | — |

---

## Updates & release

| Feature | iOS | Android | Status |
|---------|-----|---------|--------|
| `latest.json` check | `AppUpdateChecker` | `UpdateChecker` | **done** |
| APK sideload (Android) | N/A | opens manifest APK URL | **done** |
| App Store prompt (iOS) | yes | N/A | — |
| What's New modal | `WhatsNewModalView` | **done** |

---

## Domain / data layer (Android)

| iOS | Android | Status |
|-----|---------|--------|
| `PrayerModels.swift` | `PrayerModels.kt` | **done** |
| `PrayerTimesEngine.swift` | `PrayerTimesEngine.kt` | **done** |
| `MosqueDefaults.swift` | `MosqueSelection.kt` | **done** |
| `PrayerRepository` protocol | `PrayerRepository.kt` | **done** |
| `ConvexPrayerRepository` | `ConvexPrayerRepository.kt` | **done** |
| `PrayerTimesDiskCache` | `PrayerTimesDiskCache.kt` | **done** |
| `SettingsStore` full | `SettingsStore.kt` | **partial** |
| `AppLanguage` | `AppLanguage.kt` | **done** |
| `NotificationSettings` | `NotificationSettings.kt` | **done** |

---

## This slice (implemented now)

1. **Timetable iOS parity** — localized strings (`LocaleStrings`), 24dp chrome, 70×48 date cells with scroll-to-selected, chevron month switcher (44dp), styled missing-month CTA, `MasjidlySupportMail` missing-times email, initial month/day from home `displayedDate` + `monthData`.
2. **`PrayerSunPhaseIcon`** — theme-specific sun/moon line art (Fajr–Isha) matching iOS `PrayerSunPhaseIcon`.
2. **`QiblaPrayerIcon`** — concentric rings, sun-phase center, optional Qibla pointer, hero countdown ring/label/time with tap + long-press lock.
3. **Home Qibla parity** — orb always visible when compass hidden (`hideQiblaCompass`); pointer only when location allowed.
4. **Hero countdown** — wired to `PrayerTimesEngine.heroCountdownPresentation` / `formatHeroCountdownClock` / `heroProgress01`.

Prior slices still in place: disk cache SWR, settings/timetable shells, foreground stale refresh.

Build verified: `cd apps/android && ./gradlew :app:assembleDebug` ✅

---

## Known blockers / decisions

| Item | Notes |
|------|-------|
| Convex Android AAR vs HTTP | Using **official HTTP `/api/query`**; same function paths as iOS. |
| Gill Sans font | Bundled in `res/font/`; `rememberAppTextStyle` mirrors iOS `appFont` + locale scaling. |
| Prayer hero PNGs | No prayer hero PNGs are present in the iOS asset catalog; Android uses the Compose `PrayerSunPhaseIcon` parity path. |
| Localized strings | iOS `LocaleBundle`; Android uses English labels + locale-aware formatters only. |
| Qibla accuracy | Requires runtime location permission; compass uses rotation vector + mosque lat/lng fallback. |
| Closest mosque | Android now uses GPS/network location distance in settings. |
| Notifications | `PrayerNotificationScheduler` + channels wired; snooze/quick actions still iOS-only. |
| Adhan audio | No `.caf`/`.ogg` assets in `res/raw` yet — preview is a stub. |
| `latest.json` / APK update | `UpdateChecker` documents URL only; no in-app prompt or sideload flow. |
| iOS-only targets | Watch, widgets — out of scope for Android v1 unless product asks. |

---

## Suggested next slices (priority)

1. `PrayerNotificationScheduler` + Android notification channels.
2. `latest.json` update prompt + APK download intent.
3. Copy prayer hero PNGs + Gill Sans (optional).
4. Full `LocaleBundle` string tables (ar/ur/id).
5. Onboarding flow shell.
6. Home screen widget (Glance).
