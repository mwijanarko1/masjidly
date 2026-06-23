# Masjidly - Official Mosque Prayer Times

[![iOS](https://img.shields.io/badge/platform-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Android](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)](https://developer.android.com/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.9+-FA7343?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Kotlin](https://img.shields.io/badge/Kotlin-Compose-7F52FF?logo=kotlin)](https://developer.android.com/jetpack/compose)

A beautifully designed, time-adaptive prayer times app that displays **official mosque timetables** with an immersive, atmospheric interface. The visual language shifts throughout the day - from deep pre-dawn blues to vivid sunset purples - reflecting the spiritual rhythm of each prayer.

---

## Features

- **Official Prayer Times** - Accurate adhan and iqamah times sourced directly from participating mosques
- **Time-Adaptive Atmosphere** - Full-bleed gradients that change based on the current prayer (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha)
- **Next Prayer Countdown** - Live countdown to the next adhan or iqamah with smart DST handling
- **Monthly Timetable** - Complete month view with prayer times, iqamah ranges, and Ramadan overrides
- **Local Notifications** - Customizable prayer reminders with adhan sound, snooze, and quick actions
- **Qibla Direction** - Compass-based Qibla indicator using device heading and location
- **Home Screen Widgets** - iOS and Android widgets showing today's prayer times at a glance
- **Multi-Language Support** - English, Arabic, and Urdu with RTL layout support
- **Mosque Selection** - Choose from a curated list of local mosques with persistent selection

---

## Project Structure

This is a **multi-platform codebase** with a shared Convex backend:

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
├── apps/android/                               # Native Android app (Kotlin + Jetpack Compose)
│   ├── app/src/main/kotlin/.../                # Features, domain, data, widgets
│   ├── PARITY.md                               # iOS ↔ Android parity tracker
│   └── README.md                               # Gradle build instructions
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
- **Android**: Android Studio, JDK 17+, Android SDK 35
- **Backend**: Convex account (external deployment)

### Native iOS

```bash
# Open the project in Xcode
open "Masjidly - Official Masjid Prayer Times.xcodeproj"

# Build and run on a simulator or device
# Cmd+R in Xcode
```

### Native Android (Kotlin)

```bash
cd apps/android

# Point Gradle at your SDK (or set ANDROID_HOME)
cp local.properties.example local.properties
# edit local.properties → sdk.dir=...

./gradlew :app:assembleDebug
```

Debug APK: `app/build/outputs/apk/debug/app-debug.apk` (package `com.mikhailspeaks.masjidly`).

Release build and publishing: see [`docs/build-android-release.md`](docs/build-android-release.md) and [`AGENTS.md`](AGENTS.md).

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

### Native Android (Kotlin + Compose)

| Layer | Pattern | Key Files |
|-------|---------|-----------|
| Entry | `Application` + `MainActivity` | `MasjidlyApp.kt`, `MainActivity.kt` |
| Domain | Data classes + engine | `domain/PrayerModels.kt`, `PrayerTimesEngine.kt` |
| Data | HTTP Convex client + disk cache | `data/convex/ConvexPrayerRepository.kt`, `data/cache/` |
| Feature | ViewModel + Compose screens | `features/home/HomeViewModel.kt`, `HomeScreen.kt` |
| UI | Material 3 + design tokens | `ui/theme/`, `ui/home/HomeDesign.kt` |

---

## Testing

### iOS
```bash
# Run unit tests in Xcode
# Cmd+U
```

### Android
```bash
cd apps/android
./gradlew test
```

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
