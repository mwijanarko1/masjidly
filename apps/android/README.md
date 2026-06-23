# Native Android (Kotlin + Jetpack Compose)

Parallel native Android app. iOS SwiftUI is the source of truth; Expo (`apps/expo`) stays untouched until feature parity.

## Build

Requires `ANDROID_HOME` pointing at your SDK (e.g. external SSD).

```bash
cd apps/android
./gradlew :app:assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

Debug installs as `com.mikhailspeaks.masjidly.native` so it can sit alongside the Expo Android app.

## Structure (mirrors iOS)

| Android | iOS |
|---------|-----|
| `features/home/HomeScreen.kt` | `Features/Home/HomeView.swift` |
| `features/timetable/TimetableScreen.kt` | `Features/Home/TimetableView.swift` |
| `features/settings/SettingsScreen.kt` | `Features/Settings/SettingsView.swift` |
| `data/ConvexConfig.kt` | `App/ConvexConfiguration.swift` |
| `features/updates/UpdateChecker.kt` | `Features/Updates/AppUpdateChecker.swift` |

## Pending

See **`PARITY.md`** for the full iOS ↔ Android parity map and remaining gaps.
