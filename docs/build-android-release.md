# Android release APK

```bash
cd apps/android

# Bump versionCode / versionName in app/build.gradle.kts first

./gradlew :app:assembleRelease

cp app/build/outputs/apk/release/app-release.apk Masjidly-<version>.apk
shasum -a 256 Masjidly-<version>.apk
```

See `AGENTS.md` for publishing to sheffieldmasjids.com and updating `latest.json`.
