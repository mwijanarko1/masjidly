---
workflow: product-launch-video
flow: automation
storyboard: no
message: "Prayer times from your own masjid, not a calculation that's minutes off"
destination: tiktok
aspect: 1080x1920
language: en
length: 30s
angle: problem-reveal-proof
---

## Intent

A dynamic 30-second motion graphics promo for Masjidly (iOS + Android). Show the
app, the different prayer screens, notifications, widgets, and mosque tabs, and
land the point that times match your local mosque's published timetable instead
of calculated times that are off from it. Mention how many mosques are live and
that the list keeps growing.

User wording: "make a dynamic 30-second motion graphics video for masjidly ...
how the times are accurate to your local mosque and not just calculated times
that are off from your local mosque. mention how many mosques we have and say
that we're going to keep increasing"

## Assets

- ../launch-video/assets/screenshots/home.png: real iOS home screen (Fajr, Masjid Faizul Islam), prayer screen beat.
- ../launch-video/assets/screenshots/timetable.png: real iOS daily timetable (adhan + iqamah), accuracy beat.
- ../launch-video/assets/app-icon.png: app icon for reveal and CTA.
- ../launch-video/assets/sfx/*.wav: whoosh / pop / impact SFX from the previous launch video.

## Customizations

- Audio: SFX plus a vocals-only nasheed sourced online. No musical instruments (user: "its an islamic app so no music").
- Count on screen: "340+ masjids" across "10 countries" (production `mosques:list`, 341 visible on 2026-09-27, including 48 city-wide official timetables), plus "more added every week" style line.
- Accuracy proof uses real data: Masjid Faizul Islam, 27 Sep 2026. Masjid timetable Fajr 5:26 / Asr 4:57 / Isha 8:16 (iqamah 6:20 / 5:45 / 8:30) vs Muslim World League calculation Fajr 5:06 / Asr 4:10 / Isha 8:43.
- Notification copy from the app: "Isha Iqamah soon" / "Iqamah in 10 min in Masjid Faizul Islam."

## Notes

- No voiceover. On-screen kinetic type carries the message.
- App look: blue (#1E3F8F) to purple (#8450A8) gradient, Gill Sans type, white text; Masjidly accent #47A6FF.
- Mosque tabs: capsule chips at the bottom of home, selected chip is white with dark text, plus button adds a tab.

## Revisions

- 2026-09-27 v2: user disliked v1 backgrounds and asked for inspiration from the opencode 2 launch video (x.com/kitlangton/status/2103884479710523586). User: "the background should match the app and the concept of prayer times". v2 is one continuous shot through a day of prayer skies (app Set 2 gradients), a typed caption rail, one persistent phone. See STORYBOARD.md.
- 2026-09-27 v3: user asked for typewriter sounds on typing, much more camera motion (like the opencode video), the timetable page with Midnight and Last Third, languages, customizable themes, a different nasheed, "App Store" and "Google Play" buttons instead of "Free on iPhone & Android", and no phone mockup: "make the whole video as if it's the app itself, so you can zoom in, zoom out of certain features". Length changed to ~40s (user choice). Nasheed: "Path to Jannah" by abdul2025 (Pixabay, tagged Vocal). See STORYBOARD.md.
- 2026-09-27 v4: user: "make sure the ui actually matches the app", show the home page's prayer display and that pressing F S D A M I changes the background colour ("don't mention just show"), and use normal clicking sounds instead of typewriter. Home screen rebuilt from the SwiftUI source at true scale (2.687x); skies follow the app defaults (Dhuhr and Tahajjud use Original); typing track now uses keyboard clicks (assets/sfx/keys; typewriter kept in assets/sfx/keys-typewriter).
- 2026-09-27 v6: user feedback: slides 2 and 4 were the same point (merged: the comparison card is gone, the hook now ticks 5:06 to 5:26 live); "prayer times, redesigned" instead of "tap any prayer"; captions readable for longer; language picker animation; add 4 masjid tabs; slower themes; small, large and lock screen widgets. Plus pasted review notes (no text-only cards, 3D camera, tactile SFX, live morphs, continuous day-to-night). User chose captions overlaid in the app's empty space and ~50s. Built at 55s.
- 2026-09-27 v7: user: the language selector went off screen, and the add masjid UI did not match the app. Language sheet shortened to fit (bottom at 1892px) with the app's blue check circle. Add masjid rebuilt from MosqueSelectionOnboardingView: "Pick your mosque", Country / City / Mosque rows, searchable Mosque dropdown (real Sheffield list), blue Continue capsule, sky-tinted backdrop, card springs out of the + button. Caption moved below the card (top 1680); SFX cues retimed.
