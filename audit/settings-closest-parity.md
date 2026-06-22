# Settings + Closest Mosque Parity Audit

**Files inspected:**

| Platform | Path | Size |
|----------|------|------|
| Expo | `apps/expo/app/settings.tsx` | 1472 lines |
| iOS | `Features/Settings/SettingsView.swift` | 1325 lines |
| iOS | `Features/Settings/SettingsViewModel.swift` | 225 lines |
| Expo | `components/ui/SettingsMenuPickerRow.tsx` | 195 lines |

## Settings row/button inventory

Both platforms ship identical visible sections in the same order:

| Section | Expo | iOS | Parity |
|---------|------|-----|--------|
| Title header + close (X) button | ✅ | ✅ | 1:1 |
| Country picker | ✅ | ✅ | 1:1 |
| City picker | ✅ | ✅ | 1:1 |
| Mosque picker | ✅ | ✅ | 1:1 |
| **Closest mosque row** | ✅ | ✅ | **see below** |
| 24h toggle | ✅ | ✅ | 1:1 |
| Asr adhan preference | ✅ | ✅ | 1:1 (conditional) |
| Language picker | ✅ | ✅ | 1:1 |
| Theme mode (dynamic/fixed) | ✅ | ✅ | 1:1 |
| Fixed theme picker | ✅ | ✅ | 1:1 (conditional) |
| Qibla compass toggle | ✅ | ✅ | 1:1 |
| **Location recovery card** | ✅ | ✅ | **see below** |
| Notification master toggle | ✅ | ✅ | 1:1 |
| Adhan per-prayer toggles (expandable) | ✅ | ✅ | 1:1 |
| Iqamah per-prayer toggles (expandable) | ✅ | ✅ | 1:1 |
| Pre-adhan reminder picker | ✅ | ✅ | 1:1 |
| Pre-iqamah reminder picker | ✅ | ✅ | 1:1 |
| 3 contact cards | ✅ | ✅ | 1:1 |
| Dev section (`__DEV__` / `#if DEBUG`) | 7 buttons | 8 buttons | **see below** |

## Closest mosque deep findings

Both platforms share the same algorithm (Haversine on all mosques, min distance), but **location lifecycle differs**:

| Aspect | Expo | iOS |
|--------|------|-----|
| Trigger | `useEffect` on `[hideQiblaCompass]` only (`settings.tsx:264-287`) | `.onAppear` + `.onReceive(willEnterForeground)` + `.onChange(of: hideQiblaCompass)` (`SettingsView.swift:286-310`) |
| Provider | `expo-location` `getCurrentPositionAsync(.Balanced)` | `SettingsClosestMosqueLocationProvider` (`CLLocationManager`, 100m accuracy, 250m filter) |
| Guard | `hideQiblaCompass` OR no coords OR no mosques | `hideQiblaCompass` OR `.denied/.restricted` OR no location (`SettingsView.swift:544-548`) |
| Re-fetch on foreground | **None** | ✅ `.onReceive(willEnterForegroundNotification)` |
| Re-fetch on auth change | **None** | ✅ `locationManagerDidChangeAuthorization` delegate |

## Parity gaps ranked

### HIGH

**1. Location recovery ignores `.restricted` status on Expo**
- `settings.tsx:295` checks only `DENIED` → `Location.PermissionStatus.DENIED`
- `SettingsView.swift:38-39` checks `denied || restricted`
- **Impact**: Users with location restricted via MDM/parental controls never see the recovery card on Expo

**2. Closest mosque never re-fetches on foreground in Expo**
- Expo: one-shot `useEffect` on mount. No `AppState`/`willEnterForeground` listener.
- iOS: `SettingsView.swift:294-296` re-fetches location every foreground + `.onChange(of: hideQiblaCompass)` + delegate callback on auth change
- **Impact**: If user opens app in a different city, closest mosque is stale until they toggle qibla or navigate away/back

### MEDIUM

**3. Missing "Test Review Prompt" dev button on Expo**
- iOS: 8 dev buttons incl. `settings.development.test_review_prompt` (`SettingsView.swift:263-266` via `AppReviewPromptCoordinator`)
- Expo: 7 dev buttons, no review prompt test (`settings.tsx:1093-1179`)
- **Impact**: QA can't test the review prompt flow on Expo without a production build

**4. Notification test fires 1s delayed on Expo vs instant on iOS**
- iOS: `SettingsViewModel.swift` uses `trigger: nil` (immediate delivery)
- Expo: `settings.tsx` uses `{ type: TIME_INTERVAL, seconds: 1 }` (1-second delay)
- **Impact**: Test notifications arrive staggered on Expo instead of simultaneously — trivial but can confuse rapid testing

### LOW

**5. Mosque picker UI paradigm differs**
- iOS: Native `Menu` with inline checkmark (`SettingsView.swift:802-835`)
- Expo: `SettingsMenuPickerRow` → full-screen modal bottom sheet with "Done" button (`SettingsMenuPickerRow.tsx`)
- Parity in function, not in feel. QA should verify both pass acceptance criteria.

**6. Asr adhan labels hardcoded on Expo**
- Expo: labels are plain strings `"First Asr (Mithl 1)"` / `"Second Asr (Mithl 2)"` (`settings.tsx`)
- iOS: same hardcoded strings in `asrIqamahPickerRow` (`SettingsView.swift`)
- No gap — both use untranslated English. Flag if localization is needed later.

## Recommended smallest fixes

1. **Expo: add `.restricted` to location recovery check** — one-line change in `settings.tsx:295`
2. **Expo: add `AppState` listener** to re-fetch location on foreground for closest mosque — ~10 lines in `settings.tsx`
3. **Expo: add "Test Review Prompt" dev button** — one new button in `__DEV__` block
4. **Expo: use `trigger: null` for test notifications** — or keep 1s delay if iOS uses 1s too (verify)

## Needs parent

No. Both settings screens are fully implementable and fixable by a mobile engineer. No backend contract changes needed.
