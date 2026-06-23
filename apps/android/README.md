# Native Android (Kotlin + Jetpack Compose)

Native Android app. iOS SwiftUI is the source of truth for behavior and design.

## Build

Requires `ANDROID_HOME` pointing at your SDK (e.g. external SSD).

```bash
cd apps/android
./gradlew :app:assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

Release APK:

```bash
./gradlew :app:assembleRelease
```

See `docs/build-android-release.md` and root `AGENTS.md` for release publishing.

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
