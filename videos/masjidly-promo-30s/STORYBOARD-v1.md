---
format: 1080x1920
duration: 30s
message: "Prayer times from your own masjid, not a calculation that's minutes off"
arc: Hook (conflict) → Proof of drift → Reveal → Features (screens, tabs, notifications, widgets) → Scale (340+) → CTA
audience: Muslims who pray at a local masjid, on TikTok / Reels / Shorts
mode: autonomous
music: nasheed (vocals only, no instruments)
---

## Video direction

- **Palette** (frame.md): night-sky canvas #0B1233 under the app's own blue #1E3F8F to purple #8450A8 gradient; white ink; muted #C9D2F2 for labels; accent #47A6FF for the one thing that matters per frame (the masjid's time, the count, the CTA). Negative #FF6B6B only for the struck-through calculated time. Tinted glass cards (white 10% fill, 22% border), pill chrome, no hard shadows except the phone body.
- **Type**: Gill Sans everywhere (the app's own voice). Light for giant numerals (matches the app's big time), SemiBold for headlines, Bold for chips.
- **Motion grammar**: long-tail power3/expo eases, springy only on pops (chips, badges, tabs). Every frame reveals on the beat across its duration; no front-loading. One continuous slow drift on the sky gradient runs underneath the whole video for cohesion. Hard punchy cuts on the nasheed phrasing; SFX whoosh on each frame change, pops on chip reveals, one impact on the "4:57" slam and on "340+".
- **Rhythm**: Frames 1 to 2 fast and argumentative; Frame 3 is the breather reveal; Frames 4 to 7 are the energetic feature run; Frame 8 is the climax number; Frame 9 holds still on the lockup.
- **Layout**: 9:16. Headline in the upper third (y 0.12 to 0.28), hero object (phone / number / cards) in the middle, nothing below y 0.83 (TikTok UI band).
- **Negative list**: no instruments in audio, no stock mosque photos, no invented numbers (all times are real Convex data for 27 Sep 2026; count is the real production total), no generic AI purple bokeh, no slideshow freeze, no screensaver floating.

## Frame 1: Hook: two answers for Asr

- scene: "ASR" label; a calculated 4:10 PM gets struck out as the masjid's 4:57 PM slams in
- duration: 3.2s
- transition_in: cut
- status: animated
- src: compositions/frames/01-hook.html
- blueprint: kinetic-type-beats (Adapt)
- focal: the two times
- sfx: whoosh-1 at 0.0, impact at 1.55
- voiceover: ""

Adapt: keep the in-place token swap; the swapped token is the time.
Scene 1 (0.0-0.5s): sky ground; small caps eyebrow "ASR · TODAY" drops in at upper third.
Scene 2 (0.4-1.4s): giant light numeral "4:10 PM" rises in, center; a pill tag above it "Calculated time" in muted ink.
Scene 3 (1.4-2.2s): a red strike line draws through 4:10, it dims and shrinks up; "4:57 PM" slams in below it in accent blue with a scale overshoot; tag "Your masjid" pops.
Scene 4 (2.2-3.2s): line "47 minutes apart." types in under it; hold.

## Frame 2: Calculated times drift

- scene: three-row comparison card, Calculated vs Masjid Faizul Islam, with minute-gap chips popping
- duration: 3.6s
- transition_in: cut
- status: animated
- src: compositions/frames/02-drift.html
- blueprint: grid-card-assemble (Adapt)
- focal: comparison card
- sfx: whoosh-2 at 0.0, pop-1 at 1.3, pop-2 at 1.7, pop-3 at 2.1
- voiceover: ""

Adapt: rows self-assemble in a cascade, each ending in a delta chip.
Scene 1 (0.0-0.6s): headline "Calculated times drift." rises in upper third.
Scene 2 (0.5-1.3s): glass card slides up; column heads "Calculated" and "Your masjid"; rows Fajr 5:06 / 5:26, Asr 4:10 / 4:57, Isha 8:43 / 8:16 cascade in.
Scene 3 (1.3-2.4s): red gap chips pop per row: "20 min", "47 min", "27 min".
Scene 4 (2.4-3.6s): footnote "Masjid Faizul Islam · 27 Sep" fades in; the "Your masjid" column glows blue; hold.

## Frame 3: Reveal: Masjidly

- scene: app icon springs up, wordmark and promise line
- duration: 2.6s
- transition_in: cut
- status: animated
- src: compositions/frames/03-reveal.html
- blueprint: logo-assemble-lockup (Adapt)
- focal: assets/app-icon.png
- roles: app-icon = cutout
- sfx: whoosh-3 at 0.0
- voiceover: ""

Scene 1 (0.0-0.9s): radial glow blooms at center; app icon springs from 0 to full with a soft rotation settle.
Scene 2 (0.7-1.5s): wordmark "Masjidly" letter-cascades in under the icon.
Scene 3 (1.4-2.6s): line "Times straight from your masjid's timetable." fades up; hold.

## Frame 4: Every salah, its own sky

- scene: phone runs through the real prayer screens (Fajr, Dhuhr, Asr, Maghrib, Isha skies) then the day's adhan and iqamah table slides up
- duration: 4.6s
- transition_in: cut
- status: animated
- src: compositions/frames/04-prayers.html
- blueprint: device-surface-showcase (Adapt, stepwise flow)
- focal: rebuilt home screen (faithful to assets/screens/home.png)
- roles: home screen = hero; timetable sheet = second screen (faithful to assets/screens/timetable.png)
- sfx: whoosh-1 at 0.0, pop-1 at 0.9, pop-2 at 1.5, pop-3 at 2.1, pop-1 at 2.7, whoosh-2 at 3.3
- voiceover: ""

Scene 1 (0.0-0.8s): headline "Every salah." upper third; phone rises with a slight 3D tilt settling flat, Fajr screen (5:26AM, Iqamah 6:20AM, navy-purple sky).
Scene 2 (0.8-3.2s): screen steps through Dhuhr 1:02PM/2:00PM (pale cyan sky, dark ink), Asr 4:57PM/5:45PM (cyan-yellow), Maghrib 6:54PM/6:57PM (pink), Isha 8:16PM/8:30PM (deep navy); sky crossfades, time digits roll, the initials row highlight steps F D A M I.
Scene 3 (3.2-4.6s): timetable sheet slides up (Prayer / Adhan / Iqamah, 27 September, Masjid Faizul Islam); chips "Adhan" and "Iqamah" pop over the columns; hold.

## Frame 5: Mosque tabs

- scene: reconstructed home screen; plus button adds Masjid Risalah as a tab and the times swap
- duration: 3.6s
- transition_in: cut
- status: animated
- src: compositions/frames/05-tabs.html
- blueprint: cursor-ui-demo (Adapt, tap dots instead of a cursor)
- focal: tab bar
- sfx: whoosh-3 at 0.0, pop-2 at 1.0, pop-3 at 1.8
- voiceover: ""

Scene 1 (0.0-0.8s): headline "All your masjids." ; phone with app UI: Asr 4:57 PM, Iqamah 5:45 PM, tabs "Masjid Faizul Islam" (selected) + "+".
Scene 2 (0.8-1.7s): tap ripple on "+", new tab "Masjid Risalah" slides in and becomes selected.
Scene 3 (1.7-2.6s): digits roll: 4:57 to 4:06, iqamah 5:45 to 4:30.
Scene 4 (2.6-3.6s): sub line "One tap apart." fades in; hold.

## Frame 6: Notifications

- scene: lock screen with Masjidly notifications dropping in
- duration: 3.2s
- transition_in: cut
- status: animated
- src: compositions/frames/06-notify.html
- blueprint: compose
- focal: notification stack
- sfx: whoosh-1 at 0.0, pop-1 at 0.7, pop-2 at 1.6
- voiceover: ""

Scene 1 (0.0-0.6s): headline "Never miss jama'ah." ; phone lock screen: big clock 6:54.
Scene 2 (0.6-1.5s): banner 1 drops: "Maghrib Adhan / Adhan is now in Masjid Faizul Islam. Tap to hear adhan."
Scene 3 (1.5-2.4s): banner 2 drops on top: "Isha Iqamah soon / Iqamah in 10 min in Masjid Faizul Islam."
Scene 4 (2.4-3.2s): hold.

## Frame 7: Widgets

- scene: home-screen widgets assemble in small and medium sizes, each in its prayer's sky
- duration: 3.2s
- transition_in: cut
- status: animated
- src: compositions/frames/07-widgets.html
- blueprint: grid-card-assemble (Reproduce)
- focal: widget grid
- sfx: whoosh-2 at 0.0, pop-3 at 0.8, pop-1 at 1.2, pop-2 at 1.6
- voiceover: ""

Scene 1 (0.0-0.6s): headline "On your home screen."
Scene 2 (0.6-2.0s): widgets pop in staggered: small Asr 4:57PM / Iqamah 5:45PM (cyan-yellow sky), small Isha 8:16PM / Iqamah 8:30PM (navy sky), medium "Masjid Faizul Islam · Sun 27 Sep · NEXT Maghrib 6:54PM · Iqamah 6:57PM" (pink sky).
Scene 3 (2.0-3.2s): chip "iPhone · Android" pops; hold.

## Frame 8: 340+ masjids and growing

- scene: count-up to 340+, 10 countries, city names scatter
- duration: 3.2s
- transition_in: cut
- status: animated
- src: compositions/frames/08-count.html
- blueprint: dataviz-countup (Adapt)
- focal: the number
- sfx: whoosh-3 at 0.0, impact at 1.2
- voiceover: ""

Scene 1 (0.0-1.2s): number counts 0 to 340, "+" snaps on at the end.
Scene 2 (0.8-2.0s): "masjids · 10 countries" rises under it; city names pop scattered around (Sheffield, Birmingham, London, Toronto, Jakarta, Riyadh, Cairo, Dubai, Sydney, Paris).
Scene 3 (2.0-3.2s): accent pill "More added every week" pops; hold.

## Frame 9: CTA

- scene: icon + Masjidly lockup, free on iPhone and Android
- duration: 2.8s
- transition_in: cut
- status: animated
- src: compositions/frames/09-cta.html
- blueprint: titlecard-reveal (Reproduce)
- focal: assets/app-icon.png
- roles: app-icon = cutout
- sfx: whoosh-1 at 0.0
- voiceover: ""

Scene 1 (0.0-0.8s): icon + "Masjidly" lockup settles in.
Scene 2 (0.6-1.4s): "Your masjid. Your times." rises in.
Scene 3 (1.2-2.4s): store pill "Free on iPhone & Android" pops; hold to end.
