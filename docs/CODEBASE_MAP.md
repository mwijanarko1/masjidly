---
last_mapped: 2026-05-13T00:00:00Z
---

# Codebase Map — Masjidly (Native SwiftUI + Expo Android companion)

## System Overview

Masjidly is a **native iOS app** (SwiftUI, `@Observable`) that displays official mosque prayer times with a light weather-inspired UI. It fetches prayer/iqamah data from a **Convex** backend, computes next-prayer state locally via `PrayerTimesEngine`, schedules local notifications, persists user preferences in `SettingsStore`, includes a **Qibla compass**, and offers a **multi-step onboarding tutorial**.

An **Expo RN companion app** lives under `apps/expo/` (separate codebase, shared Convex backend). The Expo app targets **Android only** and replicates the same domain behavior, data sources, settings, localization, timetable, Qibla, audio adhan playback, and local prayer notification flows as the native iOS app.

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
│   │   ├── HomeView.swift                             # Root UI — header, hero illustration, quick-info, carousel, timetable
│   │   ├── HomeViewModel.swift                        # @Observable — next prayer, selected date, mosque switching, error states
│   │   ├── HomeUIComponents.swift                     # Reusable SwiftUI views (QuickInfoItem, PrayerCarouselCell, etc.)
│   │   ├── HomeDesign.swift                           # Design tokens — TimeTheme, gradients, shadows, color helpers
│   │   ├── PrayerTimesEngine.swift                    # Core calculation engine — next prayer, DST adjustment, time parsing
│   │   ├── TimetableView.swift                        # Monthly timetable sheet
│   │   ├── QiblaDirection.swift                       # Qibla bearing calculator, indicator rotation, continuous rotation smoothing
│   │   └── QiblaPrayerIcon.swift                      # Canvas-drawn Qibla compass icon
│   ├── Settings/
│   │   ├── SettingsView.swift                         # Settings UI — mosque picker, notification toggles, language, Qibla, about
│   │   ├── SettingsViewModel.swift                    # @Observable — settings state, mosque list loading
│   │   ├── AdhanSoundPreviewPlayer.swift              # AVAudioPlayer wrapper for adhan preview in settings
│   │   ├── AppReviewPromptCoordinator.swift           # App Store review request logic (SKStoreReviewController)
│   │   └── MasjidlySupportMail.swift                  # MFMailComposeViewController wrapper for support
│   ├── Notifications/
│   │   ├── PrayerNotificationScheduler.swift          # UNUserNotificationCenter scheduling for prayer reminders
│   │   ├── PrayerNotificationContent.swift            # Standardized content, category/action IDs, sound wiring, userInfo keys
│   │   └── NotificationSettings.swift                 # Notification permission / settings helpers
│   ├── Onboarding/                                    # First-launch tutorial flow
│   │   ├── OnboardingStep.swift                       # Step enum (chooseMosque, prayerShortcut, qibla, timetable, settings, notifications)
│   │   ├── OnboardingFlowController.swift             # @Observable — drives step progression, mosque selection, notification setup
│   │   ├── OnboardingTutorialChrome.swift             # Shared card chrome (frosted glass, border, shadow)
│   │   ├── MosqueSelectionOnboardingView.swift        # Mosque picker step
│   │   ├── OnboardingNotificationSetupView.swift      # Notification permissions + toggles step
│   │   └── OnboardingCoachMarkView.swift              # Coach mark overlays for home, timetable, settings
│   ├── Audio/
│   │   └── AdhanMiniPlayerBar.swift                   # Bottom chrome for in-app adhan playback
│   └── Widgets/
│       ├── WidgetPrayerSnapshot.swift                 # Widget snapshot data model (DailyPrayerTimes, mosque slug)
│       └── WidgetPrayerSnapshotService.swift          # @MainActor service writing timeline entries for iOS widgets
├── Assets.xcassets/                                   # App icon, accent color, prayer illustrations (Fajr–Isha)
├── Fonts/                                             # Comfortaa font files + archive
├── Icons/                                             # Prayer PNG icons (fajr, dhuhr, asr, maghrib, isha)
├── Resources/                                         # Adhan audio files (Adhan-1.caf, Adhan-2.caf)
└── Localizable.xcstrings                              # String catalog for i18n

apps/expo/                                             # Expo RN Android companion app (separate codebase)
├── app/                                               # Expo Router screens
│   ├── _layout.tsx                                    # Root layout — ErrorBoundary, SafeAreaProvider, MasjidlyConvexProvider
│   ├── index.tsx                                      # Home screen — hero illustration, adhan time, prayer carousel, Qibla
│   ├── timetable.tsx                                  # Timetable modal — month switcher, date strip, prayer rows
│   └── settings.tsx                                   # Settings modal — mosque picker, language, 24h toggle, notifications
├── components/
│   ├── ui/
│   │   ├── AtmosphericSkyBackground.tsx                # Full-bleed sky gradient background (LinearGradient + radial overlay)
│   │   ├── Button.tsx                                 # Reusable touchable button
│   │   ├── PrayerLetterPicker.tsx                      # Prayer toggles for notification settings (letter-style chips)
│   │   ├── PrayerRow.tsx                              # Single prayer time row (name, adhan, iqamah)
│   │   ├── PrayerSunPhaseIcon.tsx                      # Canvas-drawn sun phase icons (semicircle, rays, stars)
│   │   ├── QiblaPrayerIcon.tsx                         # Qibla compass icon using Canvas
│   │   ├── SettingsMenuPickerRow.tsx                   # Menu-based picker row for settings
│   │   └── SettingsToggleRow.tsx                       # Toggle row for settings
│   ├── onboarding/
│   │   ├── CoachMarkCard.tsx                           # Coach mark card overlay
│   │   ├── MosqueSelectionCard.tsx                     # Mosque picker onboarding card
│   │   ├── NotificationSetupCard.tsx                   # Notification setup onboarding card
│   │   └── TutorialOverlay.tsx                         # Full-screen tutorial overlay orchestrator
│   └── ErrorBoundary.tsx                              # React error boundary
├── lib/
│   ├── convex/
│   │   └── client.tsx                                 # ConvexReactClient + MasjidlyConvexProvider
│   ├── prayer/
│   │   ├── prayerTimesEngine.ts                       # Full engine port — DST, iqamah, next prayer, 12h format
│   │   ├── mosqueDefaults.ts                          # Default mosque selection + visible filtering
│   │   ├── monthName.ts                               # Month name enum + from-number helper
│   │   └── prayerRepository.ts                        # Typed Convex repository with Zod parsing
│   ├── i18n/
│   │   ├── translations.ts                            # English / Arabic / Urdu dictionary
│   │   └── language.ts                                # Language resolution, RTL detection, hook
│   ├── notifications/
│   │   ├── expoNotificationApi.ts                     # expo-notifications wrapper abstraction layer
│   │   └── prayerNotifications.ts                     # Android channel setup, schedule/cancel, 7-day scheduling
│   ├── audio/
│   │   └── AdhanSoundPlayer.ts                        # Expo Audio adhan playback + mini-player
│   ├── design/
│   │   ├── themes.ts                                  # SkyTheme per prayer time (gradient colors, glow)
│   │   └── gradientColors.ts                          # Hex-to-RGB helpers, gradient densification (anti-banding)
│   └── hooks/
│       ├── useHomePrayerData.ts                       # Data fetch + engine resolution for home screen
│       ├── usePrayerNotifications.ts                  # Watches settings → reschedule/cancel notifications
│       └── useQiblaDirection.ts                       # Qibla direction with device heading subscription
├── store/
│   ├── settings.ts                                    # Persisted settings (AsyncStorage via Zustand persist)
│   └── onboarding.ts                                  # Zustand onboarding flow store (step state, mosque select, notification setup)
├── types/
│   └── prayer.ts                                      # Zod schemas + TS types (Mosque, PrayerTime, MonthPrayerData, etc.)
├── constants/
│   └── index.ts                                       # Design tokens — colors, spacing, font sizes
├── assets/
│   └── prayers/                                       # Prayer illustration PNGs (fajr, dhuhr, asr, maghrib, isha)
├── __tests__/                                         # 131+ Jest tests
│   ├── prayer/                                        # Engine, decoding, defaults, monthName
│   ├── convex/                                        # Repository boundary tests
│   ├── store/                                         # Settings persistence tests
│   ├── i18n/                                          # Language resolution tests
│   ├── notifications/                                 # Notification scheduling tests
│   ├── hooks/                                         # useHomePrayerData tests
│   └── screens/                                       # Home, Timetable, Settings component tests
└── docs/                                              # Expo-specific documentation

docs/                                                  # Project documentation
├── DESIGN.md                                          # Visual design tokens (colors, typography, layout)
├── CODEBASE_MAP.md                                    # This file
├── GLOSSARY.md                                        # Shared domain vocabulary
├── swift-mvp-plan-sheffield-masjids-app.md            # Original MVP planning doc
├── minimal-prayer-times-home-redesign.md              # Home screen redesign spec
├── android-expo-feature-parity-with-native-ios-masjidly.md  # Feature parity tracking doc
├── patch.swift                                        # Data patching script
├── patch_timetable.py                                 # Timetable patching utility
└── prayer_times_home_page.json                        # Sample API response

Masjidly - Official Masjid Prayer TimesTests/          # Unit tests
├── MasjidlyTests.swift                                # PrayerTimesEngine + time calculation tests
├── PrayerNotificationSchedulerTests.swift             # Notification scheduling tests
└── WidgetPrayerSnapshotTests.swift                    # Widget snapshot tests

Masjidly - Official Masjid Prayer TimesUITests/        # UI tests
└── MasjidlyUITests.swift                              # Basic launch test

MasjidlyWidgets/                                       # iOS Home Screen widgets
├── MasjidlyWidgets.swift                              # Widget timeline provider + entry view
└── MasjidlyWidgetData.swift                           # Widget data model & shared accessors

MasjidlyWidgetSupport/                                 # Shared support for widgets
└── MasjidlyWidgets-Info.plist                         # Widget extension Info.plist
```

---

## Key Workflows

### App Boot (Native iOS)
1. `@main` app creates `AppEnvironment`, which instantiates `SettingsStore` → `ConvexService` → `ConvexPrayerRepository` + `PrayerTimesDiskCache` → `PrayerNotificationScheduler`
2. App registers notification category/action definitions from `PrayerNotificationContent`
3. `MasjidlyRootView` wraps `HomeView` with forced `en` locale + `LTR` layout
4. `OnboardingFlowController` checks `settings.hasCompletedOnboarding`; if `false` and mosques are loaded, presents the tutorial sequence
5. `AdhanMiniPlayerBar` is shown in the bottom safe area inset when audio playback is active

### App Boot (Expo Android)
1. Root `_layout.tsx` mounts `MasjidlyConvexProvider` around the router stack
2. `HomeScreen` mounts `useHomePrayerData`, which:
   - Loads mosque list via `prayerRepository.listMosques()`
   - Resolves selected mosque via `resolveSelectedMosque`
   - Fetches current month, Ramadan, and UK DST dates in parallel
   - Resolves displayed prayer times, iqamah times, and next countdown via `PrayerTimesEngine`
3. `usePrayerNotifications` watches settings and reschedules local notifications when toggled
4. `useOnboardingStore.startIfNeeded()` triggers tutorial overlay if `hasCompletedOnboarding` is false

### Prayer Time Display
1. `HomeViewModel` (iOS) / `useHomePrayerData` (Expo) loads mosque data via repository
2. `PrayerTimesEngine` computes the next prayer from today's `DailyPrayerTimes` + `DailyIqamahTimes`
3. UI renders hero illustration, large next-prayer time, quick-info metrics, and horizontal prayer carousel
4. User taps a prayer in the carousel to select; engine recalculates

### Data Fetching & Caching
- **Convex queries** for mosque list, monthly prayer times, iqamah times, and Ramadan data
- **iOS** uses `ConvexPrayerRepository` (subscription-based) + `PrayerTimesDiskCache` (atomic JSON file cache in Application Support) for offline resilience
- **Expo** uses `prayerRepository` with Zod parsing at the boundary
- `ConvexClient+SubscribeFirst.swift` provides a `subscribeFirst` helper for one-shot subscription results

### Notifications
- **iOS**: `PrayerNotificationContent` defines standardized category/action IDs, sound wiring, and userInfo keys. `PrayerNotificationScheduler` schedules `UNNotificationRequest` entries for 7 days of adhan + iqamah + pre-reminders. Supports snooze and quick actions (view times, open timetable).
- **Expo**: `expoNotificationApi.ts` wraps `expo-notifications`; `prayerNotifications.ts` handles Android channel setup, schedule/cancel, and 7-day scheduling. `usePrayerNotifications` hook auto-reschedules when settings change.

### Onboarding Tutorial Flow (both platforms)
1. **Choose Mosque** — select from loaded mosque list
2. **Prayer Shortcut** — sequential tap-through of each prayer in the carousel
3. **Qibla** — intro to Qibla compass (iOS: allow or defer location)
4. **Open Timetable** → explore → close
5. **Open Settings** → explore → close
6. **Notifications** — configure adhan/iqamah toggles, pre-reminder minutes, authorize permissions
7. Marks `hasCompletedOnboarding = true`, exits tutorial

### Qibla Direction
- **iOS**: `QiblaDirectionCalculator` computes bearing from device location to Kaaba, including `indicatorRotationDegrees` (shortest arc) and `continuousRotationDegrees` (smooth animation across 0° wrap). `QiblaPrayerIcon` renders compass via Canvas.
- **Expo**: `useQiblaDirection` hook subscribes to device heading + location, computes bearing via identical formula. `QiblaPrayerIcon` renders heading needle + Qibla tick.

### Settings
- **iOS**: `SettingsView` includes mosque picker, notification toggles (per-prayer), language selector, 24h toggle, Qibla toggle, adhan sound preview, support mail, app review prompt, about section
- **Expo**: `settings.tsx` replicates all settings; `SettingsMenuPickerRow` for pickable fields, `SettingsToggleRow` for boolean toggles
- **iOS persistence**: `SettingsStore` via `UserDefaults` + `@Observable`
- **Expo persistence**: `useSettingsStore` via Zustand `persist` middleware (AsyncStorage)

### Widgets (iOS only)
- `MasjidlyWidgets` target provides home screen widgets
- `WidgetPrayerSnapshotService` fetches prayer data and writes timeline entries via `WidgetCenter`
- `WidgetPrayerSnapshot` is the decoded data model passed to the widget's timeline provider
- `WidgetPrayerSnapshotTests` cover the snapshot service

### Audio
- **iOS**: `AdhanSoundPreviewPlayer` (singleton) provides lightweight adhan preview in settings. `AdhanMiniPlayerBar` shows playback progress when audio is active.
- **Expo**: `AdhanSoundPlayer.ts` uses `expo-av` for adhan playback with duration tracking and mini-player state.

### Debug Tooling (iOS)
- An empty `Debug/` directory exists — placeholder for future debug/dev tools
- `OnboardingFlowController.restartTutorialFromDeveloperTools()` enables re-running the tutorial from developer controls

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
| Persistence | `UserDefaults` via `@Observable` + disk cache | `Data/Persistence/SettingsStore.swift`, `PrayerTimesDiskCache.swift` |

| Layer (Expo) | Pattern | Files |
|-------|---------|-------|
| Entry | Expo Router stack | `app/_layout.tsx` |
| Domain | Pure functions + Zod schemas | `lib/prayer/prayerTimesEngine.ts`, `types/prayer.ts` |
| Data | Convex client → Repository | `lib/convex/client.tsx`, `lib/prayer/prayerRepository.ts` |
| State | Zustand + persist middleware | `store/settings.ts`, `store/onboarding.ts` |
| Design Tokens | Theme records + gradient helpers | `lib/design/themes.ts`, `lib/design/gradientColors.ts` |
| UI | React Native + component library | `app/*.tsx`, `components/ui/*.tsx`, `components/onboarding/*.tsx` |
| Persistence | AsyncStorage via Zustand | `store/settings.ts` |

---

## Known Risks

- **`xcuserdata` tracked in git** — Xcode user data is committed; consider adding to `.gitignore`
- **Expo app under `apps/expo/`** is a separate codebase with its own routing, state, and test suite — changes here do not affect the native app
- **PrayerTimesEngine** (~8k tokens in Swift, ~800 lines in TS) handles DST, time parsing, and next-prayer logic; the largest single module in both codebases
- **iOS tests**: 3 test files (`MasjidlyTests`, `PrayerNotificationSchedulerTests`, `WidgetPrayerSnapshotTests`) — engine + notifications + widgets
- **Expo tests**: 131+ Jest tests covering domain, data, UI, and notifications
- **Convex backend** is external; no local Convex functions or schema definitions in this repo
- **Android notification testing** requires a development build; Expo Go does not fully support notification channels
- **PrayerTimesDiskCache** uses atomic writes via temp file + `replaceItemAt`; cache invalidation / staleness logic is manual (no TTL)
- **Onboarding flow** in both platforms is tightly coupled to the exact step sequence; adding/removing steps requires updating the controller, store, and all step UI components
