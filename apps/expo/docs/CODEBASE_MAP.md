# Codebase Map — Expo RN Template

> Auto-generated architecture reference. Update when adding major features or restructuring.

## Overview

A reusable React Native + Expo starter template on **Expo SDK 55** (React Native 0.83, React 19.2). Uses file-based routing (Expo Router), Zustand for global state, React Query for server state, and TypeScript throughout. New Architecture only.

---

## Project Structure

```
.
├── app/                        # Expo Router screens and layouts
│   ├── _layout.tsx             # Root layout: ErrorBoundary + SafeAreaProvider + Stack
│   ├── modal.tsx               # Modal screen example
│   └── (tabs)/
│       ├── _layout.tsx         # Native tabs layout (NativeTabs + ThemeProvider)
│       ├── index.tsx           # Home screen
│       └── profile.tsx         # Profile screen
│
├── components/                 # Reusable UI components
│   ├── ErrorBoundary.tsx       # React Error Boundary — wraps full app
│   └── ui/
│       └── Button.tsx          # Pressable button with variant support
│
├── lib/
│   └── hooks/
│       └── useNotifications.ts # Push token registration + local scheduling
│
├── store/
│   └── auth.ts                 # Zustand auth store (user, isAuthenticated, isLoading)
│
├── types/
│   └── user.ts                 # User Zod schema + TypeScript types + AuthState
│
├── constants/
│   └── index.ts                # COLORS, SPACING, FONT_SIZES, API_ENDPOINTS
│
├── __tests__/                  # Jest test suite
│   ├── components/
│   │   └── Button.test.tsx
│   ├── store/
│   │   └── auth.test.ts
│   └── types/
│       └── user.test.ts
│
├── ios/
│   └── PrivacyInfo.xcprivacy   # Apple privacy manifest
│
├── assets/                     # Icons, splash, fonts
├── docs/                       # Architecture docs
├── .env.example                # Template for required environment variables
├── app.json                    # Expo config
├── babel.config.js             # Babel config with module-resolver (@/ alias)
├── tsconfig.json               # TypeScript config with @/ path alias
├── jest.config.js              # Jest config (jest-expo preset)
└── package.json
```

---

## Key Architecture Decisions

### Routing
Expo Router drives all navigation. Screens live directly in `app/`. The `(tabs)` group uses **native tabs** (`NativeTabs` from `expo-router/unstable-native-tabs`) for the bottom tab bar on iOS and Android. Modals are registered in the root `_layout.tsx`.

### State Management
| Layer | Tool | Used For |
|-------|------|----------|
| Global | Zustand (`store/`) | Auth session, user data |
| Server | React Query (`@tanstack/react-query`) | API data fetching & caching |
| Local | `useState` / `useReducer` | Component-scoped UI state |

### Data Validation
All external data (API responses, auth payloads) is validated at the boundary using **Zod** schemas (`types/user.ts`). Never pass unvalidated data into the store.

### Path Aliases
`@/` maps to the project root. Use `@/components/...`, `@/store/...`, etc. throughout — never use `../../` relative paths.

### Error Handling
`components/ErrorBoundary.tsx` wraps the entire app via `app/_layout.tsx`. In development it shows the raw error message; in production it shows a generic recovery screen.

### Safe Areas
All screens wrap content in `SafeAreaView` from `react-native-safe-area-context`. The `SafeAreaProvider` is mounted once in the root layout.

### Testing
`jest-expo` preset with `@testing-library/react-native`. Tests live in `__tests__/` mirroring the source structure. Run with `bun test`.

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `EXPO_PUBLIC_API_BASE_URL` | Yes | Base URL for all API requests |

Copy `.env.example` to `.env` and fill in values. Variables prefixed `EXPO_PUBLIC_` are bundled into the client.

---

## Data Flow

```
User Action
    │
    ▼
Screen (app/)
    │  calls
    ▼
Custom Hook (lib/hooks/) or Zustand Store (store/)
    │  fetches/mutates via
    ▼
React Query / Zod-validated API call
    │  returns
    ▼
Validated Type (types/)
    │  stored in
    ▼
Zustand Store → re-renders subscribed screens
```

---

## Adding New Features

1. **New screen** → create `app/your-screen.tsx`
2. **New component** → create `components/ui/YourComponent.tsx`
3. **New store slice** → create `store/yourSlice.ts` using Zustand `create`
4. **New API type** → define Zod schema + `z.infer<>` type in `types/`
5. **New hook** → create `lib/hooks/useYourFeature.ts`
6. **New test** → create `__tests__/path/matching/source.test.tsx`
