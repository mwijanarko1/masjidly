# Home + Timetable Parity Audit: Expo ↔ iOS

**Skills loaded:** `ios-development`, `ios-app-store-compliance`, `vercel-react-native-skills`, `expo-docs`, `coding-standards`, `testing-strategies`

**Date:** 2026-06-19

---

## Files inspected

**Expo:**
- `apps/expo/app/index.tsx` (home screen, ~360 lines logic + render)
- `apps/expo/app/timetable.tsx` (monthly timetable, ~370 lines logic + render)
- `apps/expo/components/ui/PrayerRow.tsx` (shared row component)
- `apps/expo/components/ui/AdhanMiniPlayerBar.tsx` (audio player bar)
- `apps/expo/app/_layout.tsx` (navigation structure, ~50 lines)

**iOS:**
- `Features/Home/HomeView.swift` (~1090 lines)
- `Features/Home/TimetableView.swift` (~680 lines)
- `Features/Home/HomeUIComponents.swift` (~210 lines: `MinimalistPrayerPage` + components)
- `Features/Audio/AdhanMiniPlayerBar.swift` (~105 lines)
- `Features/Settings/AppReviewPromptCoordinator.swift` (referenced)

---

## Matched controls (1:1 parity)

| Control | Expo | iOS | Status |
|---------|------|-----|--------|
| Calendar button → timetable modal | `index.tsx:156` | `HomeView.swift:571` | ✓ |
| Settings button → settings modal | `index.tsx:191` | `HomeView.swift:555` | ✓ |
| Prev/Next day arrows | `index.tsx:161,187` | `HomeView.swift:728,733` | ✓ |
| Date display (gregorian + hijri) | `index.tsx:618-636` | `HomeView.swift:735-747` | ✓ |
| Hero orb (qibla + countdown) | `index.tsx:249-265` (HeroOrbSection) | `HomeUIComponents.swift:265-352` (MinimalistPrayerPage.heroOrb) | ✓ |
| Countdown tap/long-press | `index.tsx:271-283` | `HomeUIComponents.swift:354-371` | ✓ |
| Prayer letter picker (F/S/D/A/M/I) | `index.tsx:252-257` | `HomeUIComponents.swift:393-473` | ✓ |
| Iqamah subtitle under clock | `index.tsx:236` (computed) | `HomeView.swift:709-715` (iqamahSubtitleLine) | ✓ |
| AdhanMiniPlayerBar | `AdhanMiniPlayerBar.tsx:43-90` | `AdhanMiniPlayerBar.swift:16-65` | ✓ |
| Timetable: header bar (date + mosque) | `timetable.tsx:215-232` | `TimetableView.swift:347-384` | ✓ |
| Timetable: close button | `timetable.tsx:233-247` | `TimetableView.swift:369-384` | ✓ |
| Timetable: month switcher | `timetable.tsx:249-269` | `TimetableView.swift:219-261` | ✓ |
| Timetable: scrollable date strip | `timetable.tsx:271-307` | `TimetableView.swift:386-442` | ✓ |
| Timetable: prayer rows (6+midnight+lastThird) | `timetable.tsx:329-404` | `TimetableView.swift:482-553` | ✓ |
| Timetable: missing-month email CTA | `timetable.tsx:326-340` | `TimetableView.swift:447-470` | ✓ |
| Friday → Jummah substitution | `index.tsx:193, timetable.tsx:347-376` | `HomeView.swift:697, TimetableView.swift:562-599` | ✓ |
| Initial prayer = next prayer (or Isha) | `index.tsx:238-243` | `HomeView.swift:719-727` | ✓ |
| What's New modal | `index.tsx:310-328` | `HomeView.swift:743-809` | ✓ |
| Onboarding tutorial overlay | `index.tsx:304-309` | `HomeView.swift:452-547` | ✓ |

---

## Parity gaps — ranked

### BLOCKER (1)

**1. Missing-times fallback: iOS has "go to last available date" button, Expo does not**
- iOS `HomeView.swift:274`: `model.goToLastAvailablePrayerDate()` button shown when `hasAvailablePrayerTimesFallback` is true.
- Expo `index.tsx:261-298`: only shows email + retry buttons; no equivalent fallback navigation.
- Impact: Expo users stuck on current month when times are missing but earlier/later months have data. iOS users can jump to the last month with data.

### HIGH (3)

**2. Error state: iOS shows stuck spinner, Expo shows retry button**
- Expo `index.tsx:299-302`: when `loadState === "error"`, shows a tappable "Retry" button at the bottom.
- iOS `HomeView.swift:564-567`: error state falls through to `ProgressView()` (spinner) with no dismiss/retry. If `loadState == .error` and `displayedPrayerTimes` is nil, neither the `if let d =` nor `shouldShowMissingCurrentMonthTimes` (which checks `.loaded || .empty`) matches → infinite spinner.
- Impact: iOS users could face a stuck spinner on network errors with no retry affordance. File: `HomeView.swift:564` (else → `ProgressView()`).

**3. Notification recovery prompt: Expo has it, iOS has none**
- Expo `index.tsx:315-319`: `NotificationRecoveryModal` checks for permission issues on launch and offers fix.
- iOS: **No equivalent** — zero matches for notification recovery in `Features/Home/`.
- Impact: iOS users who denied notification permissions are never prompted to re-enable them. Only the onboarding notification step exists (which is a one-time setup).

**4. In-app review prompt: iOS has full flow, Expo has none**
- iOS `HomeView.swift:46-69,159-194`: `enjoymentReviewAlert` (love it / not really) + feedback email prompt, coordinated by `AppReviewPromptCoordinator`.
- Expo: **No review prompt code** anywhere on home screen.
- Impact: iOS accumulates App Store review opportunities; Expo has zero.

### MEDIUM (2)

**5. "Go to today" tap on date display: Expo has it, iOS lacks it**
- Expo `index.tsx:617`: date container is a `Pressable` with `onPress={goToToday}`.
- iOS `HomeView.swift:735-747`: date `VStack` has no tap/gesture handler. `model.goToToday()` exists on the view model (`HomeViewModel.swift:161`) but is never wired in the view.
- Impact: iOS users cannot tap the date to reset to today; must navigate day-by-day. File: `HomeView.swift:735-747`.

**6. Timetable initial theme: Expo passes selected prayer, iOS uses static initial theme**
- Expo passes `theme: selectedPrayer` via URL param → `timetable.tsx:56`.
- iOS `TimetableView.swift:16`: `timeTheme` is fixed at initialization from whatever was current when `showingTimetable` was set.
- Impact: Minor — iOS timetable uses the prayer theme that was selected at open time, not the dynamic one. Cosmetic, no data difference.

### LOW (1)

**7. AdhanMiniPlayerBar styling divergence**
- Expo: `expo-linear-gradient` with semi-transparent overlay.
- iOS: `OnboardingTutorialChrome.card` wrapper with native Capsule + gradient.
- Both functionally identical (play/pause, progress, dismiss). Visual framing differs slightly.
- Impact: None beyond visual.

---

## Closest related risks

- **Friday detection**: Expo uses `Intl.DateTimeFormat("en-GB", { timeZone: "Europe/London" })` — locale-dependent (en-GB hardcoded). iOS uses `Calendar` with `PrayerTimesEngine.sheffieldTimeZone`. If the device locale changes weekday names, Expo's `startsWith("f")` check could break for non-English locales. Low risk in UK-centric context.
- **`isTimePast` next-day logic**: Both platforms handle midnight/last-third correctly with PM guards. No gap.
- **Ramadan timetable**: Both `prayerRepository`/`prayerRepository.ts` have Ramadan APIs and caching. Neither home screen surfaces Ramadan UI — dormant on both sides. Not a gap.

---

## Recommended smallest fixes

1. **(Blocker)** Add `goToLastAvailablePrayerDate()` equivalent to Expo `useHomePrayerData`/`useHomePrayerData.ts` — expose a fallback date method and add a "View available times" button in the missing-times empty state (`index.tsx:261-298`). ~15 lines.
2. **(High)** Wire `model.goToToday()` to the date VStack in iOS `HomeView.swift` — add `.onTapGesture { model.goToToday() }` on the date container. ~3 lines.
3. **(High)** Add error-state retry UI to iOS `HomeView.swift` — show a "Retry" button when `loadState == .error && selectedMosque != nil`. ~10 lines.
4. **(High)** Add `NotificationRecoveryModal` equivalent to iOS `HomeView.swift`, or port the permission check from Expo. ~30 lines.
5. **(Medium)** Wire iOS `model.goToToday()` to date-display gesture — same as #2.
6. **(Medium-low)** Pass dynamic theme to iOS `TimetableView` by refreshing `timeTheme` from the selected prayer index instead of capturing at init. ~5 lines.

---

**Needs parent:** No. All gaps are client-side, single-platform. A mobile engineer can address each independently.
