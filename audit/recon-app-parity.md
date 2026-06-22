# Recon: App Parity Audit — Expo ↔ iOS

## Files Inspected

**Expo (apps/expo/)**
| File | Lines | Relevance |
|------|-------|-----------|
| `app/_layout.tsx` | 1-165 | Stack nav: `index`, `timetable` (modal), `settings` (modal) |
| `app/index.tsx` | 1-~800 | Home screen: hero orb, prayer picker, date nav, calendar/settings buttons |
| `app/timetable.tsx` | 1-~700 | Full monthly timetable: day strip, prayer×iqamah rows, month switching |
| `app/settings.tsx` | 1-~1472 | Settings: country→city→mosque pickers, closest mosque, notifications, theme, qibla, dev buttons |

**iOS (Masjidly - Official Masjid Prayer Times/)**
| File | Lines | Relevance |
|------|-------|-----------|
| `App/MasjidlyRootView.swift` | 1-127 | Root: sets env, update check, AdhanMiniPlayerBar |
| `Masjidly___Official_Masjid_Prayer_TimesApp.swift` | 1-110 | `@main` App struct; notification delegate, env wiring |
| `Features/Home/HomeView.swift` | 1-~1094 | Home: hero orb, prayerLabels picker, date nav, calendar/settings buttons |
| `Features/Home/TimetableView.swift` | 1-~680 | Full-screen monthly timetable |
| `Features/Home/HomeUIComponents.swift` | ~353-~560 | `PrayerLabelsView` (letter picker), row components |
| `Features/Settings/SettingsView.swift` | 1-~1330 | Settings: country→city→mosque pickers, closest mosque row, notifications, theme, qibla |
| `Features/Onboarding/OnboardingStep.swift` | 1-18 | Onboarding steps enum |
| `Features/Onboarding/MosqueSelectionOnboardingView.swift` | 1-~103 | Mosque picker during onboarding |

---

## Page/Button Inventory: Expo ↔ iOS

### Navigation Structure

| | Expo | iOS |
|---|---|---|
| **Root** | `Stack` 3 screens | App @main → `MasjidlyRootView` → `HomeView` |
| **Home** | `app/index.tsx` (Stack: index) | `HomeView.swift` (embedded, no nav stack) |
| **Timetable** | `app/timetable.tsx` (`presentation: modal` via Stack) | `TimetableView.swift` (`.fullScreenCover` from Home) |
| **Settings** | `app/settings.tsx` (`presentation: modal` via Stack) | `SettingsView.swift` (`.fullScreenCover` from Home) |

### Home screen controls — mapped 1:1

| Control | Expo (`app/index.tsx`) | iOS (`HomeView.swift`) |
|---------|-----------------------|-----------------------|
| Calendar button | l.156–168: `router.push("/timetable")` | l.571: `showingTimetable = true` (fullScreenCover) |
| Settings button | l.191–201: `router.push("/settings")` | l.555: `showingSettings = true` (fullScreenCover) |
| Date display / go-today | l.172–183: `goToToday` press → reset date | l.723: `dateDisplay` → `model.goToToday()` |
| Prev/Next day arrows | l.161, 187: `goToPreviousDay` / `goToNextDay` | l.728, 733: `model.goToPreviousDay()` / `goToNextDay()` |
| Hero orb (countdown + qibla) | `HeroOrbSection` → `QiblaPrayerIcon` | `QiblaDirectionView` inside homeContent |
| Prayer letter picker | `PrayerLetterPicker` (l.252–257) | `PrayerLabelsView` (in `HomeUIComponents.swift` l.509–560) |
| Iqamah subtitle under clock | l.236 (computed `selectedPrayerSubtitle`) | `heroIqamahLabel` computed property |
| AdhanMiniPlayerBar | `apps/expo/components/ui/AdhanMiniPlayerBar.tsx` | `Features/Audio/AdhanMiniPlayerBar.swift` |

### Settings screen sections — mapped 1:1

| Section | Expo (`app/settings.tsx`) | iOS (`SettingsView.swift`) |
|---------|--------------------------|----------------------------|
| Country picker | l.763–773 `SettingsMenuPickerRow` | l.54 `countryPickerRow` |
| City picker | l.774–784 | l.55 `cityPickerRow` |
| Mosque picker | l.785–812 | l.56 `mosquePickerRow` |
| Closest mosque row | l.790–811: `closestMosque` computed + button | l.57–59: `closestMosque` computed + `closestMosqueRow()` |
| 24h toggle | `SettingsToggleRow` | `SettingsToggleRow` |
| Asr adhan preference | `SettingsMenuPickerRow` (shown when supported) | `asrPickerRow` |
| Language picker | `SettingsMenuPickerRow` | `languagePickerRow` |
| Theme mode/fixed | `SettingsMenuPickerRow` | `themeModePickerRow` / `fixedThemePickerRow` |
| Qibla toggle | `SettingsToggleRow` | `qiblaToggleRow` |
| Location recovery | Conditional card | `locationRecoveryRow` |
| Notification master | `SettingsToggleRow` | `masterToggleRow` |
| Adhan per-prayer toggles | Expandable section w/ per-prayer toggles | Expandable section w/ per-prayer toggles |
| Iqamah per-prayer toggles | Same pattern | Same pattern |
| Pre-adhan reminder | `SettingsMenuPickerRow` (none/5/10/15/30) | `preAdhanReminderPicker` |
| Pre-iqamah reminder | Same pattern | Same pattern |
| Contact cards (feedback, prayer times, request masjid) | 3 pressable cards | 3 pressable cards |
| Dev section (test notifications, reset tutorial, test update) | 6+ buttons (__DEV__ gated) | Settings dev section (same set) |
| "Test Update Prompt" | `DeviceEventEmitter` → `showTestUpdatePrompt` | Notification `masjidlyShowUpdatePrompt` → presentTestUpdateAlert |

---

## Closest Mosque Evidence

### Data flow (both platforms — identical algorithm)

1. Fetch user coordinates via location API
2. Fetch all mosques from Convex `listMosques`
3. Compute Haversine distance to each mosque
4. Find minimum-distance mosque
5. Show computed name + "Select closest mosque" button

### Expo
- **File**: `apps/expo/app/settings.tsx`
- **Coord fetch**: l.264–287 — `expo-location` `getCurrentPositionAsync` (Balanced accuracy)
- **Distance calc**: l.1307–1314 — local `distanceInMeters()` (Haversine)
- **Closest logic**: l.674–681 — `useMemo` reduces over all mosques
- **Render**: l.790–811 — label `"Closest mosque: %s"` + `"Select closest mosque"` button → calls `handleMosqueSelect(closestMosque)`
- **Guard**: hidden if `hideQiblaCompass` or no coords or no mosques

### iOS
- **File**: `Masjidly - Official Masjid Prayer Times/Features/Settings/SettingsView.swift`
- **Coord provider**: l.1100–1146 — `SettingsClosestMosqueLocationProvider` (CLLocationManager, 100m accuracy, 250m filter)
- **Distance calc**: n/a, uses `CLLocation.distance(from:)` built-in (Haversine via CoreLocation)
- **Closest logic**: l.545–556 — computed var `closestMosque` uses `model.mosques.min` with `userLocation.distance(from:)`
- **Render**: l.562–591 — `closestMosqueRow()`: text `"Closest mosque: \(name)"` + `"Use closest mosque"` button → calls `model.selectMosque(mosque)`
- **Guard**: hidden if `hideQiblaCompass`, location not authorized, or no current location

### Key difference: location lifecycle
- **Expo**: fetches coordinates once on mount via `expo-location`; no continuous updates
- **iOS**: `CLLocationManager` with `requestLocation()` (one-shot), but re-fetches on `.willEnterForeground` and `hideQiblaCompass` toggle; also re-checks on authorization change delegate

---

## Gaps & Risks

1. **Location accuracy**: Expo uses `Location.Accuracy.Balanced` (roughly 100-300m), iOS uses `kCLLocationAccuracyHundredMeters` + `distanceFilter 250`. Roughly equivalent, but iOS won't update as user moves (one-shot `requestLocation`). No continuous tracking on either side — fine for closest mosque.

2. **Onboarding flow**: Both have identical step sequence (mosque → qibla → countdown → timetable → settings → shortcuts → notifications). The Expo side embeds `TutorialOverlay` in each screen; iOS embeds `OnboardingTutorialChrome` as an overlay in `HomeView`. Steps should map 1:1.

3. **Missing times UX**: Expo shows inline card with email button; iOS shows `missingCurrentMonthTimesView` with same email + a "go to last available date" fallback button (`hasAvailablePrayerTimesFallback`). iOS has an extra fallback not in Expo.

4. **Push notification categories**: Both register identical categories (adhan, iqamah, reminder) with same action IDs. Snooze logic matches (10min). No parity gap.

5. **Update infrastructure**: Both fetch `latest.json` and compare versions identically per AGENTS.md. Expo shows modal; iOS shows system `.alert()`.

6. **Ramadan timetable**: iOS `PrayerRepository` protocol has `getRamadanTimetable` method (used in Watch/tests). Expo has no equivalent visible in the routes. Might be dormant on both sides.

7. **Test buttons**: Dev section parity is 1:1 (test adhan, iqamah, reminder, all, update prompt, whats new, reset tutorial). No gaps.

---

## Suggested Next Specialist(s)

- **Home screen audit specialist**: Verify hero orb countdown logic parity (Expo `heroCountdownPresentation` ↔ iOS `PrayerTimesEngine`), date/day navigation, qibla compass rendering, and missing times fallback.
- **Onboarding flow specialist**: Walk through step-by-step to confirm tutorial overlay sequencing and coach mark targeting match.
- **Needs parent**: No. This recon is sufficient for a specialist to dive into specific areas. Send a home screen or settings specialist directly.
