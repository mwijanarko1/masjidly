---
last_mapped: 2026-06-23T00:00:00Z
---

# Codebase Map — Masjidly (Native SwiftUI + Native Android Kotlin)

## System Overview

Masjidly is a **native iOS app** (SwiftUI, `@Observable`) that displays official mosque prayer times with a light weather-inspired UI. It fetches prayer/iqamah data from a **Convex** backend, computes next-prayer state locally via `PrayerTimesEngine`, schedules local notifications, persists user preferences in `SettingsStore`, includes a **Qibla compass**, and offers a **multi-step onboarding tutorial**.

A **native Android app** lives under `apps/android/` (Kotlin + Jetpack Compose). It mirrors the iOS architecture and feature set; see `apps/android/PARITY.md` for the parity tracker.

---

## Directory Guide

```
Masjidly - Official Masjid Prayer Times/              # Native iOS target
├── Masjidly___Official_Masjid_Prayer_TimesApp.swift   # @main entry — wires AppEnvironment, registers notification categories
├── App/
│   ├── MasjidlyRootView.swift                         # Root view — wraps HomeView with locale, onboarding, adhan mini-player
│   ├── AppEnvironment.swift                           # @Observable root DI container (settings, convex, repos, notification scheduler)
│   └── ConvexConfiguration.swift                      # Convex deployment URL constants
├── Domain/                                            # Business models & rules
│   ├── PrayerModels.swift                             # Mosque, PrayerTime, IqamahTimeRange, RamadanPrayerData, DailyPrayerTimes, UkDstCalendar
│   ├── PrayerRepository.swift                         # Protocol for prayer data access
│   ├── PrayerLocalization.swift                       # Canonical prayer name → localization key mapping
│   ├── MosqueDefaults.swift                           # Default mosque selection logic
│   ├── MonthName.swift                                # Hijri/Gregorian month name helpers
│   └── AppLanguage.swift                              # Language enum + resolved locale helpers
├── Data/
│   ├── Convex/
│   │   ├── ConvexService.swift                        # Convex client wrapper
│   │   ├── ConvexPrayerRepository.swift               # Convex-backed PrayerRepository implementation
│   │   └── ConvexClient+SubscribeFirst.swift          # Convex subscription helper extension
│   └── Persistence/
│       ├── SettingsStore.swift                        # @Observable UserDefaults-backed user preferences
│       └── PrayerTimesDiskCache.swift                 # Atomic JSON file cache (mosques, monthly, ramadan, UK DST) in Application Support
├── Features/
│   ├── Home/                                          # Main prayer times screen
│   ├── Settings/                                      # Mosque picker, notifications, language, Qibla
│   ├── Notifications/                                 # Local notification scheduling
│   ├── Onboarding/                                    # First-launch tutorial flow
│   ├── Audio/                                         # Adhan mini-player
│   └── Widgets/                                       # iOS widget snapshot service
├── Assets.xcassets/                                   # App icon, accent color, prayer illustrations (Fajr–Isha)
├── Fonts/                                             # Comfortaa font files + archive
├── Icons/                                             # Prayer PNG icons (fajr, dhuhr, asr, maghrib, isha)
├── Resources/                                         # Adhan audio files (Adhan-1.caf, Adhan-2.caf)
└── Localizable.xcstrings                              # String catalog for i18n

apps/android/                                          # Native Android app (Kotlin + Jetpack Compose)
├── app/src/main/kotlin/com/mikhailspeaks/masjidly/
│   ├── MasjidlyApp.kt                                 # Application entry
│   ├── MainActivity.kt                                # Single-activity Compose host
│   ├── domain/                                        # Models, PrayerTimesEngine, localization
│   ├── data/                                          # Convex HTTP client, SettingsStore, disk cache
│   ├── features/                                      # home, timetable, settings, onboarding, notifications, qibla, updates, audio
│   ├── ui/                                            # theme tokens, navigation, home design components
│   └── widget/                                        # Glance home-screen widget
├── app/src/main/res/                                  # launcher icons, fonts, adhan audio, widget XML
├── PARITY.md                                          # iOS ↔ Kotlin feature parity tracker
└── README.md                                          # Gradle build instructions

docs/                                                  # Project documentation
├── DESIGN.md                                          # Visual design tokens (colors, typography, layout)
├── CODEBASE_MAP.md                                    # This file
├── GLOSSARY.md                                        # Shared domain vocabulary
├── build-android-release.md                           # Release APK build steps
├── swift-mvp-plan-sheffield-masjids-app.md            # Original MVP planning doc
└── minimal-prayer-times-home-redesign.md              # Home screen redesign spec

Masjidly - Official Masjid Prayer TimesTests/          # Unit tests
Masjidly - Official Masjid Prayer TimesUITests/        # UI tests
MasjidlyWidgets/                                       # iOS Home Screen widgets
MasjidlyWidgetSupport/                                 # Shared support for widgets
```

---

## Key Workflows

### App Boot (Native iOS)
1. `@main` app creates `AppEnvironment`, which instantiates `SettingsStore` → `ConvexService` → `ConvexPrayerRepository` + `PrayerTimesDiskCache` → `PrayerNotificationScheduler`
2. App registers notification category/action definitions from `PrayerNotificationContent`
3. `MasjidlyRootView` wraps `HomeView` with forced `en` locale + `LTR` layout
4. `OnboardingFlowController` checks `settings.hasCompletedOnboarding`; if `false` and mosques are loaded, presents the tutorial sequence
5. `AdhanMiniPlayerBar` is shown in the bottom safe area inset when audio playback is active

### App Boot (Native Android)
1. `MasjidlyApp` initializes `SettingsStore` and notification channels
2. `MainActivity` hosts `MasjidlyNavHost` (Compose Navigation)
3. `HomeViewModel` loads mosque list via `ConvexPrayerRepository`, resolves selected mosque, fetches month/Ramadan/DST data
4. `PrayerTimesEngine` computes next prayer; `HomeScreen` renders hero, carousel, and Qibla
5. `OnboardingFlowViewModel` presents tutorial when `hasCompletedOnboarding` is false
6. `PrayerNotificationScheduler` schedules alarms; `UpdateChecker` fetches `latest.json` on launch

### Prayer Time Display
1. `HomeViewModel` (iOS) / `HomeViewModel` (Android) loads mosque data via repository
2. `PrayerTimesEngine` computes the next prayer from today's `DailyPrayerTimes` + `DailyIqamahTimes`
3. UI renders hero illustration, large next-prayer time, quick-info metrics, and horizontal prayer carousel
4. User taps a prayer in the carousel to select; engine recalculates

### Data Fetching & Caching
- **Convex queries** for mosque list, monthly prayer times, iqamah times, and Ramadan data
- **iOS** uses `ConvexPrayerRepository` (subscription-based) + `PrayerTimesDiskCache` (atomic JSON file cache in Application Support) for offline resilience
- **Android** uses `ConvexPrayerRepository` (HTTP query client) + disk cache for offline resilience
- `ConvexClient+SubscribeFirst.swift` provides a `subscribeFirst` helper for one-shot subscription results

### Notifications
- **iOS**: `PrayerNotificationContent` defines standardized category/action IDs, sound wiring, and userInfo keys. `PrayerNotificationScheduler` schedules `UNNotificationRequest` entries for 7 days of adhan + iqamah + pre-reminders.
- **Android**: `PrayerNotificationScheduler` handles channel setup, schedule/cancel, and 7-day scheduling via alarm manager.

### Onboarding Tutorial Flow (both platforms)
1. **Choose Mosque** — select from loaded mosque list
2. **Prayer Shortcut** — sequential tap-through of each prayer in the carousel
3. **Qibla** — intro to Qibla compass
4. **Open Timetable** → explore → close
5. **Open Settings** → explore → close
6. **Notifications** — configure adhan/iqamah toggles, pre-reminder minutes, authorize permissions
7. Marks `hasCompletedOnboarding = true`, exits tutorial

### Qibla Direction
- **iOS**: `QiblaDirectionCalculator` computes bearing from device location to Kaaba. `QiblaPrayerIcon` renders compass via Canvas.
- **Android**: `QiblaDirection` + `QiblaPrayerIcon` mirror the same bearing formula and compass UI.

### Settings
- **iOS**: `SettingsView` includes mosque picker, notification toggles (per-prayer), language selector, 24h toggle, Qibla toggle, adhan sound preview, support mail, app review prompt, about section
- **Android**: `SettingsScreen` replicates the same settings surface
- **Persistence**: `SettingsStore` on both platforms (UserDefaults on iOS, DataStore/SharedPreferences on Android)

### Widgets
- **iOS**: `MasjidlyWidgets` target provides home screen widgets via `WidgetPrayerSnapshotService`
- **Android**: `MasjidlyPrayerWidget` (Glance) reads from `WidgetSnapshotStore`

### Audio
- **iOS**: `AdhanSoundPreviewPlayer` + `AdhanMiniPlayerBar`
- **Android**: adhan playback + mini-player bar in Compose

---

## Architecture Patterns

| Layer (iOS) | Pattern | Files |
|-------|---------|-------|
| Entry | `@main` SwiftUI App | `Masjidly___Official_Masjid_Prayer_TimesApp.swift` |
| Root | Locale/LTR wrapper + safe-area chrome | `App/MasjidlyRootView.swift` |
| DI | `@Observable` AppEnvironment | `App/AppEnvironment.swift` |
| Domain | Value types + protocol | `Domain/PrayerModels.swift`, `PrayerRepository.swift` |
| Data | Convex subscription → Repository + Disk Cache | `Data/Convex/*.swift`, `PrayerTimesDiskCache.swift` |
| Feature VM | `@Observable` view models | `Features/*/HomeViewModel.swift`, `SettingsViewModel.swift` |
| UI | SwiftUI views + design tokens | `Features/*/*.swift`, `HomeDesign.swift` |

| Layer (Android) | Pattern | Files |
|-------|---------|-------|
| Entry | Application + Single Activity | `MasjidlyApp.kt`, `MainActivity.kt` |
| Domain | Data classes + engine | `domain/PrayerModels.kt`, `PrayerTimesEngine.kt` |
| Data | Convex HTTP → Repository + disk cache | `data/convex/ConvexPrayerRepository.kt` |
| Feature VM | ViewModel + StateFlow | `features/home/HomeViewModel.kt` |
| UI | Jetpack Compose + design tokens | `features/*/`, `ui/theme/` |

---

## Known Risks

- **`xcuserdata` tracked in git** — Xcode user data is committed; consider adding to `.gitignore`
- **PrayerTimesEngine** handles DST, time parsing, and next-prayer logic; the largest single domain module in both codebases
- **iOS tests**: 3 test files (`MasjidlyTests`, `PrayerNotificationSchedulerTests`, `WidgetPrayerSnapshotTests`)
- **Convex backend** is external; no local Convex functions or schema definitions in this repo
- **PrayerTimesDiskCache** uses atomic writes via temp file + `replaceItemAt`; cache invalidation / staleness logic is manual (no TTL)
- **Onboarding flow** in both platforms is tightly coupled to the exact step sequence; adding/removing steps requires updating the controller, store, and all step UI components
