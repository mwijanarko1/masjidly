# Prayer Focus onboarding

## Goals
- Existing users: after dismissing What’s New for this update, show Prayer Focus setup once.
- New users: after notifications in the tutorial, show the same setup.
- Tutorial chrome/UI language; skippable.

## Flow
1. **Intro** — Turn on / Skip  
2. **Apps** (if turned on) — Screen Time + choose apps; stay until authorized + ≥1 app, or Skip  
3. **Schedule** — start, duration, prayers → Finish  

## Persistence
`SettingsStore.hasCompletedPrayerFocusOnboarding` — set on skip or successful finish.  
Skip showing if already enabled with authorization and ≥1 app (auto-mark complete).
