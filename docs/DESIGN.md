---
version: alpha
name: Masjidly
description: Native SwiftUI visual identity for official masjid prayer times — calm, time-of-day atmospheres with glass surfaces and a warm Islamic accent.
colors:
  primary: "#D98A2B"
  on-primary: "#0B1726"
  secondary: "#0B1726"
  accent: "#F6C15A"
  success: "#58D66D"
  surface: "#070B14"
  surface-elevated: "#0A1220"
  on-surface: "#FFFFFF"
  gradient-dawn-start: "#4A5EAD"
  gradient-dawn-end: "#95669F"
  gradient-day-start: "#2F75D6"
  gradient-day-end: "#12385A"
  gradient-dusk-start: "#B96B24"
  gradient-dusk-end: "#5B2D16"
  gradient-night-start: "#0A1220"
  gradient-night-end: "#050810"
  silhouette: "#2A1810"
typography:
  display-prayer:
    fontFamily: SF Pro Display
    fontSize: 34px
    fontWeight: 700
    lineHeight: 40px
  title-hero:
    fontFamily: SF Pro Display
    fontSize: 28px
    fontWeight: 600
    lineHeight: 34px
  body-md:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: 400
    lineHeight: 22px
  body-sm:
    fontFamily: SF Pro Text
    fontSize: 15px
    fontWeight: 400
    lineHeight: 20px
  label-md:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 500
    lineHeight: 18px
  caption:
    fontFamily: SF Pro Text
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
rounded:
  sm: 8px
  md: 12px
  lg: 24px
  pill: 20px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: 12px
    typography: "{typography.label-md}"
  card-glass:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: 16px
  chip-status:
    backgroundColor: "#000000"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.pill}"
    padding: 12px
    typography: "{typography.label-md}"
---

## Overview

Masjidly presents **official mosque prayer times** with a premium, contemplative feel. The interface follows the rhythm of the day: backgrounds and hero treatments shift across **dawn, day, dusk, and night** themes so the app feels anchored to real-world light, not a static brand wallpaper.

The emotional tone is **trustworthy and calm** — readable at a glance before and after prayer, respectful of sacred context, and visually warm without loud marketing gradients. **Glass-style panels** (subtle translucency, soft borders) organize the hero and key metrics; **gold amber** (`primary`) highlights the next prayer and key actions; **cool deep navy** (`secondary` / surfaces) keeps long reading sessions easy on the eyes.

This file follows the [DESIGN.md format](https://stitch.withgoogle.com/docs/design-md/overview) used by Google Stitch: YAML tokens are normative; sections below explain intent and how to apply tokens in SwiftUI (and any future web surfaces).

## Colors

- **Primary (`#D98A2B`):** Warm gold for emphasis — next prayer, primary controls, sun highlights in daytime hero. Pair with **on-primary (`#0B1726`)** for label text on filled primary backgrounds.
- **Secondary (`#0B1726`):** Deep ink for structural chrome and high-contrast text where the background is light or bright.
- **Accent (`#F6C15A`):** Sunlit yellow for secondary highlights, dusk/sun cores, and subtle glows — use sparingly so it does not compete with primary.
- **Success (`#58D66D`):** Live or “connected” status and positive confirmation only; keep motion and glow subtle.
- **Surface (`#070B14`) / surface-elevated (`#0A1220`):** Default app backdrop and card bases. Prefer vertical **background gradients** between these two for depth when not using a time-of-day gradient.
- **On-surface (`#FFFFFF`):** Primary text and icons on dark gradients and cards. For de-emphasized copy, use **white at ~60% opacity** in implementation (token name `on-surface-muted` documents intent; implement as opacity in SwiftUI).
- **Time-of-day gradients:** Map hero and large background fills to `gradient-dawn-*`, `gradient-day-*`, `gradient-dusk-*`, or `gradient-night-*` per the active `TimeTheme`. These are atmospheric, not for small UI controls.
- **Silhouette (`#2A1810`):** Earthy brown for illustrative silhouettes (e.g. skyline) over day/dusk glass, slightly softened with opacity where needed.

## Typography

Use **system SF Pro** (Display for large headlines, Text for body). Prefer **dynamic type** scaling in SwiftUI where practical; the pixel sizes in tokens are reference defaults at a baseline layout.

- **display-prayer:** Next prayer name or largest time readout — short lines, high weight.
- **title-hero:** Section titles inside the hero stack.
- **body-md / body-sm:** Lists of prayer times, settings explanations.
- **label-md:** Chips, buttons, row subtitles.
- **caption:** Hijri line, footnotes, metadata.

Avoid decorative scripts for body UI; reserve any ornamental typography (if ever used) to marketing screens only, not the prayer dashboard.

## Layout

- **Horizontal rhythm:** Use `spacing.lg` (24px) as the default horizontal inset for hero and primary cards; outer screen margins align with this grid.
- **Vertical rhythm:** Stack related hero text with `spacing.xs` to `spacing.sm`; separate major sections with `spacing.md` or `spacing.lg`.
- **Touch targets:** Keep tappable rows at least ~44pt tall; chip and button vertical padding should meet this when combined with typography.
- **Tab app:** Home and Settings share the same surface language; Settings stays visually quieter (fewer gradients, more list clarity).

## Elevation & Depth

- **Warm glow:** Soft shadow using `primary` at low opacity under hero glass and key cards — suggests lantern-like warmth, not harsh Material elevation.
- **Theme glow:** Each time theme exposes a soft tinted glow (dawn purple, day blue, dusk amber, night blue-black) behind the hero; intensity stays moderate so text remains legible.
- **Glass:** Translucent white fill (~10% opacity) with a ~20% white stroke and **1pt** hairline border on rounded rectangles; avoid heavy blur that obscures underlying gradients on Home.

## Shapes

- **Cards and hero panel:** `rounded.lg` (24px) for the main glass hero and large containers.
- **Chips and pills:** `rounded.pill` (20px) for status chips.
- **Standard inner elements:** `rounded.sm` / `rounded.md` for nested controls.

Corners should feel **continuous and soft** — no sharp tiles unless required by system components (e.g. navigation bar).

## Components

- **button-primary:** Filled gold button for primary actions (e.g. enable notifications, confirm). Always `textColor` on-primary for contrast.
- **card-glass:** Primary content container on Home; may combine with gradient background and optional `customShadow` using primary-tinted shadow from tokens prose.
- **chip-status:** Compact live indicator; background reads as near-black at 20% opacity in code — solid token here is `#000000` for spec compatibility; implement as translucent black over gradients.

When adding new components, define sub-tokens under `components` in the front matter and reference color/typography/rounded tokens with `{colors.*}`, `{typography.*}`, `{rounded.*}`.

## Do's and Don'ts

**Do**

- Shift hero **gradient and glow** with the time-of-day theme so the UI matches user context.
- Keep **next prayer** visually dominant using primary + display typography hierarchy.
- Prefer **high contrast** for prayer times and iqamah against dark surfaces; test in sunlight and night mode.

**Don't**

- Don't use **accent** for large filled buttons — reserve for highlights and illustration.
- Don't add **legal or cluttered footers** on Settings for MVP; keep focus on mosque selection and notifications.
- Don't introduce **neon or rainbow gradients** unrelated to dawn/dusk/night storytelling.
- Don't block **Dynamic Type** or reduce touch targets below platform guidance for accessibility.

---

## References

- [What is DESIGN.md? (Stitch Docs)](https://stitch.withgoogle.com/docs/design-md/overview)
- [DESIGN.md specification & tooling](https://github.com/google-labs-code/design.md)

Optional validation (when using Node tooling in this repo): `npx @google/design.md lint docs/DESIGN.md` per upstream README.
