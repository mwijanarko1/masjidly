---
last_mapped: 2026-05-09T00:00:00Z
---

# Codebase Map — Masjidly (Native SwiftUI + Expo companion)

## System Overview

Masjidly is a **native iOS app** (SwiftUI, `@Observable`) that displays official mosque prayer times with a light weather-inspired UI. It fetches prayer/iqamah data from a **Convex** backend, computes next-prayer state locally via `PrayerTimesEngine`, schedules local notifications, and persists user preferences in `SettingsStore`.

An **Expo RN companion app** lives under `apps/expo/` (separate codebase, shared Convex backend).

---

## Directory Guide

```
Masjidly - Official Masjid Prayer Times/          # Native iOS target
├── Masjidly___Official_Masjid_Prayer_TimesApp.swift   # @main entry — wires AppEnvironment → HomeView
├── App/
│   ├── AppEnvironment.swift                     # @Observable root DI container
│   └── ConvexConfiguration.swift                # Convex deployment URL constants
├── Domain/                                      # Business models & rules
│   ├── PrayerModels.swift                       # Mosque, PrayerTime, IqamahTimeRange, RamadanPrayerData, DailyPrayerTimes, UkDstCalendar
│   ├── PrayerRepository.swift                   # Protocol for prayer data access
│   ├── MosqueDefaults.swift                     # Default mosque selection logic
│   └── MonthName.swift                          # Hijri/Gregorian month name helpers
├── Features/
│   ├── Home/                                    # Main prayer times screen
│   │   ├── HomeView.swift                       # Root UI — header, hero illustration, quick-info, carousel, timetable
│   │   ├── HomeViewModel.swift                  # @Observable — next prayer, selected date, mosque switching
│   │   ├── HomeUIComponents.swift               # Reusable SwiftUI views (QuickInfoItem, PrayerCarouselCell, etc.)
│   │   ├── HomeDesign.swift                     # Design tokens — gradients, shadows, color helpers
│   │   ├── TimetableView.swift                  # 7-day timetable sheet
│   │   └── PrayerTimesEngine.swift              # Core calculation engine — next prayer, DST adjustment, time parsing
│   ├── Settings/
│   │   ├── SettingsView.swift                   # Settings UI — mosque picker, notification toggles, about
│   │   └── SettingsViewModel.swift              # @Observable — settings state, mosque list loading
│   └── Notifications/
│       ├── PrayerNotificationScheduler.swift    # UNUserNotificationCenter scheduling for prayer reminders
│       └── NotificationSettings.swift           # Notification permission / settings helpers
├── Data/
│   ├── Convex/
│   │   ├── ConvexService.swift                  # Convex client wrapper
│   │   ├── ConvexPrayerRepository.swift         # Convex-backed PrayerRepository implementation
│   │   └── ConvexClient+SubscribeFirst.swift    # Convex subscription helper extension
│   └── Persistence/
│       └── SettingsStore.swift                  # @Observable UserDefaults-backed user preferences
└── Assets.xcassets/                             # App icon, accent color, prayer illustrations (Fajr–Isha)

apps/expo/                                       # Expo RN companion app (separate codebase)
├── app/                                         # Expo Router screens
├── components/                                  # UI components
├── store/                                       # Zustand stores
├── lib/hooks/                                   # Custom hooks
├── types/                                       # Zod schemas + TS types
├── __tests__/                                   # Jest tests
└── docs/                                        # Expo-specific architecture docs

docs/                                            # Project documentation
├── DESIGN.md                                    # Visual design tokens (colors, typography, layout)
├── CODEBASE_MAP.md                              # This file
├── swift-mvp-plan-sheffield-masjids-app.md      # Original MVP planning doc
└── prayer_times_home_page.json                  # Sample API response

Masjidly - Official Masjid Prayer TimesTests/    # Unit tests
└── MasjidlyTests.swift                          # PrayerTimesEngine + time calculation tests

Masjidly - Official Masjid Prayer TimesUITests/  # UI tests
└── MasjidlyUITests.swift                        # Basic launch test
```

---

## Key Workflows

### App Boot
1. `AppEnvironment` instantiates `SettingsStore` → `ConvexService` → `ConvexPrayerRepository` → `PrayerNotificationScheduler`
2. `HomeViewModel` and `SettingsViewModel` receive their dependencies
3. `HomeView` renders with `env.homeViewModel`; `SettingsView` is presented as a sheet

### Prayer Time Display
1. `HomeViewModel` loads mosque data via `repository`
2. `PrayerTimesEngine` computes the next prayer from today's `DailyPrayerTimes` + `DailyIqamahTimes`
3. UI renders hero illustration, large next-prayer time, quick-info metrics, and horizontal prayer carousel
4. User taps a prayer in the carousel to select; engine recalculates

### Data Fetching
- `ConvexPrayerRepository` subscribes to Convex queries for mosque list, monthly prayer times, iqamah times, and Ramadan data
- `ConvexClient+SubscribeFirst.swift` provides a `subscribeFirst` helper for one-shot subscription results

### Notifications
- `PrayerNotificationScheduler` schedules `UNNotificationRequest` entries for upcoming prayer times
- Settings toggles enable/disable per-prayer notifications

### Settings
- `SettingsStore` persists selected mosque, notification preferences, and UI state in `UserDefaults`
- `SettingsViewModel` loads mosque list and exposes it for picker UI

---

## Architecture Patterns

| Layer | Pattern | Files |
|-------|---------|-------|
| Entry | `@main` SwiftUI App | `Masjidly___...App.swift` |
| DI | `@Observable` AppEnvironment | `App/AppEnvironment.swift` |
| Domain | Value types + protocol | `Domain/PrayerModels.swift`, `PrayerRepository.swift` |
| Data | Convex subscription → Repository | `Data/Convex/*.swift` |
| Feature VM | `@Observable` view models | `Features/*/HomeViewModel.swift`, `SettingsViewModel.swift` |
| UI | SwiftUI views + design tokens | `Features/Home/*.swift`, `HomeDesign.swift` |
| Persistence | `UserDefaults` via `@Observable` | `Data/Persistence/SettingsStore.swift` |

---

## Known Risks

- **No `.gitignore` for Xcode user data** — `xcuserdata` is tracked; consider adding to `.gitignore`
- **Expo app under `apps/expo/`** is a separate codebase with its own routing, state, and test suite — changes here do not affect the native app
- **PrayerTimesEngine** (~8k tokens) is the largest single file; handles DST, time parsing, and next-prayer logic in one module
- **Tests are minimal** — `MasjidlyTests.swift` covers engine calculations; UITests only verify launch
- **Convex backend** is external; no local Convex functions or schema definitions in this repo
