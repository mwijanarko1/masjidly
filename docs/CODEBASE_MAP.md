---
last_mapped: 2026-05-10T00:00:00Z
---

# Codebase Map — Masjidly (Native SwiftUI + Expo Android companion)

## System Overview

Masjidly is a **native iOS app** (SwiftUI, `@Observable`) that displays official mosque prayer times with a light weather-inspired UI. It fetches prayer/iqamah data from a **Convex** backend, computes next-prayer state locally via `PrayerTimesEngine`, schedules local notifications, and persists user preferences in `SettingsStore`.

An **Expo RN companion app** lives under `apps/expo/` (separate codebase, shared Convex backend). The Expo app targets **Android only** and replicates the same domain behavior, data sources, settings, localization, timetable, and local prayer notification flows as the native iOS app.

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
│   ├── PrayerLocalization.swift                 # Canonical prayer name → localization key mapping
│   ├── MosqueDefaults.swift                     # Default mosque selection logic
│   ├── MonthName.swift                          # Hijri/Gregorian month name helpers
│   └── AppLanguage.swift                        # Language enum + resolved locale helpers
├── Features/
│   ├── Home/                                    # Main prayer times screen
│   │   ├── HomeView.swift                       # Root UI — header, hero illustration, quick-info, carousel, timetable
│   │   ├── HomeViewModel.swift                  # @Observable — next prayer, selected date, mosque switching
│   │   ├── HomeUIComponents.swift               # Reusable SwiftUI views (QuickInfoItem, PrayerCarouselCell, etc.)
│   │   ├── HomeDesign.swift                     # Design tokens — gradients, shadows, color helpers
│   │   ├── TimetableView.swift                  # Monthly timetable sheet
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

apps/expo/                                       # Expo RN Android companion app (separate codebase)
├── app/                                         # Expo Router screens
│   ├── _layout.tsx                              # Root layout — ErrorBoundary, SafeAreaProvider, MasjidlyConvexProvider
│   ├── index.tsx                                # Home screen — hero illustration, adhan time, prayer carousel
│   ├── timetable.tsx                            # Timetable modal — month switcher, date strip, prayer rows
│   └── settings.tsx                             # Settings modal — mosque picker, language, 24h toggle, notifications
├── components/                                  # UI components
│   ├── ui/                                      # PrayerCarousel, PrayerRow, SettingsToggleRow
│   └── ErrorBoundary.tsx
├── lib/                                         # Domain, data, i18n, notifications
│   ├── convex/client.tsx                        # ConvexReactClient + MasjidlyConvexProvider
│   ├── prayer/                                  # Domain layer ported from Swift
│   │   ├── prayerTimesEngine.ts                 # Full engine port — DST, iqamah, next prayer, 12h format
│   │   ├── mosqueDefaults.ts                    # Default mosque selection + visible filtering
│   │   ├── monthName.ts                         # Month name enum + from-number helper
│   │   └── prayerRepository.ts                  # Typed Convex repository with Zod parsing
│   ├── i18n/                                    # Static localization
│   │   ├── translations.ts                      # English / Arabic / Urdu dictionary
│   │   └── language.ts                          # Language resolution, RTL detection, hook
│   ├── notifications/                           # Local prayer notifications
│   │   ├── prayerNotifications.ts               # Android channel, schedule/cancel, 7-day scheduling
│   │   └── usePrayerNotifications.ts            # Hook watching settings → reschedule
│   └── hooks/                                   # Custom hooks
│       └── useHomePrayerData.ts                 # Home data fetch + engine resolution
├── store/                                       # Zustand stores
│   └── settings.ts                              # Persisted settings (AsyncStorage)
├── types/                                       # Zod schemas + TS types
│   └── prayer.ts                                # Mosque, PrayerTime, MonthPrayerData, RamadanPrayerData, etc.
├── constants/                                   # Design tokens
│   └── index.ts                                 # Colors, spacing, font sizes
├── assets/                                      # Images, icons
│   └── prayers/                                 # Prayer illustration PNGs (fajr, dhuhr, asr, maghrib, isha)
├── __tests__/                                   # Jest tests
│   ├── prayer/                                  # Engine, decoding, defaults, monthName tests
│   ├── convex/                                  # Repository boundary tests
│   ├── store/                                   # Settings persistence tests
│   ├── i18n/                                    # Language resolution tests
│   ├── notifications/                           # Notification scheduling tests
│   ├── hooks/                                   # useHomePrayerData tests
│   └── screens/                                 # Home, Timetable, Settings component tests
└── docs/                                        # Expo-specific docs

 docs/                                            # Project documentation
 ├── DESIGN.md                                    # Visual design tokens (colors, typography, layout)
 ├── CODEBASE_MAP.md                              # This file
 ├── GLOSSARY.md                                  # Shared domain vocabulary
 ├── swift-mvp-plan-sheffield-masjids-app.md      # Original MVP planning doc
 └── prayer_times_home_page.json                  # Sample API response

 Masjidly - Official Masjid Prayer TimesTests/    # Unit tests
 └── MasjidlyTests.swift                          # PrayerTimesEngine + time calculation tests

 Masjidly - Official Masjid Prayer TimesUITests/  # UI tests
 └── MasjidlyUITests.swift                        # Basic launch test
```

---

## Key Workflows

### App Boot (Native iOS)
1. `AppEnvironment` instantiates `SettingsStore` → `ConvexService` → `ConvexPrayerRepository` → `PrayerNotificationScheduler`
2. `HomeViewModel` and `SettingsViewModel` receive their dependencies
3. `HomeView` renders with `env.homeViewModel`; `SettingsView` is presented as a sheet

### App Boot (Expo Android)
1. Root `_layout.tsx` mounts `MasjidlyConvexProvider` around the router stack
2. `HomeScreen` mounts `useHomePrayerData`, which:
   - Loads mosque list via `prayerRepository.listMosques()`
   - Resolves selected mosque via `resolveSelectedMosque`
   - Fetches current month, Ramadan, and UK DST dates in parallel
   - Resolves displayed prayer times, iqamah times, and next countdown via `PrayerTimesEngine`
3. `usePrayerNotifications` watches settings and reschedules local notifications when enabled

### Prayer Time Display
1. `HomeViewModel` (iOS) / `useHomePrayerData` (Expo) loads mosque data via repository
2. `PrayerTimesEngine` computes the next prayer from today's `DailyPrayerTimes` + `DailyIqamahTimes`
3. UI renders hero illustration, large next-prayer time, quick-info metrics, and horizontal prayer carousel
4. User taps a prayer in the carousel to select; engine recalculates

### Data Fetching
- `ConvexPrayerRepository` (iOS) subscribes to Convex queries for mosque list, monthly prayer times, iqamah times, and Ramadan data
- `prayerRepository` (Expo) calls the same Convex functions via `anyApi` with Zod parsing at the boundary
- `ConvexClient+SubscribeFirst.swift` provides a `subscribeFirst` helper for one-shot subscription results

### Notifications
- `PrayerNotificationScheduler` (iOS) schedules `UNNotificationRequest` entries for upcoming prayer times
- `prayerNotifications.ts` (Expo) schedules local Android notifications via `expo-notifications` with a `prayer-times` channel
- Both schedule 7 days of adhan + iqamah notifications, cancel previous ones on settings change, and use localized body strings

### Settings
- `SettingsStore` (iOS) persists selected mosque, notification preferences, and UI state in `UserDefaults`
- `useSettingsStore` (Expo) persists the same fields in `AsyncStorage` via Zustand `persist` middleware
- `SettingsViewModel` / `SettingsScreen` loads mosque list and exposes it for picker UI

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

| Layer (Expo) | Pattern | Files |
|-------|---------|-------|
| Entry | Expo Router stack | `app/_layout.tsx` |
| Domain | Pure functions + Zod schemas | `lib/prayer/prayerTimesEngine.ts`, `types/prayer.ts` |
| Data | Convex client → Repository | `lib/convex/client.tsx`, `lib/prayer/prayerRepository.ts` |
| State | Zustand + persist | `store/settings.ts` |
| UI | React Native + design tokens | `app/index.tsx`, `app/timetable.tsx`, `app/settings.tsx` |
| Persistence | AsyncStorage via Zustand | `store/settings.ts` |

---

## Known Risks

- **No `.gitignore` for Xcode user data** — `xcuserdata` is tracked; consider adding to `.gitignore`
- **Expo app under `apps/expo/`** is a separate codebase with its own routing, state, and test suite — changes here do not affect the native app
- **PrayerTimesEngine** (~8k tokens in Swift, ~800 lines in TS) is the largest single module; handles DST, time parsing, and next-prayer logic
- **Tests** — `MasjidlyTests.swift` covers engine calculations; Expo has 131 Jest tests covering domain, data, UI, and notifications
- **Convex backend** is external; no local Convex functions or schema definitions in this repo
- **Android notification testing** requires a development build; Expo Go does not fully support notification channels
