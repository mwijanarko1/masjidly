---
format: 1080x1920
duration: 30s
message: "Prayer times from your own masjid, not a calculation that's minutes off"
arc: One day of prayer, Fajr to Isha, then the next dawn
audience: Muslims who pray at a local masjid, on TikTok / Reels / Shorts
mode: autonomous
music: nasheed (vocals only, no instruments)
version: v2 (continuous single shot; v1 plan kept in STORYBOARD-v1.md)
---

## Video direction

- **Background is the day.** The whole canvas is the app's own per-prayer sky (Set 2 gradients from `HomeDesign.swift`): Fajr #103783 to #8752A3, Dhuhr #EBF4F5 to #60EFFF, Asr #60EFFF to #F3F98A, Maghrib #F2D7D9 to #E786A7, Isha #000328 to #00458E, then pre-dawn again. Sun rises, crosses and sets; stars at Fajr and Isha; moon at Isha. The phone screen shows the same sky, so the phone reads as a window onto the day.
- **One continuous shot.** No hard cuts. One phone stays on stage; the camera slides, pushes and pulls; features appear at the prayer they belong to.
- **Typed caption rail** (inspired by the opencode 2 video): top-left, Gill Sans, lowercase, blinking block cursor, types line 1 then line 2, then backspaces. Prayer name leads each beat in the accent. Ink follows the app's rule: white on dark skies, dark on light skies.
- **Restrained effects:** logo scramble at open and close, one RGB glitch on the calculated time, tap ripples on real interactions.

## Layers

- `compositions/v2/sky.html`: sky gradients, sun path, stars, moon, horizon glow, grain, vignette.
- `compositions/v2/stage.html`: intro lockup, phone (home, tabs, picker, lock screen), hook chips, drift card, notifications, widgets, count, CTA.
- `compositions/v2/caption.html`: typed caption rail.
- `index.html`: hosts the three layers for 0 to 30s, nasheed bed, 28 SFX cues.

## Beats

| Time | Sky | Caption | On stage |
|---|---|---|---|
| 0.0-5.6 | Fajr, stars, dawn glow | fajr. calculated says 5:06. / your masjid says 5:26. | Logo scramble; phone rises on the Fajr screen; "calculated 5:06 AM" glitches and is struck; "your masjid 5:26 AM"; "20 min off" |
| 5.6-10.8 | Dhuhr, sun at noon | dhuhr. calculated times drift. / your masjid's times don't. | Phone slides out; Fajr / Asr / Isha comparison card (20, 47, 27 min); phone returns on Dhuhr |
| 10.8-16.2 | Asr | asr. add all your masjids. / switch in one tap. | Push in; tap +; picker; add Masjid Risalah (Asr 4:57 to 4:06); tap back to Masjid Faizul Islam |
| 16.2-21.4 | Maghrib, sunset | maghrib. a nudge before iqamah. / then the adhan, right on time. | Lock screen 6:47 with "Maghrib Iqamah soon" (default 10 min reminder); clock to 6:54; "Maghrib Adhan" |
| 21.4-24.2 | Isha, moon | isha. on your home screen too. | Unlock to Isha screen; phone becomes Asr, Isha, Maghrib widgets |
| 24.2-27.0 | Isha, bright stars | 340+ masjids in 10 countries. / and more every week. | Count to 340+, city stars |
| 27.0-30.0 | Next dawn | your masjid. / your times. | Icon, scrambled wordmark, "Free on iPhone & Android", sheffieldmasjids.com/masjidly |

All times are real production data for Masjid Faizul Islam and Masjid Risalah on 27 Sep 2026; the calculated comparison is Muslim World League via the AlAdhan API.
