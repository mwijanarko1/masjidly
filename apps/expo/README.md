# Masjidly — Android Expo App

Official mosque prayer times for Android, built with Expo React Native. Shares the same Convex backend as the native iOS Masjidly app.

## Setup

```bash
bun install
```

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

The default `EXPO_PUBLIC_CONVEX_URL` points to the dev deployment. Update for release builds.

## Development

Start the Expo development server:

```bash
bun start
```

For notification testing, use an Android development build (Expo Go does not fully support local notification channels):

```bash
bun run android
```

## Tests

```bash
bun run test
```

## Lint

```bash
bun run lint
```

## Build

```bash
bun run build
```

## Project Structure

```
app/                    # Expo Router screens
  _layout.tsx           # Root layout with Convex provider
  index.tsx             # Home screen
  timetable.tsx         # Timetable modal
  settings.tsx          # Settings modal
components/             # Reusable UI components
  ui/                   # PrayerCarousel, PrayerRow, SettingsToggleRow
  ErrorBoundary.tsx
lib/                    # Domain and data layer
  convex/client.tsx     # Convex client + provider
  prayer/               # Prayer engine, repository, defaults, month names
  i18n/                 # Translations and language resolution
  notifications/        # Local prayer notification scheduler
  hooks/                # useHomePrayerData, usePrayerNotifications
store/                  # Zustand stores
  settings.ts           # Persisted settings
 types/                 # Zod schemas + TypeScript types
  prayer.ts
constants/              # Design tokens
assets/                 # Images, icons
  prayers/              # Prayer illustration PNGs
```

## Key Dependencies

- **Expo SDK 55** — React Native 0.84, React 19.2
- **Convex** — Backend data via `anyApi` function references
- **Zustand + persist** — Settings with AsyncStorage
- **expo-notifications** — Local Android prayer notifications
- **expo-localization** — System locale detection
- **Zod** — Runtime schema validation at Convex boundaries

## Architecture

- **Domain layer** (`lib/prayer/`): `PrayerTimesEngine` ported from Swift with exact behavioral parity for DST, Ramadan, iqamah parsing, and next-prayer calculation.
- **Data layer** (`lib/convex/`, `lib/prayer/prayerRepository.ts`): Typed repository over Convex public queries. No backend codegen required.
- **Settings** (`store/settings.ts`): Persisted in AsyncStorage. Mosque selection, 24h time format, language, and notification toggles.
- **Notifications** (`lib/notifications/prayerNotifications.ts`): Schedules next 7 days of adhan/iqamah local notifications. Configures Android notification channel.
- **i18n** (`lib/i18n/`): Static dictionaries for English, Arabic, Urdu. System fallback to English.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `EXPO_PUBLIC_CONVEX_URL` | Convex deployment URL (dev or prod) |

## License

MIT
