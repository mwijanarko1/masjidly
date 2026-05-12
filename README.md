# Masjidly - Official Mosque Prayer Times

[![iOS](https://img.shields.io/badge/platform-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Android](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)](https://developer.android.com/)
[![Expo](https://img.shields.io/badge/built%20with-Expo-000020?logo=expo)](https://expo.dev/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.9+-FA7343?logo=swift)](https://developer.apple.com/xcode/swiftui/)

A beautifully designed, time-adaptive prayer times app that displays **official mosque timetables** with an immersive, atmospheric interface. The visual language shifts throughout the day - from deep pre-dawn blues to vivid sunset purples - reflecting the spiritual rhythm of each prayer.

---

## Features

- **Official Prayer Times** - Accurate adhan and iqamah times sourced directly from participating mosques
- **Time-Adaptive Atmosphere** - Full-bleed gradients that change based on the current prayer (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
- **Next Prayer Countdown** - Live countdown to the next adhan or iqamah with smart DST handling
- **Monthly Timetable** - Complete month view with prayer times, iqamah ranges, and Ramadan overrides
- **Local Notifications** - Customizable prayer reminders with adhan sound, snooze, and quick actions
- **Qibla Direction** - Compass-based Qibla indicator using device heading and location
- **Home Screen Widgets** - iOS widgets showing today's prayer times at a glance
- **Multi-Language Support** - English, Arabic, and Urdu with RTL layout support
- **Mosque Selection** - Choose from a curated list of local mosques with persistent selection

---

## Project Structure

This is a **dual-platform codebase** with a shared Convex backend:

```
├── Masjidly - Official Masjid Prayer Times/   # Native iOS app (SwiftUI)
│   ├── App/                                    # Entry point & DI
│   ├── Domain/                                 # Models, localization, defaults
│   ├── Features/
│   │   ├── Home/                               # Prayer times screen, engine, timetable
│   │   ├── Settings/                           # Mosque picker, preferences
│   │   ├── Notifications/                      # Local notification scheduling
│   │   ├── Onboarding/                         # First-launch flow
│   │   ├── Audio/                              # Adhan playback
│   │   └── Widgets/                            # iOS widget snapshot service
│   ├── Data/
│   │   ├── Convex/                             # Convex client & repository
│   │   └── Persistence/                        # UserDefaults settings store
│   └── Assets.xcassets/                        # App icons & prayer illustrations
│
├── apps/expo/                                  # Expo React Native app (Android)
│   ├── app/                                    # Expo Router screens
│   ├── components/                             # Reusable UI components
│   ├── lib/                                    # Domain, data, i18n, notifications
│   ├── store/                                  # Zustand settings store
│   └── __tests__/                              # Jest test suite
│
├── docs/
│   ├── DESIGN.md                               # Visual design tokens & guidelines
│   ├── CODEBASE_MAP.md                         # Architecture & navigation guide
│   └── GLOSSARY.md                             # Shared domain vocabulary
│
└── MasjidlyWidgets/                            # iOS Home Screen widgets
```

---

## Getting Started

### Prerequisites

- **iOS**: Xcode 16+, iOS 17+ target
- **Android**: Node.js 20+, Bun or npm, Expo CLI
- **Backend**: Convex account (external deployment)

### Native iOS

```bash
# Open the project in Xcode
open "Masjidly - Official Masjid Prayer Times.xcodeproj"

# Build and run on a simulator or device
# Cmd+R in Xcode
```

### Expo Android

```bash
cd apps/expo

# Install dependencies
bun install

# Start the development server
bun start

# Run on Android emulator or device
bun android
```

---

## Design

Masjidly uses a **minimalist, time-adaptive visual identity** built around:

- **Atmospheric Gradients** - 3-layer linear sky + radial horizon glow per prayer time
- **Custom Line-Art Icons** - Canvas-drawn sun phases (semicircles, stars, rays)
- **Comfortaa Typography** - Fully rounded geometric font matching the 3D logo aesthetic
- **Hero Time Display** - 88pt light-weight adhan time as the focal point

See [`docs/DESIGN.md`](docs/DESIGN.md) for the full design specification.

---

## Architecture

### Native iOS (SwiftUI)

| Layer | Pattern | Key Files |
|-------|---------|-----------|
| Entry | `@main` SwiftUI App | `Masjidly___Official_Masjid_Prayer_TimesApp.swift` |
| DI | `@Observable` AppEnvironment | `App/AppEnvironment.swift` |
| Domain | Value types + protocols | `Domain/PrayerModels.swift`, `PrayerRepository.swift` |
| Data | Convex subscription -> Repository | `Data/Convex/*.swift` |
| Feature | `@Observable` view models | `Features/*/HomeViewModel.swift`, `SettingsViewModel.swift` |
| UI | SwiftUI + design tokens | `Features/Home/*.swift`, `HomeDesign.swift` |

### Expo Android (React Native)

| Layer | Pattern | Key Files |
|-------|---------|-----------|
| Entry | Expo Router | `app/_layout.tsx` |
| Domain | Pure functions + Zod | `lib/prayer/prayerTimesEngine.ts`, `types/prayer.ts` |
| Data | Convex client -> Repository | `lib/convex/client.tsx`, `lib/prayer/prayerRepository.ts` |
| State | Zustand + persist | `store/settings.ts` |
| UI | React Native + tokens | `app/index.tsx`, `app/timetable.tsx`, `app/settings.tsx` |

---

## Testing

### iOS
```bash
# Run unit tests in Xcode
# Cmd+U
```

### Expo
```bash
cd apps/expo
bun test
```

The Expo test suite includes 131+ Jest tests covering the prayer engine, data decoding, settings persistence, localization, notifications, and screen components.

---

## Documentation

- **[Design System](docs/DESIGN.md)** - Colors, gradients, typography, and layout tokens
- **[Codebase Map](docs/CODEBASE_MAP.md)** - Architecture overview, key workflows, and navigation guide
- **[Glossary](docs/GLOSSARY.md)** - Shared domain vocabulary (mosque, iqamah, jummah, DST calendar, etc.)

---

## Acknowledgments

- Prayer time data powered by participating mosques via **Convex**
- Adhan audio and Islamic calendar calculations
- Built for the Muslim community with care and attention to detail

---

## License

Proprietary - All rights reserved.
