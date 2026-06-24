# Native Android (Kotlin + Jetpack Compose)

Native Android app. iOS SwiftUI is the source of truth for behavior and design.

## Build

**Local SDK (no external SSD / no emulator):** `~/Library/Android/sdk` (~350 MB) — `platform-tools`, `platforms;android-35`, `build-tools;35.0.0`. `local.properties` points at this path.

If `GRADLE_USER_HOME` in your shell still targets the Seagate SSD, override for builds:

```bash
export GRADLE_USER_HOME="$HOME/.gradle"
export ANDROID_HOME="$HOME/Library/Android/sdk"
cd apps/android
./gradlew :app:installDebug
```

Fresh machine — install the same packages:

```bash
SDK_ROOT="$HOME/Library/Android/sdk"
mkdir -p "$SDK_ROOT/cmdline-tools"
ln -sfn /opt/homebrew/share/android-commandlinetools/cmdline-tools/latest "$SDK_ROOT/cmdline-tools/latest"
yes | "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_ROOT" --licenses
"$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_ROOT" \
  "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

Physical device only — no emulator or AVD images required. Plug in the phone, enable USB debugging, then `installDebug`.

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
