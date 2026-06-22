# Onboarding & Cross-Cutting Parity Audit — Expo ↔ iOS

**Skills loaded:** ios-development, ios-app-store-compliance, vercel-react-native-skills, expo-docs, coding-standards, testing-strategies

**Inspected:** Expo `app/_layout.tsx`, `index.tsx`, `settings.tsx`, `components/onboarding/TutorialOverlay.tsx`, `CoachMarkCard.tsx`, `MosqueSelectionCard.tsx`, `NotificationSetupCard.tsx`, `components/updates/UpdatePromptModal.tsx`, `WhatsNewModal.tsx`, `components/ui/AdhanMiniPlayerBar.tsx`, `components/notifications/NotificationRecoveryModal.tsx`, `lib/updates/updateChecker.ts`, `whatsNew.ts`, `store/onboarding.ts`. iOS `App/MasjidlyRootView.swift`, `Masjidly___Official_Masjid_Prayer_TimesApp.swift`, `Features/Home/HomeView.swift`, `Features/Settings/SettingsView.swift`, `Features/Settings/SettingsViewModel.swift`, `Features/Onboarding/` (all 6 files), `Features/Audio/AdhanMiniPlayerBar.swift`, `Features/Updates/` (3 files), `Features/Notifications/PrayerNotificationContent.swift`.

## Matched Flows (✅ Full Parity)

- **Onboarding steps:** chooseLanguage, chooseMosque, prayerShortcut, qiblaCountdown, qibla, openTimetable, openSettings, notifications — all render correctly on both sides.
- **Notification categories/actions:** IDs, per-category action sets (adhan: viewTimes+snoozeReminder, iqamah: viewMosque+openTimetable, reminder: openTimetable+dismiss), snooze interval (10min) — all identical.
- **AdhanMiniPlayerBar:** progress track, play/pause, dismiss, remaining time label — functional match.
- **Update check:** same `latest.json` URL, same version comparison logic, test button on both sides.
- **Dev test buttons:** test adhan/iqamah/reminder/all, test update prompt, test what's new, reset tutorial — all present on both.
- **Skip tutorial:** positioned at bottom during prayerShortcut step, routes to notifications step — both match.

## Parity Gaps (Ranked)

**HIGH — iOS missing coach marks for exploreTimetable, closeTimetable, exploreSettings, closeSettings**
- `HomeView.swift:587-676` returns `EmptyView()` for these 4 steps
- `TutorialOverlay.tsx:242-310` shows proper coach marks on Expo
- Impact: iOS users navigating to timetable/settings during onboarding get zero visual guidance. The step still advances but the overlay is blank.
- Fix: Add `OnboardingCoachMarkView` for each step matching Expo layout (~20 lines each).

**MEDIUM — iOS What's New content has 1 item vs Expo's 5**
- `WhatsNew.swift:32-69` only shows "Bug Fixes" item
- `whatsNew.ts:103-127` shows 5 items (country picker, language, Asr preference, multi-Jummah, closest mosque)
- Impact: iOS users miss feature announcements.
- Fix: Sync `WhatsNew.swift` items array to match Expo.

**MEDIUM — iOS missing notification recovery modal on launch**
- `app/index.tsx:211-222` checks permission + shows `NotificationRecoveryModal`
- iOS `HomeView.swift` has no equivalent check or modal
- Impact: iOS users with denied/faulty permissions get no in-app fix prompt.
- Fix: Add permission check + recovery modal to iOS HomeView (~60 lines).

**LOW — Expo mini player title "Adhan" not localized**
- `AdhanMiniPlayerBar.tsx:99` has hardcoded `<Text>Adhan</Text>`
- iOS uses `localized("notification.channel.adhan")`
- Fix: Use `t("notification.channel.adhan", languageCode)`.

**LOW — Expo missing "Test Review Prompt" dev button**
- iOS `SettingsView.swift:259` has test button, Expo `settings.tsx` dev section lacks it.
- Fix: Add 5-line button.

**LOW — Expo missing "go to last available date" fallback for missing times**
- iOS `HomeView.swift:234-246` has `model.goToLastAvailablePrayerDate()` button
- Expo `app/index.tsx:260-277` only shows email + retry
- Fix: Add fallback button (~10 lines).

## Needs Parent: No. All fixes are mobile-only.
