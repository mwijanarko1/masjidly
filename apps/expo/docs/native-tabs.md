# Native Tabs Guide

This guide explains how to build `expo-router/unstable-native-tabs` so they feel as close as possible to a real Swift tab shell while still fitting the architecture of this Expo template.

It is not just an API reference. It covers:

- navigation architecture
- root shell responsibilities
- tab group design
- safe areas and content insets
- theming and translucency
- detail routes outside the tab bar
- hidden tab routes
- state restoration and tab re-selection
- lifecycle and bootstrap concerns
- realistic limits compared to a true Swift `TabView` or `UITabBarController`

Use this document as the standard for all tab-based apps built from this template.

---

## Goal

Native tabs in Expo Router can get very close to a Swift tab experience when you do three things well:

1. Keep the tab bar inside a dedicated route group, not at the absolute app root.
2. Put app bootstrap, providers, and detail stacks above the tab shell.
3. Design each tab screen like native content that understands safe areas, translucency, and restoration.

The biggest mistake is treating native tabs as only a UI choice. In practice they are a shell architecture choice.

---

## The Swift Mental Model

In a native Swift app, the tab shell usually looks like this:

- `App` entry decides whether to show onboarding, auth, or the main tab shell.
- `TabView` or `UITabBarController` owns the main sections of the app.
- Each tab may own its own navigation stack.
- Detail screens are often pushed inside a tab stack or presented modally above the tab shell.
- App lifecycle, theme, notifications, and state restoration are coordinated above the tabs.

To get close in Expo Router:

- `app/_layout.tsx` should act like the Swift app shell.
- `app/(tabs)/_layout.tsx` should act like the tab controller.
- each screen under `app/(tabs)/` should behave like a native root tab screen
- non-tab flows should live outside `/(tabs)` and be registered in the root `Stack`

That separation matters more than the tab icons.

---

## Recommended Architecture

Use this structure:

```text
app/
├── _layout.tsx
├── modal.tsx
├── settings/
│   └── notifications.tsx
├── post/
│   └── [id].tsx
└── (tabs)/
    ├── _layout.tsx
    ├── index.tsx
    ├── search.tsx
    ├── activity.tsx
    └── profile.tsx
```

Responsibilities:

- `app/_layout.tsx`
  - root providers
  - app bootstrap
  - auth or onboarding gate
  - root `Stack`
  - modal and non-tab route registration
- `app/(tabs)/_layout.tsx`
  - tab configuration only
  - tab theming
  - visible and hidden tab triggers
- `app/(tabs)/*.tsx`
  - actual tab screen content
  - safe-area ownership for the screen
  - scroll-to-top readiness
- routes outside `/(tabs)`
  - pushed detail screens
  - modal screens
  - flows that should not show the tab bar

This is the same broad pattern that scales best in the React Native apps we reviewed. It is also the closest Expo equivalent to a native app shell.

---

## Template Standard

This template already has the correct high-level split:

- root stack in `app/_layout.tsx`
- tab group in `app/(tabs)/_layout.tsx`
- screens inside `app/(tabs)/`

That is the baseline to keep.

Do not move `NativeTabs` into the absolute root unless the entire app is only tabs with no pushed flows, no auth gate, and no modal/detail routes. Even then, prefer the grouped layout because it stays extensible.

---

## Root Shell Responsibilities

`app/_layout.tsx` should behave like the native app container, not like a tab file.

It should own:

- `SafeAreaProvider`
- global `ErrorBoundary`
- theme providers
- query, auth, analytics, and state providers
- notification/bootstrap side effects
- root `Stack`

Recommended pattern:

```tsx
import { Stack } from 'expo-router';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { ErrorBoundary } from '@/components/ErrorBoundary';

export default function RootLayout() {
  return (
    <ErrorBoundary>
      <SafeAreaProvider>
        <StatusBar style="light" />
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="modal" options={{ presentation: 'modal' }} />
          <Stack.Screen name="post/[id]" />
        </Stack>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
}
```

Why this feels more native:

- the app shell is stable even when tab content changes
- pushed screens can appear outside the tab bar cleanly
- onboarding or auth can happen before entering the tab shell
- modal presentation stays separate from tab concerns

If you need auth, onboarding, or startup isolation, do it here or in a wrapper loaded from here. Do not scatter shell decisions across individual tab screens.

---

## Tab Group Responsibilities

`app/(tabs)/_layout.tsx` should be small, focused, and declarative.

It should own:

- tab order
- tab labels and icons
- visible vs hidden tab triggers
- tab bar appearance
- navigation theme values that affect the tab shell

It should not own:

- async bootstrapping
- data fetching for tabs
- notifications
- auth side effects beyond simple redirect or gate logic
- heavyweight business logic

Recommended pattern:

```tsx
import { ThemeProvider, DarkTheme, DefaultTheme } from '@react-navigation/native';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { DynamicColorIOS, Platform, useColorScheme } from 'react-native';

function iosTabLabelColor() {
  if (Platform.OS !== 'ios') return undefined;
  return DynamicColorIOS({ light: '#111827', dark: '#F9FAFB' });
}

function iosSelectedTint() {
  if (Platform.OS !== 'ios') return undefined;
  return DynamicColorIOS({ light: '#111827', dark: '#FFFFFF' });
}

export default function TabLayout() {
  const scheme = useColorScheme();
  const navigationTheme = scheme === 'dark' ? DarkTheme : DefaultTheme;

  return (
    <ThemeProvider value={navigationTheme}>
      <NativeTabs
        backgroundColor="transparent"
        tintColor={iosSelectedTint()}
        labelStyle={{
          color: iosTabLabelColor(),
          fontSize: 12,
        }}
      >
        <NativeTabs.Trigger name="index" contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Home</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'house', selected: 'house.fill' }} md="home" />
        </NativeTabs.Trigger>

        <NativeTabs.Trigger name="search" contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Search</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'magnifyingglass', selected: 'magnifyingglass' }} md="search" />
        </NativeTabs.Trigger>

        <NativeTabs.Trigger name="profile" contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Profile</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'person', selected: 'person.fill' }} md="person" />
        </NativeTabs.Trigger>

        <NativeTabs.Trigger name="activity" hidden contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Activity</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf="bell.fill" md="notifications" />
        </NativeTabs.Trigger>
      </NativeTabs>
    </ThemeProvider>
  );
}
```

Notes:

- `backgroundColor="transparent"` is the right default when you want iOS-style translucent glass behavior.
- `contentStyle={{ backgroundColor: 'transparent' }}` on each trigger lets content render naturally under the bar.
- hidden triggers are useful when a route belongs to the tab navigator but should not appear in the bar.

---

## Why Grouped Tabs Are Better Than Root Tabs

This is the single most important architecture rule.

Prefer:

```text
app/_layout.tsx -> Stack -> (tabs)
```

Avoid:

```text
app/_layout.tsx -> NativeTabs only
```

Grouped tabs are better because they let you:

- push detail screens outside the tab shell
- present modals without polluting tab configuration
- add auth and onboarding before tabs
- keep the tab bar hidden for flows that should feel standalone
- scale to more complex products without rewiring the whole navigation tree

This is exactly where many Expo apps drift away from native app structure. Native-feeling apps keep the tab shell as one section of the app, not the whole app.

---

## Safe Areas and Content Insets

If you want the iOS tab bar to feel native, your screen layout has to cooperate with it.

### Standard for tab screens

- use `SafeAreaView` from `react-native-safe-area-context`
- exclude the bottom edge when content should scroll behind the tab bar
- keep the screen root `collapsable={false}` if you want reliable active-tab re-tap behavior later
- prefer a `ScrollView`, `FlashList`, or `FlatList` that owns the scroll behavior for the whole screen

Recommended screen shell:

```tsx
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  return (
    <SafeAreaView
      style={styles.safeArea}
      edges={['top', 'left', 'right']}
      collapsable={false}
    >
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View>{/* content */}</View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  content: {
    padding: 16,
    paddingBottom: 120,
  },
});
```

Why `paddingBottom` matters:

- the tab bar may overlap the final content
- translucent bars look better when content continues underneath them
- extra bottom padding prevents the last card or CTA from being unreachable

### When to include bottom safe area

Include bottom safe area only when the design requires content to stop above the tab bar, for example:

- fixed forms
- screens with sticky bottom CTAs that should sit above the tab bar
- non-scrolling layouts

For most feed or dashboard tabs, do not include the bottom edge.

---

## Theming for a More Swift-Like Result

Swift tab bars feel polished because the surrounding surfaces, typography, system colors, and translucency all agree with each other.

To get closer in Expo:

- drive navigation theme from one source of truth
- use dynamic iOS colors where possible
- align screen background and tab content background
- avoid hardcoded color mismatches between root screens and the tab bar

Recommended rules:

- use `ThemeProvider` in the tab layout
- use the same theme source in the root shell and tab shell
- prefer `DynamicColorIOS` for label and selected tint on iOS
- avoid over-styling Android to imitate iOS too aggressively

If you build a theme object, it should include:

- tab bar background
- screen background
- selected icon color
- unselected icon color
- label color
- content background
- border/shadow color

This gives you one place to evolve the shell when the visual design changes.

---

## Tab Screen Design Rules

A Swift-like shell is not just the tab bar. Each tab screen needs to feel like a native root screen.

Use these rules:

- one main scroll container per tab
- safe-area ownership at the top level
- predictable header spacing
- no nested full-screen scroll containers unless necessary
- no fake bottom bars inside tab screens
- avoid using `TouchableOpacity`; prefer `Pressable`
- prefer `expo-image` for image-heavy lists
- use `FlashList` for large feeds

Good tab screens usually have:

- a simple root layout
- a stable background
- one source of scrolling
- content padding that anticipates the tab bar

Bad tab screens usually have:

- multiple vertical scrollers fighting each other
- content clipped by the tab bar
- extra fake padding hacks instead of correct safe-area rules
- inconsistent backgrounds that break translucency

---

## Detail Screens Should Usually Live Outside `/(tabs)`

If a screen is not a first-class app section, it probably should not be a visible tab.

Put these outside `/(tabs)`:

- item detail pages
- settings subsections
- notification detail
- compose/create flows
- onboarding
- auth
- checkout/paywall
- deep drill-down content

Example:

```tsx
// app/_layout.tsx
<Stack>
  <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
  <Stack.Screen name="post/[id]" options={{ headerShown: true }} />
  <Stack.Screen name="settings/notifications" options={{ headerShown: true }} />
</Stack>
```

Then push to them from a tab screen:

```tsx
import { router } from 'expo-router';

router.push('/post/42');
```

That is much closer to how native apps treat primary sections vs secondary flows.

---

## Hidden Tab Routes

Use hidden tab triggers when a route belongs to the tab navigator but should not be visible in the tab bar.

Common examples:

- a profile tab that is entered from avatar taps
- an activity route kept inside the tab shell for state continuity
- a debug or internal tab during development

Example:

```tsx
<NativeTabs.Trigger name="activity" hidden contentStyle={{ backgroundColor: 'transparent' }}>
  <NativeTabs.Trigger.Label>Activity</NativeTabs.Trigger.Label>
  <NativeTabs.Trigger.Icon sf="bell.fill" md="notifications" />
</NativeTabs.Trigger>
```

Use hidden tabs carefully.

Use them when:

- you need the route to share the tab shell
- you want tab-level state continuity
- the route behaves like a sibling of the main tabs

Do not use them when:

- the screen is really a detail route
- the user should think of it as pushed content
- the route has its own standalone flow

If in doubt, use a stack route outside `/(tabs)`.

---

## Auth and Onboarding

To feel native, auth and onboarding should be shell decisions, not random per-screen checks.

Recommended order:

1. root app decides if boot is safe
2. root shell loads providers
3. auth state resolves
4. onboarding completion resolves
5. user enters tab shell

Possible implementation styles:

- redirect from the root stack before entering `/(tabs)`
- render a wrapper above `NativeTabs` that shows onboarding/auth until ready
- lazy-load the “normal root” after a safe-mode or boot check

Avoid:

- checking auth independently in every tab screen
- duplicating onboarding guards per route
- mixing boot logic into tab icons or tab screen components

The closer the shell decision is to the root, the more native it feels.

---

## Bootstrap and Lifecycle

Native apps often feel more solid because lifecycle work is centralized.

Put these concerns above the tab screens:

- notification registration
- theme restoration
- persisted settings load
- analytics session setup
- audio mode
- auth refresh
- environment validation
- offline cache hydration

Good places:

- `app/_layout.tsx`
- a root wrapper imported from `app/_layout.tsx`
- a dedicated `AppBootstrap` component rendered above the `Stack`

Avoid doing this work in individual tab screens unless it is truly tab-specific.

---

## State Restoration

Swift tabs commonly restore selection and preserve section state. Expo can approximate this, but you need to be deliberate.

You can preserve or restore:

- selected tab
- scroll position per tab
- filters per tab
- in-memory screen state

Possible approaches:

- persist selected tab in Zustand or storage
- restore initial route into `/(tabs)` when boot completes
- keep state local to each tab screen when the navigator keeps screens mounted
- use screen-focused effects instead of mount-only effects when data should refresh on return

Important caveat:

Expo native tabs do not give you full parity with a handcrafted Swift coordinator. You can get close, but not identical behavior across every lifecycle edge case.

---

## Tab Re-selection and Scroll-to-Top

This is one of the biggest “native feel” details.

In a native iOS app, tapping the already-selected tab often scrolls the current list to top or resets the section.

Expo support here is improving, but you should design for it explicitly:

- keep the screen root non-collapsable
- keep one primary scroll container
- centralize any future re-selection handling rather than tying it to random child components

Recommended prep:

```tsx
<SafeAreaView
  collapsable={false}
  edges={['top', 'left', 'right']}
  style={styles.safeArea}
>
  <ScrollView ref={scrollRef}>{/* content */}</ScrollView>
</SafeAreaView>
```

If you later add an active-tab re-tap bridge or event, the screen is already structured correctly to respond.

This is one place where true Swift still has an advantage because you can directly coordinate with `UITabBarController`.

---

## Performance Guidance

Native-feeling tabs also need to feel fast.

For tab performance:

- avoid expensive work in the tab layout component
- do not create large inline objects repeatedly
- keep triggers static where possible
- use `FlashList` for large tab content
- memoize expensive tab row items when rendering lists
- keep tab screens focused on presentation and delegate data orchestration to hooks or stores

Especially avoid:

- heavy async work on first render of every tab
- giant hero images that re-layout the screen repeatedly
- multiple nested providers inside each tab screen
- long synchronous calculations in render

---

## Accessibility

Swift-like quality includes accessibility quality.

Make sure:

- tab labels are short and unambiguous
- icons support the meaning but do not replace the text
- screen titles and headings are clear
- interactive elements inside tabs use `Pressable` and proper accessibility roles
- bottom CTA content is not blocked by the tab bar

If a tab is hidden, do not rely on the user discovering it from the tab bar. It must be reachable from another accessible path.

---

## Platform-Specific Advice

### iOS

- lean into translucent tab bars
- use SF Symbols for best native feel
- use dynamic colors for selected tint and label styles
- let content scroll behind the tab bar when it improves depth

### Android

- support Material icon names in every trigger
- do not force iOS visual tricks that look wrong on Android
- prioritize clear surfaces and consistent spacing over “glass” imitation

The goal is native feel on both platforms, not identical visuals.

---

## What Expo Can and Cannot Match

### Expo native tabs can match well

- native bottom tab bar rendering
- platform icons
- primary-section app structure
- hidden vs visible tab routes
- a root stack above tabs
- theme-driven tab appearance
- modals and push flows outside the tab shell

### Expo native tabs cannot fully match

- total control of `UITabBarController` behavior
- first-class coordinator patterns identical to Swift
- every tab re-selection edge case
- UIKit-level customization hooks
- deep OS-level state restoration parity

The right mindset is:

- use Expo native tabs for native shell behavior
- use good architecture to close the remaining gap
- do not chase fake parity with brittle hacks

---

## Recommended Standard for This Template

When building tabs in this repository:

1. Keep `app/_layout.tsx` as the root shell with providers, bootstrap, and a `Stack`.
2. Keep `NativeTabs` in `app/(tabs)/_layout.tsx`.
3. Put detail routes outside `/(tabs)`.
4. Use `backgroundColor="transparent"` on `NativeTabs` unless the design needs an opaque bar.
5. Use `contentStyle={{ backgroundColor: 'transparent' }}` on every trigger when content should extend beneath the tab bar.
6. Use `SafeAreaView` with `edges={['top', 'left', 'right']}` for scrolling tab screens.
7. Add extra bottom padding to the scroll content so the last item clears the tab bar.
8. Keep the screen root `collapsable={false}` to preserve future re-selection support.
9. Centralize theme values used by both screen backgrounds and the tab shell.
10. Keep auth, onboarding, notifications, and other startup concerns above the tab group.

---

## Suggested Upgrade for the Current Template

The current template uses the correct route split, but it can get closer to a native Swift-style shell with a few improvements:

- make tab bar translucency explicit by setting `backgroundColor="transparent"`
- add `contentStyle={{ backgroundColor: 'transparent' }}` on each trigger
- align the root status bar and navigation theme with the tab shell
- update tab screens to exclude the bottom safe area when the design should scroll behind the bar
- add bottom content padding in scrolling tabs
- introduce a small centralized theme object for tab-shell colors
- keep future auth/onboarding/bootstrap work above the `Stack`, not inside tab screens

---

## Example: Full Template-Style Setup

### `app/_layout.tsx`

```tsx
import { Stack } from 'expo-router';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { ErrorBoundary } from '@/components/ErrorBoundary';

export default function RootLayout() {
  return (
    <ErrorBoundary>
      <SafeAreaProvider>
        <StatusBar style="light" />
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="modal" options={{ presentation: 'modal' }} />
          <Stack.Screen name="post/[id]" options={{ headerShown: true }} />
        </Stack>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
}
```

### `app/(tabs)/_layout.tsx`

```tsx
import { ThemeProvider, DarkTheme, DefaultTheme } from '@react-navigation/native';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { DynamicColorIOS, Platform, useColorScheme } from 'react-native';

export default function TabLayout() {
  const scheme = useColorScheme();

  return (
    <ThemeProvider value={scheme === 'dark' ? DarkTheme : DefaultTheme}>
      <NativeTabs
        backgroundColor="transparent"
        tintColor={
          Platform.OS === 'ios'
            ? DynamicColorIOS({ light: '#111827', dark: '#FFFFFF' })
            : undefined
        }
        labelStyle={{
          color:
            Platform.OS === 'ios'
              ? DynamicColorIOS({ light: '#111827', dark: '#F9FAFB' })
              : undefined,
          fontSize: 12,
        }}
      >
        <NativeTabs.Trigger name="index" contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Home</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'house', selected: 'house.fill' }} md="home" />
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="profile" contentStyle={{ backgroundColor: 'transparent' }}>
          <NativeTabs.Trigger.Label>Profile</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'person', selected: 'person.fill' }} md="person" />
        </NativeTabs.Trigger>
      </NativeTabs>
    </ThemeProvider>
  );
}
```

### `app/(tabs)/index.tsx`

```tsx
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  return (
    <SafeAreaView
      style={styles.safeArea}
      edges={['top', 'left', 'right']}
      collapsable={false}
    >
      <ScrollView contentContainerStyle={styles.content}>
        <View>
          <Text>Home</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  content: {
    padding: 16,
    paddingBottom: 120,
  },
});
```

---

## Review Checklist

Before shipping native tabs, verify:

- [ ] `NativeTabs` lives in `app/(tabs)/_layout.tsx`, not the absolute root
- [ ] `app/_layout.tsx` owns the root `Stack`
- [ ] detail and modal routes live outside `/(tabs)`
- [ ] tab triggers are explicit and stable
- [ ] hidden tabs are only used when truly justified
- [ ] tab shell theming is centralized
- [ ] tab screens own safe areas correctly
- [ ] scrolling tab screens exclude the bottom safe area when appropriate
- [ ] tab content has enough bottom padding to clear the bar
- [ ] startup/bootstrap logic is above the tabs
- [ ] auth/onboarding decisions are shell-level decisions
- [ ] large tab lists use performant list primitives
- [ ] the design still feels right on Android, not just iOS

---

## Final Recommendation

If you want Expo native tabs to feel as close as possible to Swift tabs, focus less on cosmetic tweaks and more on shell architecture.

The winning formula is:

- root stack above tabs
- dedicated tab route group
- native-safe screen layouts
- centralized theme and bootstrap
- detail flows outside the tab bar
- deliberate preparation for restoration and re-selection

That is the closest practical match to a real native tab app while staying clean, scalable, and idiomatic in React Native + Expo.
