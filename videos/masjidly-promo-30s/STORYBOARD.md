---
format: 1080x1920
duration: 55s
message: "Prayer times from your own masjid, not a calculation that's minutes off"
arc: One day of prayer, Fajr to the last third of the night, then the next dawn
audience: Muslims who pray at a local masjid, on TikTok / Reels / Shorts
mode: autonomous
music: "Path to Jannah" nasheed (vocals only) + typing track + SFX
version: v6 (the app never leaves the screen; captions overlay its empty space; stage JS lives in tools/stage.js and is inlined by tools/build_stage.py)
---

## Video direction

- **The frame is the app.** No phone mockup. The Masjidly home screen fills the frame on its own sky; the camera zooms into features and back out. Other screens (comparison card, theme cards, lock screen, widgets, timetable) take over the full frame the same way.
- **Background is the app's sky.** Exactly the app's default per-prayer skies from `HomeDesign.swift` (Modern for Fajr, Sunrise, Asr, Maghrib, Isha; Original for Dhuhr and Tahajjud), crossfading over 0.8s whenever a prayer is selected, as in the app. Stars appear only on the non-app count and closing screens.
- **The letter picker drives the sky.** Beat 2 taps S, D, A, M, I: the page, the sun-phase icon, the ink colour and the whole background change on each tap. The captions never mention it.
- **Typed caption rail**, top-left, lowercase Gill Sans, block cursor, keywords in the accent. Every keystroke has a keyboard click (`assets/audio/typing.wav`, generated with the captions by `tools/build_captions.py`).
- **Motion:** zoom-throughs (logo into app, Isha widget into timetable), focus pulls (the rest of the UI dims and blurs), whip-ins with motion blur, the app zooming out into three theme cards, page crossfades like the app, screen-recording style tap markers, one RGB glitch.

## Layers

- `compositions/v2/sky.html`: the app's skies in tap order (incl. Original + Custom Asr themes and the Tahajjud night), stars for the count only.
- `compositions/v2/stage.html`: the app and every screen, one camera (`#s-cam`).
- `compositions/v2/caption.html`: typed rail. Beats are written by `tools/build_captions.py`; edit them there and rerun it.
- `index.html`: 40s host, nasheed bed (`nasheed-bed-v3.mp3`), typing track, 87 SFX cues (incl. synthesized sub, glass, tick, roll, chime, riser, ink).

## Beats

| Time | Sky | Caption (overlaid) | On screen |
|---|---|---|---|
| 0-1.9 | Fajr | | Logo scramble, zoom through into the app |
| 1.9-7.6 | Fajr | calculated times drift. / yours come from your masjid. | "Calculated" pill; the time ticks live 5:06 to 5:26 with a bass thud; "Your masjid" pill and "+20 min" badge |
| 7.6-13.6 | Sunrise to Isha | prayer times, redesigned. / adhan and iqamah at a glance. | Taps on S D A M I; page, icon, ink and sky change (not mentioned) |
| 13.6-19.8 | Dhuhr (Original) | in your language. / right to left, too. | "Choose your language" sheet; العربية, اردو, Bahasa Indonesia; names stroke-draw on |
| 19.8-26.4 | Asr | add all your masjids. / switch in one tap. | + four times: Masjid Risalah, Sheffield Grand Mosque, Masjid Umar (YMA), Madina Masjid Sheffield; tab bar scrolls; back to Masjid Faizul Islam |
| 26.4-31.6 | Asr, Original, Custom | make it yours. / your theme, or your own colours. | Original / Modern / Custom cards, custom colours change, 3D tilt away |
| 31.6-36.6 | Maghrib | never miss iqamah. / the adhan, right on time. | Lock screen, 6:47 iqamah reminder then 6:54 adhan, with chimes |
| 36.6-43.2 | Isha | on your home screen. / and your lock screen. | Small + large widgets (live countdown to Isha), then lock screen inline, circular and rectangular widgets |
| 43.2-47.4 | Tahajjud | the night, worked out. / midnight and the last third. | Timetable zoom to Midnight 12:11AM and Last Third 1:56AM; night line |
| 47.4-51.6 | Stars | masjids in 10 countries. / and more every week. | 340+ over a turning globe, arcs from Sheffield to cities |
| 51.6-55 | Dawn | your masjid. your times. | Icon, wordmark, App Store and Google Play buttons |

Data: Masjid Faizul Islam and Masjid Risalah, 27 Sep 2026, production Convex. Midnight and Last Third use the app's `computeMidnightAndLastThird` (Maghrib 18:54 to next Fajr 05:28). Calculated comparison is Muslim World League via AlAdhan. Arabic time format verified with the same `DateFormatter` setup the app uses.
