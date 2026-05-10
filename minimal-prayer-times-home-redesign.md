# Minimal Prayer Times Home Redesign

## Summary

Replace the full-screen prayer slideshow in `HomeView` with a single, minimal home screen:

- Large focus area for the next/current prayer.
- Compact list showing all daily prayer times at once.
- No swiping, no page dots, no per-prayer full-screen pages.
- Keep the existing time formatting, theme colors, settings sheet, and data flow.

Loaded skills: `ai-interaction-workflow`, `coding-standards`, `testing-strategies`, `swiftui-pro`, `ios-development`.

## Current State

The slideshow behavior lives in:

- `Masjidly - Official Masjid Prayer Times/Features/Home/HomeView.swift`
  - `@State private var selectedPrayerIndex`
  - `TabView(selection:)`
  - `currentActiveTheme(d:)` uses selected page for the background theme.

- `Masjidly - Official Masjid Prayer Times/Features/Home/HomeUIComponents.swift`
  - `MinimalistPrayerPage`
  - `MinimalistDomeIcon`
  - slideshow dot indicators inside `MinimalistPrayerPage`.

## Target UX

Use a “one-screen list” layout:

1. Top right: existing settings button.
2. Center/top focus:
   - optional minimal dome mark or very small symbol
   - next prayer name
   - next prayer time
   - countdown if available from `model.nextCountdown`
3. Below focus: compact daily prayer list:
   - Fajr
   - Sunrise
   - Dhuhr or Jummah when relevant
   - Asr
   - Maghrib
   - Isha
4. Highlight only the row matching `model.nextCountdown?.nextName`.
5. Remove page indicators and full-screen paging.

## Public Interfaces / Types

No domain model or repository API changes.

Add local UI-only helper types in the Home feature:

```swift
private struct PrayerDisplayItem: Identifiable, Equatable {
    let id: String
    let name: String
    let time: String
    let theme: HomeDesign.TimeTheme
    let isNext: Bool
}
```

This should stay private to `HomeView.swift` unless reused elsewhere.

## Implementation Steps

1. In `HomeView.swift`, remove slideshow state:
   - Delete `selectedPrayerIndex`.
   - Delete the `TabView`.
   - Delete `currentActiveTheme(d:)` dependency on selected page.

2. Add computed prayer display items:
   - Build items from `model.displayedPrayerTimes`.
   - Apply `formatTime(_:)`.
   - Mark `isNext` using `model.nextCountdown?.nextName`.
   - Map `Sunrise` to `.sunrise`, `Fajr` to `.fajr`, etc.
   - Treat `Jummah` as the Dhuhr row visually, because the daily data model has Dhuhr time and the countdown can name Jummah.

3. Theme the page from the next prayer:
   - Prefer `model.nextCountdown?.nextName`.
   - Fall back to `.fajr` while data is missing.
   - This keeps the background stable and meaningful without user paging.

4. Replace `MinimalistPrayerPage` with new components:
   - `MinimalPrayerOverview`
   - `NextPrayerFocus`
   - `DailyPrayerList`
   - `DailyPrayerRow`

5. Keep styling minimal:
   - Use one gradient background from `HomeDesign.TimeTheme`.
   - Remove large per-page spacing.
   - Use small text labels, strong time hierarchy, thin dividers, and subtle opacity.
   - Avoid nested card-on-card layout.
   - Use stable row heights so times do not shift.

6. Clean up unused components if no longer referenced:
   - Remove `MinimalistPrayerPage`.
   - Remove `PrayerCarouselItem` if still unused after the redesign.
   - Keep `MinimalistDomeIcon` only if the new focus area uses it.

7. Preserve existing sheets:
   - Keep settings sheet.
   - Leave `TimetableView` untouched unless a separate entry point is requested.
   - Note: `showingTimetable` currently exists but no visible button sets it to `true`; this plan does not solve that unless requested.

## Accessibility

- Add a combined accessibility label for the next prayer focus, for example:
  - “Next prayer, Asr, 5:42 PM”
- Each row should expose prayer name and time together.
- The highlighted row should not rely on color alone:
  - Include a small “Next” text marker or semantic label.
- Keep Dynamic Type resilient with `minimumScaleFactor` and predictable row layout.

## Test Cases / Verification

### Fast checks

Run Swift tests:

```bash
xcodebuild test \
  -project "Masjidly - Official Masjid Prayer Times.xcodeproj" \
  -scheme "Masjidly - Official Masjid Prayer Times" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Manual UI verification

Verify on simulator:

- Home screen no longer swipes between prayer pages.
- All six daily prayer times are visible without interaction on a normal iPhone viewport.
- The next prayer is visually emphasized.
- 12-hour / 24-hour setting still changes all displayed times.
- Settings button still opens settings.
- Loading state still shows `ProgressView`.
- Isha/dark theme keeps readable contrast.
- Larger text sizes do not overlap or clip core prayer data.

### Optional focused test

If adding a pure helper function for prayer display items, add Swift Testing coverage for:

- all six items are generated from `DailyPrayerTimes`
- next prayer row is marked correctly
- Jummah maps to Dhuhr visual row
- 12-hour formatting remains delegated to existing `formatTime(_:)`

## Assumptions

- The app being changed is the native SwiftUI iOS app, not the Expo template.
- “More minimalistic” means fewer interactions and less visual noise, not fewer prayer times.
- The preferred direction is the one-screen list selected by the user.
- No backend, notification, Convex, or prayer-time calculation behavior should change.
