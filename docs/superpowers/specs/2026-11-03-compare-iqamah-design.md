# Compare: design spec

Status: draft for review (revision 2)
Date: 2026-11-03
Platforms: iOS (SwiftUI) and Android (Kotlin/Compose), parity required

## 1. Problem

A user wants to find a masjid with a later (or earlier) iqamah than their own masjid. Today the only way is to add masjid tabs one by one on Home and check each tab. That is slow and pollutes the Home tab bar.

## 2. Goal

One **Compare** page with two modes:

- **Masjids**: the user builds a personal list of masjids (any city) and sees their times side by side for a day.
- **By time**: the user enters a time and finds which masjids in a city have a jamaat or adhan after (or before) it.

### Non-goals

- Backend or Convex changes.
- A bottom tab bar or other navigation redesign.
- A shortcut from Home prayer rows (possible follow-up).
- Distance or map features.
- Syncing the compare list with Home masjid tabs. They are separate lists.

## 3. Entry point

- A new circular **Compare** button in the Home header, styled like the existing timetable and settings buttons (44x44, `Circle().fill(Color.white.opacity(0.18))`, text color from the current appearance).
- Placement: next to the timetable (calendar) button.
  - iOS: beside `calendarButton` in `Features/Home/HomeView.swift`.
  - Android: beside the `Icons.Default.CalendarMonth` button in `features/home/HomeScreen.kt`.
- Icon: iOS SF Symbol `arrow.left.arrow.right`; Android `Icons.AutoMirrored.Filled.CompareArrows` (or the closest Material equivalent).
- Always visible.
- Presentation: same as the timetable.
  - iOS: `.fullScreenCover`.
  - Android: new route `MasjidlyDestination.Compare = "compare"` in `ui/navigation/MasjidlyDestination.kt` and `MasjidlyNavHost.kt`.

## 4. Page shell

```
+---------------------------------------+
|  x            Compare                 |  header: close, title
|        [ Masjids | By time ]          |  mode switch
|          <   Tue 3 Nov   >            |  day stepper, shared by both modes
|                                       |
|  ... mode content ...                 |
+---------------------------------------+
```

- Title: **Compare**.
- Mode switch: segmented control, **Masjids** (default) and **By time**. The page remembers the last mode used.
- Day stepper: defaults to the day Home shows. `<` and `>` move one day. Shared by both modes.
- Visual style: match `TimetableView`: same time-of-day background and appearance via `settings.resolvedAppearance(for:)`, Comfortaa typography, compact spacing (see `docs/DESIGN.md`).

## 5. Mode: Masjids

### 5.1 Empty state

On the first open (after the user installs or updates to this version) the compare list is empty:

```
|          Compare masjid times         |
|   Add masjids to see their times      |
|            side by side.              |
|                                       |
|            [ + Add masjid ]           |
```

The list persists between sessions after that:

- iOS: new `SettingsStore.compareMosqueIds: [String]`.
- Android: the matching settings key in the existing settings store.

### 5.2 Adding and removing masjids

- A `+` button in the mode content header, plus the empty-state button, opens a masjid picker.
- Picker: reuse the existing add-masjid-tab picker UI, with search, masjids from every city grouped by city, and already-added masjids shown as checked. Multi-select, with a Done button.
- Limit: 10 masjids. At 10 the picker disables the remaining rows and shows "Up to 10 masjids".
- Remove: iOS swipe-to-delete on a row; Android long-press menu. Both platforms also offer **Remove** in the row's context menu.
- Order: the order in which masjids were added. Your Home masjid, if present, is pinned first.

### 5.3 Day grid

```
              Fajr  Dhuhr  Asr   Mag   Isha
Al-Huda (you) 06:15 12:45  14:30 16:35 19:45
Tawhid        06:00 13:00  14:45 16:40 20:00
               -15   +15    +15   +5    +15
Jamia         06:30 12:30  14:15 16:35 20:30
               +15   -15    -15   0     +45
Umar          06:10 13:15  14:15 16:38 20:15
                           16:00        21:00
Madina        06:10 13:15  15:00 16:38 20:15
Leeds
```

- Rows are masjids. Columns are Fajr, Dhuhr, Asr, Maghrib, Isha. On Fridays the Dhuhr column header reads **Jummah** and uses Jummah iqamah, matching Home.
- The masjid name column is sticky. When the list contains masjids from more than one city, each name shows its city on a second line.
- Cells show the iqamah. Several jamaats (for example two Asr slots or two Jummahs) stack vertically in one cell.
- Non-time values (for example "After Maghrib") show as smaller wrapped text.
- A cell with no data shows "-".
- Highlight: the latest clock time in each column gets a subtle emphasis (bold or accent tint). Ties are all highlighted.
- Sorting: tap a prayer header to sort the rows by that prayer's earliest slot, ascending. Tap again for descending, and a third time to return to the added order. Your masjid stays pinned first in every sort. Non-time and empty cells sort last.
- Width: with the 12-hour setting the grid omits AM/PM (the column makes it clear). With the largest text sizes the prayer columns scroll horizontally while the name column stays fixed.
- RTL (Arabic, Urdu): the column order and the sticky column mirror.

### 5.4 Deltas against your masjid

- When your Home masjid (the active masjid tab, otherwise `selectedMosqueId`) is in the list, its row is labelled "(yours)" and every other row shows a small signed minute delta under each time: "+15", "-10", "0". Above 59 minutes: "+1h10".
- Delta baseline: the iqamah Home shows for your masjid for that prayer and day (for Asr, the slot chosen by your `AsrIqamahPreference`).
- The delta uses the other masjid's earliest slot for that prayer.
- No delta when either side has no clock time.
- No delta for a masjid in a different time zone from yours (compare `Mosque.timezone`; if either is missing, fall back to equal `countryCode`). Wall-clock times in different zones are not comparable.
- When your masjid is not in the list, no deltas are shown.

### 5.5 Row actions

- Tap a row: open that masjid on Home. Reuse the existing add-tab and select-tab flow (add the tab if it is not open, make it active), then dismiss the page.
- Context menu: **Open on Home**, **Remove**.

## 6. Mode: By time

### 6.1 Controls

```
|  City        [ Sheffield         v ]  |
|  Prayer      [ Any | Fajr | ... ]     |
|  Type        [ Jamaat | Adhan ]       |
|  Time        [ After v ] [ 20:30 ]    |
```

| Control | Default | Behaviour |
|---|---|---|
| City | Your Home masjid's city | Picker of every city with at least one visible masjid, using `cityGroupingKey`. Search spans one city at a time because times in different cities are not comparable. |
| Prayer | Any | **Any**, Fajr, Dhuhr (Jummah on Fridays), Asr, Maghrib, Isha. |
| Type | Jamaat | **Jamaat** uses iqamah times. **Adhan** uses the prayer start times from the monthly timetable. |
| Direction | After | **After** or **Before** the chosen time. |
| Time | Today: now, rounded up to the next 5 minutes. Other days: 12:00. | Time picker. Respects the 12h/24h setting. |

### 6.2 Results

```
|  Jamaats after 20:30 in Sheffield     |
|                                       |
|  Isha   20:30  Jamia            [+]   |
|                in 25 min              |
|  Isha   20:45  Madina           [+]   |
|  Isha   21:00  Umar             [+]   |
|  -----------------------------------  |
|  3 masjids have no fixed time         |
|  Loading 14 of 20 masjids...          |
```

- Results: every matching slot from every visible masjid in the city. **After** includes slots at or after the time, sorted ascending. **Before** includes slots at or before the time, sorted descending (closest first).
- Each row: prayer name (shown when Prayer is Any), time, masjid name. On today, the row also shows "in N min" or "N min ago".
- A masjid with several matching slots appears once per slot.
- `[+]` adds that masjid to the compare list (checked when already added). At the 10-masjid limit it is disabled.
- Tap a row: open that masjid on Home, same as section 5.5.
- Footer: count of masjids whose value for the prayer is not a clock time ("No fixed time"), and a loading progress line while fetches are still running.
- Empty: "No jamaats after 20:30" (or the matching wording for adhan and before), plus a button to go to the next day when the day is today.

## 7. Time resolution rules

Every time on the page must match what Home, the timetable, and widgets show for that masjid. Do not write new parsing.

- Day data: `PrayerTimesEngine.resolveIqamahTimes(on:monthly:ramadan:)` on iOS and `PrayerTimesEngine.resolveIqamahTimes` on Android. These already handle Ramadan timetables and the monthly Jummah fallback.
- Iqamah display value: `PrayerTimesEngine.getDisplayIqamah(...)` on both platforms. This handles `adhan + N`, "sunset", "Entry Time", "Straight after Maghrib", and the masjid-specific Isha rules.
- Multiple jamaats: `splitIqamahTimes`. Asr: all slots from `getAsrIqamahSlots`, not only the user's preferred slot, because another masjid's second slot can be the one the user needs.
- Adhan times: the same day row Home uses for prayer start times (with the Asr adhan following `selectAsrAdhanTime` and the user's preference).
- Format with the user's 12h/24h setting (`uses24HourTime`).
- "Today" and time zone: same logic as Home.

## 8. Data loading

No backend change. Use the existing repository calls and disk cache (`PrayerTimesDiskCache` on iOS and the matching cache on Android, with the same version checks as `HomeViewModel`).

- Per masjid: `prayerTimes:getMonthly` for the selected month, plus `prayerTimes:getRamadan` when the date is in Ramadan.
- Masjids mode loads only the masjids in the compare list (10 at most).
- By time mode loads every visible masjid in the chosen city. This is the expensive path (34 masjids in London).
- For both modes:
  1. Render whatever is cached immediately.
  2. Fetch missing or stale masjids in parallel, with at most 6 requests in flight.
  3. Fill in rows and results as each fetch finishes. A failed fetch shows "Couldn't load" (Masjids mode, tap to retry) or is counted in the footer (By time mode, with a retry button).
  4. Offline: cached data only. Uncached masjids show "Offline".
  5. Crossing a month boundary with the day stepper loads that month for the masjids involved.
  6. Leaving the page or switching city cancels fetches in flight. Completed fetches stay in the disk cache.

## 9. Localization and accessibility

- All new strings in en, ar, ur, id. Arabic and Urdu use RTL layout.
- New string keys (names indicative):
  - `compare.title` "Compare"
  - `compare.mode.masjids` "Masjids", `compare.mode.byTime` "By time"
  - `compare.empty.title` "Compare masjid times", `compare.empty.body` "Add masjids to see their times side by side.", `compare.add` "Add masjid"
  - `compare.limit` "Up to 10 masjids"
  - `compare.yours` "(yours)"
  - `compare.openOnHome` "Open on Home", `compare.remove` "Remove"
  - `compare.find.city` "City", `compare.find.prayer` "Prayer", `compare.find.any` "Any", `compare.find.type` "Type", `compare.find.jamaat` "Jamaat", `compare.find.adhan` "Adhan", `compare.find.after` "After", `compare.find.before` "Before", `compare.find.time` "Time"
  - `compare.find.header.jamaatAfter` "Jamaats after %@ in %@" (and the adhan and before variants)
  - `compare.find.inMinutes` "in %d min", `compare.find.minutesAgo` "%d min ago"
  - `compare.find.noFixedTime` "%d masjids have no fixed time"
  - `compare.find.loading` "Loading %d of %d masjids"
  - `compare.find.empty` "No jamaats after %@", `compare.find.nextDay` "Next day"
  - `compare.error.load` "Couldn't load", `compare.error.offline` "Offline"
  - `accessibility.compare` "Compare masjid times"
- Grid accessibility: each cell reads "<Masjid>, <Prayer> iqamah <time>, <delta> than yours". Header buttons announce the sort state.
- Result row accessibility: "<Prayer> jamaat at <time>, <Masjid>, in <N> minutes".

## 10. Acceptance criteria

1. The Compare button appears in the Home header and opens the Compare page.
2. On the first open after the update, Masjids mode shows the empty state.
3. Masjids from different cities can be added. Added masjids persist after the app is restarted. The limit is 10.
4. Each grid cell equals the iqamah shown on Home for that masjid and day.
5. Deltas show only when your Home masjid is in the list, and only for masjids in your time zone.
6. Tapping a prayer header sorts the rows by that prayer, keeping your masjid first.
7. On a Friday the Dhuhr column and Prayer option show Jummah.
8. During Ramadan both modes use Ramadan timetable iqamah, matching Home.
9. By time mode lists exactly the slots in the chosen city that are after (or before) the chosen time, for the chosen prayer and type, in the right order.
10. `[+]` in By time mode adds the masjid to the compare list.
11. Tapping a masjid in either mode makes it the active Home tab and closes the page.
12. With the network off and a warm cache, cached data shows, uncached masjids show "Offline", and nothing crashes.
13. All strings appear in the four languages, and Arabic and Urdu layouts are RTL.
14. iOS and Android behave the same for criteria 1 to 13.

## 11. Testing

Per repo policy: E2E first, no new unit tests. Tests are written by the test owner, not by the implementer.

- iOS: UI tests in `Masjidly - Official Masjid Prayer TimesUITests` covering criteria 1, 2, 3, 6, 9, 10, and 11 with fixture data.
- Android: the equivalent instrumented UI tests.
- Criterion 4 (parity with Home) is the highest-risk rule. Cover it with an integration test that resolves several real published timetables through the compare path and the Home path and asserts equal output. Integration level is justified because driving every masjid and day through the UI is disproportionate.
- Visual evidence: screenshots of both modes in light and dark appearance, en and ar, on iPhone and Android, plus the empty, loading, error, 10-masjid, and largest-text states.

## 12. Risks

- **By time first load.** A cold search in a large city sends one `getMonthly` request per masjid (34 for London). Mitigation: cache, concurrency cap, progressive results. If a real-device measurement shows this is slow, a city-day Convex query is the fallback (out of scope here).
- **Grid width.** Six columns at 375pt is tight, especially with long Arabic names and stacked jamaats. Mitigation: sticky name column, no AM/PM, horizontal scroll at the largest text sizes. Validate with screenshots before review.
- **Time zone.** `PrayerTimesEngine` resolves "today" in the Sheffield time zone. Masjids outside the UK inherit the same behaviour as Home today. This spec does not change it.
- **Non-time values.** Values outside the known patterns show as text, never sort as times, and are excluded from By time results (counted in the footer instead).
