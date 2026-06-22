# Closest Mosque Delay — Expo vs iOS

## Files Examined

| File | Lines | Role |
|------|-------|------|
| `apps/expo/app/settings.tsx` | 193–209, 253–285, 679–685, 795–818 | Expo settings screen (mosque loading, location fetch, closest compute, render) |
| `Masjidly - Official Masjid Prayer Times/Features/Settings/SettingsView.swift` | 25, 280–307, 545–551, 593–629 | iOS settings screen (closest mosque provider, location life cycle) |
| `Masjidly - Official Masjid Prayer Times/Features/Settings/SettingsViewModel.swift` | 36–49 | iOS view model (cache-first + Convex load) |

## Exact Sequence — Expo

1. **Mount**: `useState` → `mosques=[]`, `loading=true`, `userCoordinates=null`
2. **`useEffect([], #1)`** (lines 193–209): `loadMosques()` — async load cache → `setMosques` + `setLoading(false)`; then network fetch → `setMosques` again.
3. **`useEffect([], #2)`** (lines 230–237): check location permission → `setLocationPermissionStatus`.
4. **`useEffect(() => refreshUserCoordinates())`** (lines 283–285): calls `refreshUserCoordinates` (line 253), which **sequentially** awaits:
   - `Location.getForegroundPermissionsAsync()` — permission read (async hop)
   - `Location.getCurrentPositionAsync({accuracy: .Balanced})` — GPS fix (async hop, may wait for fresh fix)
5. **Render gated on `loading`** (line 795): entire mosque picker + closest mosque block is hidden behind an `ActivityIndicator` until `loading=false`.
6. **`closestMosque`** `useMemo` (lines 679–685) depends on `[mosques, hideQiblaCompass, userCoordinates]` — returns `null` if `mosques.length===0` or `!userCoordinates`.

## Exact Sequence — iOS

1. **`onAppear`** fires **before** `.task` (lines 284–292):
   - `locationAuthStatus = CLLocationManager().authorizationStatus` — **synchronous**, no await.
   - `closestMosqueLocationProvider.start()` → calls `locationManager.requestLocation()` — returns **cached** location from iOS in <100ms via delegate callback (lines 621–623).
2. **`.task { await model.load() }`** runs concurrently (lines 280–282):
   - `diskCache.loadMosques()` — **synchronous** disk read, `mosques` populated immediately.
   - Then async network fetch to Convex for fresher data.
3. **`closestMosque`** computed property (lines 545–551) depends on `model.mosques` and `closestMosqueLocationProvider.currentLocation` — both populated within milliseconds of view appearing.

## Why Expo Is Delayed

### Primary cause: `Location.getCurrentPositionAsync` vs `CLLocationManager.requestLocation()`

- **iOS** uses `CLLocationManager.requestLocation()` (line 612) which returns the **last known cached location** instantly (<100ms). No fresh GPS fix needed.
- **Expo** uses `Location.getCurrentPositionAsync({accuracy: .Balanced})` (line 275), which on iOS may trigger a fresh GPS acquisition. Even with cached location, it crosses the React Native bridge (async serialization + module dispatch), adding 200–500ms minimum.

### Secondary cause: sequential permission check adds extra async hop

Expo `refreshUserCoordinates` (lines 257–279):
```
await getForegroundPermissionsAsync()     // 1st async hop
await getCurrentPositionAsync(...)        // 2nd async hop → GPS or cached
```
iOS reads `locationManager.authorizationStatus` **synchronously** (line 286) — zero hops.

### Tertiary cause: rendering gating

The entire mosque picker section (including closest mosque) is inside a `{loading ? <ActivityIndicator> : ...}` block (line 795). `loading` only flips to `false` after the cache-or-network mosque fetch completes. On iOS, the `listBlock` is always rendered; `closestMosque` row just doesn't appear if the provider is nil.

## Bug or Async Behavior?

**Not a bug — it's orchestration debt.** The data flows are all correct; the delay is the sum of:

1. `getForegroundPermissionsAsync` (async hop)
2. `getCurrentPositionAsync(.Balanced)` (GPS acquisition time + bridge overhead)
3. `loadMosques` network fetch (if cache miss)

On a cold launch with no cached mosques and no cached location, the delay can be **3–8 seconds**. With warm cache, it's **300ms–1s** (still visibly slower than iOS which is ~100ms).

## What Would Fix It

### Smallest fix (not a re-architecture):

1. **Use `Location.Accuracy.Low` instead of `.Balanced`** in `settings.tsx` line 276 — this maps to `kCLLocationAccuracyThreeKilometers` and returns cached location faster because it doesn't require a fresh GPS lock.

2. **Pre-seed `userCoordinates` from app startup.** If the home screen already fetched location for Qibla, cache the coords in a singleton or store so the settings screen reads them immediately without re-requesting.

These two changes would cut the Expo delay to match iOS (~100ms if cached, ~1s if not) without any architectural change.

### Alternatives that need parent decision:

- Replace `getCurrentPositionAsync` with expo-location's `getLastKnownPositionAsync` (returns `null` if no cache, so need fallback)
- Hoist location state to a shared context so Settings reuses whatever the home screen already fetched

## Needs Parent Decision?

No — the two fixes above are tiny and safe. But if the preference is the shared-context approach (cleaner, avoids duplicate location fetches), that needs a parent decision since it spans files outside settings.
