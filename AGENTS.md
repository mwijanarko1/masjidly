# Masjidly — Agent Standards

## Overview

Masjidly is a **multi-platform app** (iOS native SwiftUI + native Android Kotlin/Compose) with a shared Convex backend. This document defines procedures for local prod builds (APK/AAB), website sideload releases, store release notes, and the in-app update infrastructure.

---

## Repos

| Repo | URL | Purpose |
|------|-----|---------|
| `masjidly` | `github.com/mwijanarko1/masjidly` | App source code (iOS + Android) |
| `Sheffield-Masjids` | `github.com/mwijanarko1/Sheffield-Masjids` | Website hosting APK + `latest.json` |

---

## 1. Version Manifest (`latest.json`)

The apps check for updates by fetching:

```
https://sheffieldmasjids.com/masjidly/latest.json
```

Schema:

```json
{
  "android": {
    "version": "1.1.1",
    "versionCode": 7,
    "url": "https://sheffieldmasjids.com/masjidly/Masjidly-1.1.1.apk",
    "sha256": "753f16183852b5301b750abd0e88da809dfeb86968e94c315a50914aa3d87079",
    "minVersionCode": 1
  },
  "ios": {
    "version": "1.1.1",
    "build": 3,
    "appStoreUrl": "https://apps.apple.com/gb/app/masjidly-masjid-prayer-times/id6767841833"
  },
  "pub_date": "2026-05-26T13:47:05Z",
  "notes": {
    "en": "New update available",
    "ar": "تحديث جديد متاح",
    "ur": "نیا اپ ڈیٹ دستیاب ہے",
    "id": "Pembaruan baru tersedia"
  }
}
```

### Android update check
- Compares `versionCode` against the installed APK's versionCode
- If manifest `versionCode` > installed, prompts user to download

### iOS update check
- Compares `version` (semantic, e.g. `1.1.2`) against `CFBundleShortVersionString`
- Ignores build numbers
- If manifest version is newer, prompts user to open App Store

---

## 2. Android local build environment

Do **not** use Android Studio for routine builds. Use Gradle CLI.

Toolchain lives on the Seagate drive (not always on the Mac). Ensure the volume is mounted first.

```bash
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export GRADLE_USER_HOME="/Volumes/Mikhail Seagate 2TB SSD/AndroidDev/gradle"
export ANDROID_HOME="/Volumes/Mikhail Seagate 2TB SSD/AndroidDev/sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
```

- **JDK:** Homebrew `openjdk@17` if missing (`brew install openjdk@17`).
- **Signing:** `apps/android/keystore.properties` (release signing for APK + AAB).
- **Versions:** `apps/android/app/build.gradle.kts` → `versionName` + `versionCode`.

### Prod vs debug

| Goal | Command | Output |
|------|---------|--------|
| **Prod / test-on-device APK** | `./gradlew :app:assembleRelease` | `app/build/outputs/apk/release/app-release.apk` |
| **Play Store upload** | `./gradlew :app:bundleRelease` | `app/build/outputs/bundle/release/app-release.aab` |
| Debug (avoid unless asked) | `./gradlew :app:assembleDebug` | `app/build/outputs/apk/debug/app-debug.apk` |

Default when the user says “build Android” / “install for test”: **release APK**, not debug.

```bash
cd apps/android
./gradlew :app:assembleRelease --no-daemon
adb uninstall com.mikhailspeaks.masjidly   # if INSTALL_FAILED_UPDATE_INCOMPATIBLE
adb install app/build/outputs/apk/release/app-release.apk
```

Reveal artifacts in Finder when asked: `open -R <path-to-apk-or-aab>`.

### Cleanup

After a release (or when asked), delete **stray** APKs:

- Versioned copies left in `apps/android/Masjidly-*.apk` (keep only what is still needed for website publish)
- Debug APK: `app/build/outputs/apk/debug/app-debug.apk`
- Temp pulls under `.asc/artifacts/**/*.apk`

Keep the current release AAB (and optionally the matching `app-release.apk`) until uploaded/published. Do not leave old versioned APKs lying around in the app repo.

---

## 3. Releasing a New Android APK (sideload / website)

Website sideload updates use the **APK**, not the AAB. Play Store uses the **AAB**.

Every new build **must** increment `versionCode` in `apps/android/app/build.gradle.kts`.

```bash
# 0. Export JAVA_HOME / GRADLE_USER_HOME / ANDROID_HOME (see §2)

# 1. Bump versionCode
#    Edit apps/android/app/build.gradle.kts → increment versionCode by 1

# 2. Build the APK
cd apps/android && ./gradlew :app:assembleRelease

# 3. Copy with versioned name
cd apps/android
cp app/build/outputs/apk/release/app-release.apk Masjidly-<version>.apk

# 4. Compute SHA256
shasum -a 256 Masjidly-<version>.apk

# 5. Copy APK to website repo
cp Masjidly-<version>.apk <path-to-Sheffield-Masjids>/public/masjidly/

# 6. Remove old versioned APK from website repo
#    (e.g. git rm public/masjidly/Masjidly-1.0.1.apk)

# 7. Update latest.json in website repo
#    - Set android.versionCode
#    - Set android.sha256
#    - Set android.url to the versioned filename
#    - Update pub_date
#    - Update notes if needed (otherwise keep simple "New update available")

# 8. Update download links in website repo
#    - src/components/MasjidlyHomePopup.tsx (ANDROID_APK_PATH + download attribute)
#    - src/components/masjidly/MasjidlyLandingHero.tsx (href + download attribute)

# 9. Commit and push website repo
cd <path-to-Sheffield-Masjids>
git add public/masjidly/ src/components/
git commit -m "chore(release): publish Masjidly v<version> (versionCode <code>)"
git push origin main

# 10. Commit version bump in app repo
cd <path-to-masjidly>
git add apps/android/app/build.gradle.kts
git commit -m "chore: bump Android versionCode to <code>"
git push origin main

# 11. Remove the local Masjidly-<version>.apk copy from apps/android/ once published
```

### Play Store AAB

```bash
# Same env as §2; versionName / versionCode already bumped
cd apps/android && ./gradlew :app:bundleRelease --no-daemon
# Upload: app/build/outputs/bundle/release/app-release.aab
open -R app/build/outputs/bundle/release/app-release.aab
```

### Full example (website APK)

```bash
# From the masjidly repo:
# Bump versionCode from 7 to 8 in build.gradle.kts

cd apps/android && ./gradlew :app:assembleRelease

cp app/build/outputs/apk/release/app-release.apk Masjidly-1.1.1.apk
SHA=$(shasum -a 256 Masjidly-1.1.1.apk | awk '{print $1}')
echo $SHA

cp Masjidly-1.1.1.apk /path/to/Sheffield-Masjids/public/masjidly/
cd /path/to/Sheffield-Masjids
git rm public/masjidly/Masjidly-1.0.1.apk

# Update latest.json with new SHA, versionCode, pub_date
# Update MasjidlyHomePopup.tsx and MasjidlyLandingHero.tsx hrefs

git add public/masjidly/ src/components/
git commit -m "chore(release): publish Masjidly v1.1.1 (versionCode 8)"
git push origin main

cd /path/to/masjidly
git add apps/android/app/build.gradle.kts
git commit -m "chore: bump Android versionCode to 8"
git push origin main
```

---

## 4. Release notes (store + What’s New)

Source of truth for copy: in-app What’s New.

| Platform | File |
|----------|------|
| iOS | `Masjidly - Official Masjid Prayer Times/Features/Updates/WhatsNew.swift` |
| Android | `apps/android/.../features/updates/WhatsNew.kt` |

**Rules:**
- Derive store release notes from the **English** What’s New items (and matching locales).
- **No em dashes or en dashes.** Use colons or plain sentences.
- Ship notes in all **four** app languages: `en-GB`, `ar`, `ur`, `id`.
- Android What’s New may omit iOS-only features (e.g. Prayer Focus). Play Store notes follow **Android** What’s New; App Store notes follow **iOS** What’s New.
- Format for quick paste (Play Console / ASC):

```xml
<en-GB>
New logos: Four fresh looks for Masjidly: Dawn, Sky, Afternoon, and Rose.

App icon picker: Choose your favourite logo anytime in Settings.
</en-GB>

<ar>
…matching Arabic What’s New…
</ar>

<ur>
…matching Urdu What’s New…
</ur>

<id>
…matching Indonesian What’s New…
</id>
```

Style: `Title: description` per bullet, blank line between items. Keep `latest.json` `notes` short (“New update available” / locale equivalents) unless asked to expand.

---

## 5. iOS development builds (USB device)

**Default for iOS work:** build and install on the physical iPhone over USB. Do not use the Simulator unless the user asks for it, or the device is unavailable.

```bash
# Resolve the connected device (prefer USB "Top M2" / iPhone XS)
xcrun devicectl list devices

DEVICE_UDID=00008020-000E0D8A1ED8002E   # Top M2 (xcodebuild id)
DEVICE_CORE=345910DF-F6D5-5F02-B28A-DFD703DDA290  # Top M2 (devicectl id)

cd "<repo-root>"
xcodebuild \
  -project "Masjidly - Official Masjid Prayer Times.xcodeproj" \
  -scheme "Masjidly - Official Masjid Prayer Times" \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -derivedDataPath ".derivedData-usb" \
  CODE_SIGN_STYLE=Automatic \
  build

APP=".derivedData-usb/Build/Products/Debug-iphoneos/Masjidly - Official Masjid Prayer Times.app"
xcrun devicectl device install app --device "$DEVICE_CORE" "$APP"
xcrun devicectl device process launch --device "$DEVICE_CORE" "mikhailspeaks.Masjidly---Official-Masjid-Prayer-Times"
```

Notes:
- Keep using `.derivedData-usb` so device builds stay separate from simulator DerivedData.
- If the device is locked or untrusted, unlock it and accept the trust prompt, then retry.
- Re-check `devicectl list devices` / `xcodebuild -showdestinations` if IDs change after reconnecting.

---

## 6. Releasing a New iOS Version

1. Bump `MARKETING_VERSION` in Xcode project settings
2. Submit to App Store Connect (What’s New copy: see §4; match iOS `WhatsNew.swift`)
3. Update `latest.json` in website repo:
   - Set `ios.version` to new version
   - Update `pub_date`
4. Commit and push website repo

---

## 7. In-App Update Infrastructure

### iOS (`MasjidlyRootView.swift`)
- On launch, calls `AppUpdateChecker.checkForUpdate()`
- Fetches `latest.json` from website
- Compares version via `isVersion(_:newerThan:)` (dotted-numeric comparison)
- Shows system `.alert()` if update available
- "Open App Store" button calls `AppUpdateChecker.openAppStore()`

### Android (`UpdateChecker.kt`)
- `checkForUpdate()` fetches `latest.json`, compares `versionCode`
- Shows update prompt with download link when a newer APK is available
- Auto-checks on launch from `MasjidlyApp`

### Test buttons (development builds only)
- **iOS:** Settings → Development section → "Test Update Prompt"
- **Android:** Settings → Development section → "Test Update Prompt"

Both trigger a live check against `latest.json` (or show a test release if fetch fails).

---

## 8. Version Bumping Rules

- **Android versionCode**: increment by 1 for every build. Used for update comparison.
- **Android versionName** (`build.gradle.kts`): bump for meaningful feature releases.
- **iOS version** (MARKETING_VERSION): bump for App Store releases.
- **iOS build** (CURRENT_PROJECT_VERSION): increment per build, not used for update checks.

---

## 9. Important Paths

### App repo (`mwijanarko1/masjidly`)
```
apps/android/app/build.gradle.kts           # Android versionName + versionCode
apps/android/keystore.properties            # Release signing (APK + AAB)
apps/android/README.md                      # Native Android build instructions
apps/android/PARITY.md                      # iOS ↔ Kotlin parity tracker
apps/android/app/build/outputs/apk/release/app-release.apk
apps/android/app/build/outputs/bundle/release/app-release.aab
Masjidly - Official Masjid Prayer Times/App/MasjidlyRootView.swift  # Update check + alert (iOS)
Masjidly - Official Masjid Prayer Times/Features/Updates/AppUpdateChecker.swift  # Update check logic (iOS)
Masjidly - Official Masjid Prayer Times/Features/Updates/WhatsNew.swift  # iOS What’s New + store notes source
apps/android/.../features/updates/UpdateChecker.kt  # Update check logic (Android)
apps/android/.../features/updates/WhatsNew.kt       # Android What’s New + Play notes source
```

### Website repo (`mwijanarko1/Sheffield-Masjids`)
```
public/masjidly/latest.json                          # Version manifest
public/masjidly/Masjidly-<version>.apk                # APK binaries
src/components/MasjidlyHomePopup.tsx                  # Home page download button
src/components/masjidly/MasjidlyLandingHero.tsx       # Masjidly landing page download button
```
