# Android Expo Feature Parity With Native iOS Masjidly

## Summary

Bring `apps/expo` from template state to Android feature parity with the native SwiftUI Masjidly app. The native iOS app remains the source of truth for behavior; the Expo app will target Android only, using platform-appropriate React Native UI while matching the same domain behavior, data source, settings, localization, timetable, and local prayer notification flows.

Current state:
- Native iOS app is feature-complete around Convex prayer data, mosque selection, next-prayer calculation, timetable, settings, localization, and local notifications.
- Expo app is still a generic template with Home/Profile tabs, generic auth store, generic constants, and a basic notification hook.
- Backend Convex functions are external to this repo, so Expo must call the existing public Convex queries by function reference name.

Primary outcome:
- Android users can open the Expo app, see official selected-mosque prayer times, switch mosque, view timetable, change language/time format, and schedule/cancel local prayer notifications with the same calculation rules as native iOS.

## Scope

In scope:
- Android Expo app only.
- Replace template screens with Masjidly app screens.
- Use the same Convex deployment URLs as native iOS:
  - debug/dev: `https://upbeat-goat-583.eu-west-1.convex.cloud`
  - release/prod: `https://zany-mockingbird-207.eu-west-1.convex.cloud`
- Port native domain models and `PrayerTimesEngine` behavior to TypeScript.
- Implement persistent settings.
- Implement local Android notifications using `expo-notifications`.
- Copy native prayer illustration/icon raster assets into Expo.
- Add tests before production behavior changes and record TDD RED/GREEN evidence.

Out of scope:
- iOS Expo parity.
- Web parity.
- Native Swift app changes, except using it as the behavioral reference.
- Backend Convex schema/function changes.
- Auth/profile features from the Expo template.
- Remote push notification tokens; parity requires local scheduled prayer notifications only.

## References Used

- Existing repo map: `docs/CODEBASE_MAP.md`
- Native source of truth:
  - `Masjidly - Official Masjid Prayer Times/Features/Home/HomeViewModel.swift`
  - `Masjidly - Official Masjid Prayer Times/Features/Home/PrayerTimesEngine.swift`
  - `Masjidly - Official Masjid Prayer Times/Features/Home/TimetableView.swift`
  - `Masjidly - Official Masjid Prayer Times/Features/Settings/SettingsView.swift`
  - `Masjidly - Official Masjid Prayer Times/Features/Notifications/PrayerNotificationScheduler.swift`
- Expo Convex guide: https://docs.expo.dev/guides/using-convex/
- Convex JS without generated API: https://docs.convex.dev/client/javascript
- Expo notifications API: https://docs.expo.dev/versions/latest/sdk/notifications/
- Expo native tabs note: https://docs.expo.dev/versions/latest/sdk/router/native-tabs/

## Public Interfaces And Types

Add these Expo app modules.

### `apps/expo/types/prayer.ts`

Define Zod schemas and TypeScript types matching Swift models:

- `Mosque`
  - `id: string`
  - `name: string`
  - `address: string`
  - `lat: number`
  - `lng: number`
  - `slug: string`
  - `website?: string | null`
  - `isHidden?: boolean | null`
- `PrayerTime`
  - `date: number`
  - `fajr: string`
  - `shurooq: string`
  - `dhuhr: string`
  - `asr: string`
  - `maghrib: string`
  - `isha: string`
- `IqamahTimeRange`
  - `date_range: string`
  - `fajr: string`
  - `dhuhr: string`
  - `asr: string`
  - `maghrib?: string | null`
  - `isha: string`
  - `jummah?: string | null`
- `MonthPrayerData`
- `RamadanPrayerDay`
- `RamadanPrayerData`
- `DailyPrayerTimes`
- `DailyIqamahTimes`
- `UkDstYear`
- `UkDstCalendar`
- `NextPrayerCountdownResult`

Expose camelCase app types while decoding snake_case Convex payloads through Zod transforms.

### `apps/expo/lib/prayer/monthName.ts`

Expose:

- `MONTH_NAMES`
- `monthNameFromNumber(monthNumber: number): MonthName | null`

Values must match Swift `MonthName.rawValue`: lowercase English month names.

### `apps/expo/lib/prayer/mosqueDefaults.ts`

Expose:

- `DEFAULT_MOSQUE_SLUG = "muslim-welfare-house"`
- `visibleMosques(mosques: Mosque[]): Mosque[]`
- `resolveSelectedMosque(input): Mosque | null`

Selection precedence must match Swift:
1. visible mosque by persisted id
2. visible mosque by persisted slug
3. visible mosque with default slug
4. first visible mosque

### `apps/expo/lib/prayer/prayerTimesEngine.ts`

Port Swift `PrayerTimesEngine` behavior exactly.

Expose:
- `SHEFFIELD_TIME_ZONE = "Europe/London"`
- `getDateInSheffield(date: Date): { year; month; day }`
- `sheffieldNoonUtc(year, month, day): Date`
- `isoDateString(year, month, day): string`
- `normalizeMosqueSlug(slug): string`
- `isMasjidRisalah(slug): boolean`
- `mosqueTimetableAlreadyIncludesDst(slug): boolean`
- `findDayData(rows, dayOfMonth)`
- `findRamadanDayData(rows, ramadanDay)`
- `getIqamahTimesForDate(dayOfMonth, ranges)`
- `getIqamahTime(prayer, adhanTime, iqamahTimes, maghribAdhan?)`
- `resolveIshaIqamahForDisplay(input)`
- `resolvePrayerTimes(input)`
- `resolveIqamahTimes(input)`
- `resolveIqamahTimesWithDstMapping(input)`
- `getDisplayedPrayerTimes(input)`
- `getNextPrayerAndCountdown(input)`
- `formatTo12Hour(timeString): string`

Behavioral invariants:
- Use Sheffield/London civil date for all prayer-day resolution.
- Preserve Ramadan override behavior.
- Preserve Masjid Risalah special Isha/March iqamah handling.
- Preserve UK DST embedded-timetable mapping.
- Preserve `sunset`, `Entry Time`, `Various`, `adhan + N mins`, and `N minutes after adhan` handling.
- Friday Dhuhr becomes Jummah only for next-prayer/notification logic, while timetable still displays Jummah row every day like native.

### `apps/expo/lib/convex/client.ts`

Add `convex` dependency using the locked package manager.

Create:
- `convexClient = new ConvexReactClient(EXPO_PUBLIC_CONVEX_URL, { unsavedChangesWarning: false })`
- `MasjidlyConvexProvider`

Use `anyApi` from `convex/server` because the backend source/generated API is not in this repo.

Function references:
- `anyApi.mosques.list`
- `anyApi.prayerTimes.getMonthly`
- `anyApi.prayerTimes.getRamadan`
- `anyApi.prayerTimes.getUkDstDates`

### `apps/expo/lib/prayer/prayerRepository.ts`

Expose a typed repository over Convex:

- `listMosques(): Promise<Mosque[]>`
- `getMonthlyPrayerTimes(mosqueSlug: string, month: MonthName, year: number): Promise<MonthPrayerData | null>`
- `getRamadanTimetable(mosqueSlug: string, date?: string): Promise<RamadanPrayerData | null>`
- `getUkDstDates(): Promise<UkDstCalendar | null>`

Use Zod parsing at the boundary. For `getMonthlyPrayerTimes`, pass `year` as number, matching the backend validator expectation noted in Swift.

### `apps/expo/store/settings.ts`

Replace generic auth store with a Masjidly settings store using Zustand + AsyncStorage persistence.

State:
- `selectedMosqueId?: string`
- `selectedMosqueSlug?: string`
- `uses24HourTime: boolean`, default `false`
- `appLanguage: "system" | "english" | "arabic" | "urdu"`, default `system`
- `notifications`
  - `masterEnabled: boolean`, default `false`
  - `fajr: boolean`, default `true`
  - `dhuhrJummah: boolean`, default `true`
  - `asr: boolean`, default `true`
  - `maghrib: boolean`, default `true`
  - `isha: boolean`, default `true`

Add dependency:
- `@react-native-async-storage/async-storage`

### `apps/expo/lib/i18n`

Use a local static dictionary, not runtime network translation.

Files:
- `lib/i18n/translations.ts`
- `lib/i18n/language.ts`

Supported languages:
- English
- Arabic
- Urdu
- System fallback to English unless Android locale starts with `en`, `ar`, or `ur`

Add dependency:
- `expo-localization`

RTL:
- Arabic and Urdu must set layout direction expectations.
- Do not force app restart silently. If React Native requires restart for full RTL layout, show an in-settings note after language change.

### `apps/expo/lib/notifications/prayerNotifications.ts`

Replace the generic push-token hook with local prayer scheduling.

Expose:
- `requestNotificationAuthorizationIfNeeded(): Promise<boolean>`
- `cancelAllPrayerNotifications(): Promise<void>`
- `rescheduleUpcomingPrayerNotifications(input): Promise<void>`

Android requirements:
- Configure Android notification channel `prayer-times` with default importance.
- Schedule by absolute date trigger when possible; otherwise use calendar trigger supported by Expo notifications.
- Prefix all identifiers with `masjidly.prayer.`.
- Cancel only matching Masjidly prayer notification identifiers.
- Schedule next 7 days.
- Notification title is selected mosque name.
- Notification body matches localized native copy:
  - Fajr adhan / iqamah
  - Dhuhr adhan / iqamah
  - Jummah adhan / iqamah on Friday
  - Asr adhan / iqamah
  - Maghrib adhan / iqamah
  - Isha adhan / iqamah

## UI Plan

### Navigation

Remove the template Profile tab and generic modal.

Use Expo Router stack:
- `/` → Home
- `/settings` → Settings modal/screen
- `/timetable` → Timetable modal/screen

Do not use bottom tabs. Native iOS has a single primary app surface with settings and timetable opened from icon controls, so Android should follow that app model.

### Home Screen

Replace `apps/expo/app/(tabs)/index.tsx` with `apps/expo/app/index.tsx`.

UI content:
- Full-screen weather-inspired Masjidly layout.
- Top row:
  - calendar button opens timetable
  - centered Gregorian date and Hijri date
  - settings button opens settings
- Main content:
  - prayer-keyed raster illustration
  - selected prayer name
  - adhan time
  - optional localized `Iqamah: <time>` subtitle
  - horizontal prayer selector for Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- Initial selected prayer should be native parity:
  - if `nextCountdown.nextName` exists, select that prayer
  - Jummah maps to Dhuhr visual slot
- Loading state:
  - centered activity indicator
- Empty state:
  - message that no mosque data is available
  - retry button
- Error state:
  - keep last loaded data if available
  - show compact retry affordance

Design:
- Use tokens from `docs/DESIGN.md`.
- Copy assets:
  - native `FajrIllustration`, `DhuhrIllustration`, `AsrIllustration`, `MaghribIllustration`, `IshaIllustration` pngs into `apps/expo/assets/prayers/`
  - native prayer icons into `apps/expo/assets/icons/`
- Android icons:
  - existing `lucide-react-native` is acceptable because it is already installed.
  - Do not add a new icon dependency for this plan.

### Timetable Screen

Create `apps/expo/app/timetable.tsx`.

UI content:
- Gradient background based on current selected prayer theme.
- Header with selected date, mosque name, close button.
- Month switcher with previous/next month.
- Horizontal date strip for days in current month.
- Prayer rows:
  - Prayer
  - Adhan
  - Iqamah
  - Fajr
  - Sunrise with `-` iqamah
  - Dhuhr
  - Jummah row
  - Asr
  - Maghrib
  - Isha
- Highlight next row only when selected date is today.
- Month switcher fetches month data via repository.
- Time formatting obeys `uses24HourTime`.

### Settings Screen

Create `apps/expo/app/settings.tsx`.

UI sections:
- Mosque:
  - picker populated from `mosques:list`
  - excludes hidden mosques
  - changing mosque persists id + slug, refreshes home payload, and reschedules notifications if enabled
- Language:
  - System, English, Arabic, Urdu
- Display:
  - 24-hour time toggle
- Notifications:
  - master prayer notifications toggle
  - when master is on, show Fajr, Dhuhr/Jummah, Asr, Maghrib, Isha toggles
  - every notification setting change reschedules or cancels local notifications
- About section only if native iOS currently exposes about copy in the final UI review. If absent, omit.

## Data Flow

1. Root layout wraps app in:
   - `ErrorBoundary`
   - `SafeAreaProvider`
   - `MasjidlyConvexProvider`
2. Home mount:
   - read persisted settings
   - `listMosques`
   - resolve selected mosque through `resolveSelectedMosque`
   - persist resolved mosque id + slug
   - fetch current month, Ramadan timetable for today, and UK DST dates in parallel
   - resolve displayed prayer times, iqamah times, and next countdown
3. Settings mosque change:
   - update persisted mosque
   - home query state invalidates/refetches
   - notification scheduler reschedules if master enabled
4. Timetable month change:
   - fetch monthly data for selected mosque/month/year
   - reset selected day to today for current month, otherwise first day
5. Notification scheduling:
   - for each of next 7 Sheffield civil days, fetch month/Ramadan data, resolve prayer/iqamah data, then schedule enabled adhan/iqamah notifications.

## Dependency Changes

Add:
- `convex`
- `@react-native-async-storage/async-storage`
- `expo-localization`

Optional only if Android Intl cannot format Umm al-Qura Hijri dates reliably during verification:
- `@internationalized/date`

Do not add:
- auth packages
- remote push notification packages
- new icon packages
- UI kit dependencies

Use the existing `bun.lock` and frozen/locked install behavior. Do not run dependency update discovery commands.

## Implementation Phases

### Phase 1 — Remove Template Surface And Establish Domain Contracts

1. Add prayer Zod schemas/types.
2. Add month, mosque default, and settings types.
3. Add test fixtures mirroring existing Swift tests.
4. Write failing Jest tests for:
   - mosque decoding
   - monthly decoding
   - Ramadan decoding
   - hidden mosque filtering
   - default mosque resolution
5. Record RED evidence.
6. Implement the schemas/helpers.
7. Record GREEN evidence.

Acceptance:
- Generic auth/profile concepts are no longer part of the Masjidly runtime plan.
- Domain fixtures parse and match Swift model expectations.

### Phase 2 — Port PrayerTimesEngine

1. Write Jest tests equivalent to Swift `MasjidlyTests.swift`.
2. Add additional regression tests for:
   - `adhan + 5 mins`
   - `5 minutes after adhan`
   - Maghrib `sunset`
   - Isha `Entry Time`
   - Masjid Risalah May-July Isha display
   - March/October DST embedded timetable remap
   - Friday Jummah next-prayer behavior
   - 12-hour formatting
3. Record RED evidence.
4. Port engine functions to TypeScript.
5. Record GREEN evidence.

Acceptance:
- TypeScript engine returns the same outputs as Swift tests for the same fixtures.
- All date logic is pinned to `Europe/London`, not Android device timezone.

### Phase 3 — Convex Repository

1. Add Convex dependency and provider.
2. Add `.env.example` entries:
   - `EXPO_PUBLIC_CONVEX_URL=https://upbeat-goat-583.eu-west-1.convex.cloud`
3. Add repository using `anyApi` function references.
4. Add boundary tests mocking Convex calls:
   - correct query reference and args
   - `year` passed as number
   - Zod parse failure surfaces a useful repository error
5. Add integration smoke command documentation for a development build/device.

Acceptance:
- Repository exposes the same four operations as Swift `PrayerRepository`.
- No backend codegen is required in this repo.
- Invalid backend payloads fail at the boundary, not inside UI rendering.

### Phase 4 — App State And Home Screen

1. Add persisted settings store.
2. Add home data hook:
   - `useHomePrayerData`
   - returns `loadState`, `mosques`, `selectedMosque`, `displayedPrayerTimes`, `iqamahTimes`, `nextCountdown`, `refresh`
3. Replace template Home UI.
4. Add assets copied from native.
5. Add component tests for:
   - loading state
   - renders selected prayer time
   - 12-hour vs 24-hour formatting
   - prayer selector changes selected prayer
   - retry action calls refresh after error
6. Verify on Android emulator/development build.

Acceptance:
- First launch defaults to `muslim-welfare-house` when present.
- Home shows real Convex data when `EXPO_PUBLIC_CONVEX_URL` is configured.
- Home is usable on common Android phone sizes without overlapping text.

### Phase 5 — Timetable Screen

1. Add timetable route.
2. Add month switching and date strip.
3. Add prayer rows matching native behavior.
4. Add tests for:
   - today selected on current month
   - first day selected on non-current month
   - next/previous month args
   - Jummah row display
   - 12-hour formatting
5. Verify layout on Android emulator.

Acceptance:
- Timetable can browse previous/next months.
- Prayer rows display Adhan/Iqamah with native-equivalent rules.
- Close returns to Home without losing selected mosque.

### Phase 6 — Settings Screen

1. Add settings route.
2. Add mosque picker, language picker, 24-hour toggle, notification toggles.
3. Wire settings mutations to persisted store.
4. Wire mosque change to home refresh and notification reschedule.
5. Add tests for:
   - visible mosque list excludes hidden mosques
   - selecting mosque persists id + slug
   - time format toggle changes rendered Home/Timetable times
   - language selection changes translated labels
   - notification toggles call scheduler policy
6. Verify RTL rendering for Arabic and Urdu on Android.

Acceptance:
- Settings persist across app restart.
- Language applies to visible labels and notification body strings.
- Arabic and Urdu are readable and directionally coherent.

### Phase 7 — Android Local Notifications

1. Replace generic `useNotifications`.
2. Configure Android notification channel.
3. Implement cancellation by `masjidly.prayer.` prefix.
4. Implement 7-day scheduling parity.
5. Add tests with mocked `expo-notifications`:
   - master off cancels and schedules nothing
   - master on requests permission
   - each enabled prayer schedules adhan and iqamah
   - disabled prayer does not schedule
   - Friday schedules Jummah copy
   - past times are skipped
   - identifiers are stable and prefixed
6. Manual Android verification:
   - enable notifications
   - inspect scheduled notifications through mocked/logged dev path or Expo notifications APIs
   - schedule a near-future fixture notification in dev-only test mode if needed

Acceptance:
- Android app schedules local notifications without using Expo push tokens.
- Turning master off cancels Masjidly notifications only.
- Changing mosque/language/time settings reschedules.

### Phase 8 — Polish, Cleanup, And Documentation

1. Remove template-specific files if unused:
   - `store/auth.ts`
   - `types/user.ts`
   - profile screen
   - modal sample if no longer used
   - template README sections
2. Update `apps/expo/README.md` for Masjidly Android app setup:
   - install
   - env
   - Android dev build requirement
   - tests
   - lint
3. Update `docs/CODEBASE_MAP.md` for final Expo architecture.
4. Add or update `docs/GLOSSARY.md` with:
   - Mosque
   - Prayer time
   - Adhan
   - Iqamah
   - Jummah
   - Ramadan timetable
   - UK DST calendar
   - Selected mosque
5. Run final checks.

Acceptance:
- No visible template branding remains.
- Docs describe the actual Android Expo app.
- Future agents can find the domain and route structure quickly.

## Test Plan

Run during implementation:

- Policy validator:
  - `python3 ~/.agents/scripts/validate_agent_policy.py`
- TDD evidence:
  - `python3 ~/.agents/scripts/tdd_evidence.py record-red ...`
  - `python3 ~/.agents/scripts/tdd_evidence.py record-green ...`
- Expo unit/component tests:
  - `cd apps/expo && bun test`
- TypeScript:
  - `cd apps/expo && bunx tsc --noEmit` only if `tsc` is available through local dependencies; otherwise add a script using existing TypeScript.
- Lint:
  - `cd apps/expo && bun run lint`
- Expo export/build smoke:
  - `cd apps/expo && bun run build`
- Android manual verification:
  - Run in Android development build, not just Expo Go, for notification behavior.
  - Verify Home, Timetable, Settings, language, persistence, and notification scheduling.

Core Jest scenarios:
- Model decoding and schema transforms.
- Mosque defaulting/filtering.
- Prayer engine parity with Swift tests.
- DST transition mapping.
- Ramadan override.
- Friday Jummah behavior.
- 12/24-hour display.
- Settings persistence.
- Convex repository argument/reference behavior.
- Notification scheduling/cancellation.

## Assumptions And Defaults

- Expo parity target is Android only, per user clarification.
- Native SwiftUI app is the behavioral source of truth.
- Convex backend functions already exist and remain public:
  - `mosques:list`
  - `prayerTimes:getMonthly`
  - `prayerTimes:getRamadan`
  - `prayerTimes:getUkDstDates`
- Expo app should use live Convex directly, not a REST proxy.
- No authentication is required for this feature parity pass.
- Local notifications are enough; push notification tokens are removed from the feature path.
- Existing `lucide-react-native` may be used because it is already installed.
- Native raster assets can be copied into Expo assets.
- Android visual parity means same information architecture and design language, not pixel-perfect SwiftUI reproduction.
