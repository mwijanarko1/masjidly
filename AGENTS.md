# Masjidly — Agent Standards

## Overview

Masjidly is a **multi-platform app** (iOS native SwiftUI + native Android Kotlin/Compose + legacy Expo Android) with a shared Convex backend. This document defines the exact procedures for building, publishing, and maintaining the in-app update infrastructure.

> **Android note:** Production APK releases still ship from `apps/expo/` until native `apps/android/` reaches full parity. Debug builds of the Kotlin app use `com.mikhailspeaks.masjidly.native` so they can install alongside Expo.

---

## Repos

| Repo | URL | Purpose |
|------|-----|---------|
| `masjidly` | `github.com/mwijanarko1/masjidly` | App source code (iOS + Expo) |
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

## 2. Releasing a New Android APK

Every new build **must** increment `versionCode` in `apps/expo/app.json`.

```bash
# 1. Bump versionCode
#    Edit apps/expo/app.json → increment "versionCode" by 1

# 2. Build the APK
cd apps/expo/android && ./gradlew assembleRelease

# 3. Copy with versioned name
cd apps/expo
cp android/app/build/outputs/apk/release/app-release.apk Masjidly-<version>.apk

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
git add apps/expo/app.json
git commit -m "chore: bump Android versionCode to <code>"
git push origin main
```

### Full example

```bash
# From the masjidly repo:
# Bump versionCode from 7 to 8 in app.json

cd apps/expo/android && ./gradlew assembleRelease

cd ..
cp android/app/build/outputs/apk/release/app-release.apk Masjidly-1.1.1.apk
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
git add apps/expo/app.json
git commit -m "chore: bump Android versionCode to 8"
git push origin main
```

---

## 3. Releasing a New iOS Version

1. Bump `MARKETING_VERSION` in Xcode project settings
2. Submit to App Store Connect
3. Update `latest.json` in website repo:
   - Set `ios.version` to new version
   - Update `pub_date`
4. Commit and push website repo

---

## 4. In-App Update Infrastructure

### iOS (`MasjidlyRootView.swift`)
- On launch, calls `AppUpdateChecker.checkForUpdate()`
- Fetches `latest.json` from website
- Compares version via `isVersion(_:newerThan:)` (dotted-numeric comparison)
- Shows system `.alert()` if update available
- "Open App Store" button calls `AppUpdateChecker.openAppStore()`

### Expo (`UpdatePromptModal.tsx` + `updateChecker.ts`)
- `checkForUpdate()` fetches `latest.json`, compares `versionCode` (Android) / `version` (iOS)
- Returns `UpdateInfo` with `updateAvailable`, `release`, `error`
- `UpdatePromptModal` shows a native modal with title + body + Download/Later buttons
- Auto-checks on launch (2s delay) via `<UpdatePromptModal autoCheck />` in `_layout.tsx`

### Test buttons (development builds only)
- **iOS:** Settings → Development section → "Test Update Prompt"
- **Expo:** Settings → Development section → "Test Update Prompt"

Both trigger a live check against `latest.json` (or show a test release if fetch fails).

---

## 5. Version Bumping Rules

- **Android versionCode**: increment by 1 for every build. Used for update comparison.
- **Android version** (app.json): bump for meaningful feature releases.
- **iOS version** (MARKETING_VERSION): bump for App Store releases.
- **iOS build** (CURRENT_PROJECT_VERSION): increment per build, not used for update checks.

---

## 6. Important Paths

### App repo (`mwijanarko1/masjidly`)
```
apps/android/app/build.gradle.kts           # Native Android versionName + versionCode (keep in sync with Expo)
apps/android/README.md                      # Native Android build instructions
apps/android/PARITY.md                      # iOS ↔ Kotlin parity tracker
apps/expo/app.json                          # Legacy Android version + versionCode (current release APK)
apps/expo/lib/updates/updateChecker.ts      # Update check logic (Expo)
apps/expo/components/updates/UpdatePromptModal.tsx  # Update modal UI (Expo)
apps/expo/app/_layout.tsx                   # Auto-check integration (Expo)
Masjidly - Official Masjid Prayer Times/App/MasjidlyRootView.swift  # Update check + alert (iOS)
Masjidly - Official Masjid Prayer Times/Features/Updates/AppUpdateChecker.swift  # Update check logic (iOS)
apps/android/.../features/updates/UpdateChecker.kt  # Update check logic (native Android)
```

### Website repo (`mwijanarko1/Sheffield-Masjids`)
```
public/masjidly/latest.json                          # Version manifest
public/masjidly/Masjidly-<version>.apk                # APK binaries
src/components/MasjidlyHomePopup.tsx                  # Home page download button
src/components/masjidly/MasjidlyLandingHero.tsx       # Masjidly landing page download button
```
