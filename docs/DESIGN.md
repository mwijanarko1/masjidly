---
version: alpha
name: Masjidly
description: Native SwiftUI visual identity for official masjid prayer times — light, airy “weather” home with navy type, cool gray secondary text, and sky-blue accents on soft white surfaces.
colors:
  primary: "#1D2433"
  on-primary: "#FFFFFF"
  secondary: "#9095A1"
  accent: "#47A6FF"
  accent-deep: "#2E8DFF"
  success: "#58D66D"
  surface: "#FFFFFF"
  surface-muted: "#F8F9FB"
  on-surface: "#1D2433"
  border-subtle: "#F0F0F0"
  shadow-soft: "rgba(0,0,0,0.04)"
  gradient-weather-start: "#FFFFFF"
  gradient-weather-end: "#F8F9FB"
  gradient-dawn-start: "#4A5EAD"
  gradient-dawn-end: "#95669F"
  gradient-day-start: "#2F75D6"
  gradient-day-end: "#12385A"
  gradient-dusk-start: "#B96B24"
  gradient-dusk-end: "#5B2D16"
  gradient-night-start: "#0A1220"
  gradient-night-end: "#050810"
  atmosphere-shine: "#47A6FF"
typography:
  display-prayer-time:
    fontFamily: SF Pro Rounded
    fontSize: 96px
    fontWeight: 700
    lineHeight: 1.05
  title-prayer-name:
    fontFamily: SF Pro
    fontSize: 28px
    fontWeight: 500
    lineHeight: 34px
  title-section:
    fontFamily: SF Pro
    fontSize: 22px
    fontWeight: 700
    lineHeight: 28px
  title-mosque:
    fontFamily: SF Pro
    fontSize: 20px
    fontWeight: 700
    lineHeight: 26px
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
    fontSize: 14px
    fontWeight: 500
    lineHeight: 18px
  label-strong:
    fontFamily: SF Pro Text
    fontSize: 16px
    fontWeight: 700
    lineHeight: 20px
  caption:
    fontFamily: SF Pro Text
    fontSize: 12px
    fontWeight: 500
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
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: 12px
    typography: "{typography.label-md}"
  card-surface:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    borderColor: "{colors.border-subtle}"
    rounded: "{rounded.lg}"
    padding: 16px
  chip-status:
    backgroundColor: "rgba(0,0,0,0.2)"
    textColor: "{colors.on-primary}"
    accentText: "{colors.success}"
    rounded: "{rounded.pill}"
    typography: "{typography.caption}"
  carousel-prayer:
    width: 80px
    height: 110px
    rounded: "{rounded.lg}"
    selectedBackground: "linear-gradient({colors.accent} → {colors.accent-deep})"
---

## Overview

Masjidly presents **official mosque prayer times** on a **light, calm home screen** inspired by modern weather apps: a tall vertical **white → cool gray** background, a soft **sky-blue atmospheric bloom** at the top, and **high-contrast navy** (`primary`) for titles and the main adhan time. The emotional tone stays **trustworthy and uncluttered** — easy to read at a glance, respectful of context, without heavy dark chrome or ornamental noise.

The **default Home experience** uses the `weather` time theme: full-screen `gradient-weather-*`, optional subtle `#47A6FF` shine, and **opaque white cards** with **1pt** `border-subtle` hairlines where needed (for example the circular settings control). Alternate **dawn / day / dusk / night** gradients remain in the design system for sheets, future theming, or non-Home surfaces; they are documented in tokens but are not the current Home backdrop.

Prayer-specific **raster illustrations** (asset catalog) reinforce which salat is next without relying on dense iconography alone.

This file follows the [DESIGN.md format](https://stitch.withgoogle.com/docs/design-md/overview) used by Google Stitch: YAML tokens are normative; sections below explain intent and how they map to SwiftUI (`HomeDesign`, `HomeView`, `HomeUIComponents`).

## Colors

- **Primary (`#1D2433`):** Main text and icons — mosque title, section headers (“Today”), hero adhan time, quick-info values, carousel copy when unselected.
- **Secondary (`#9095A1`):** Supporting labels — prayer name under the hero time, tertiary row labels, “7 days” link style treatments.
- **Accent (`#47A6FF`) / accent-deep (`#2E8DFF`):** Interactive emphasis and **selected** prayer state — SF Symbol tints in the horizontal prayer strip, **active gradient** fills (`accent` → `accent-deep`), and glow shadows. Use for focus and selection, not for every body paragraph.
- **On-primary (`#FFFFFF`):** Text and symbols on **accent-filled** or **active-gradient** backgrounds (selected carousel cell).
- **Surface (`#FFFFFF`) / surface-muted (`#F8F9FB`):** Card bodies and vertical background gradient endpoints on Home.
- **Border-subtle (`#F0F0F0`):** Hairline strokes on floating circular controls and glass-adjacent chrome.
- **Success (`#58D66D`):** Positive or “live” micro-copy in status-style chips when used; keep glow minimal.
- **Time-of-day gradients** (`gradient-dawn-*` through `gradient-night-*`): Atmospheric palettes for **non–weather** themes; pair with theme-appropriate `glowColor` in code when those themes are active.
- **Atmosphere-shine (`#47A6FF`):** Large, heavily blurred, very low-opacity shapes for depth on the weather home only — never at full saturation behind body text.

## Typography

Use **system SF Pro**; the **hero adhan time** uses **SF Pro Rounded** at high weight for a friendly, clock-like readout. Prefer **Dynamic Type** scaling in SwiftUI where practical; pixel sizes are reference defaults.

- **display-prayer-time:** Dominant next-prayer adhan time on Home (`~96pt`, bold, rounded design).
- **title-prayer-name:** Prayer name directly under the hero time (`~28pt`, medium).
- **title-section:** Major section titles on Home (`~22pt`, bold), e.g. “Today”.
- **title-mosque:** Center header mosque name (`~20pt`, bold).
- **label-strong / caption:** Quick-info metrics and carousel labels (`~16pt` bold values, `~12pt` medium names); carousel time row uses **~14pt** bold.
- **body-md / body-sm:** Lists, settings copy, timetable rows.
- **label-md:** Buttons, links, compact controls.

Avoid decorative scripts in functional UI.

## Layout

- **Horizontal rhythm:** `spacing.lg` (**24px**) — header, hero stack padding, quick-info row, “Today” header, and horizontal `ScrollView` content inset on Home.
- **Vertical rhythm:** **32px** between the header block and the hero illustration stack; **16px** inside the “Today” block (title row vs. carousel). Use `spacing.md` / `spacing.lg` between major sections elsewhere.
- **Touch targets:** Circular header actions use a **48×48** pt tap area; maintain at least ~44pt for primary navigation.
- **Tab app:** Home leads with the light weather language; Settings reuses the same **gradient-weather** backdrop and token colors for continuity.

## Elevation & Depth

- **Soft card shadow:** Very soft **black at ~4% opacity**, moderate blur and downward offset — white `QuickInfoItem` tiles and unselected carousel cells (`softCard`).
- **Intense glow (selection):** **Accent** at higher opacity under the **active gradient** pill in the prayer carousel — signals “next” alignment without harsh elevation.
- **Warm glow (alternate surfaces):** Accent-tinted shadow for glass-style elements in sheets (`warmGlow`); intensity stays moderate so legibility wins.

Avoid stacking so many shadows that the light theme feels muddy.

## Shapes

- **Cards and tiles:** `rounded.lg` (**24px**) — quick-info columns, prayer carousel items.
- **Pills / chips:** `rounded.pill` (**20px**) — status chip when present.
- **Circular chrome:** **1pt** `border-subtle` stroke on white circular buttons (e.g. settings).

Corners stay **continuous and soft**; no sharp tiles unless required by system components.

## Imagery & icons

- **Hero illustration:** One **prayer-keyed** image (`FajrIllustration`, `DhuhrIllustration`, `AsrIllustration`, `MaghribIllustration`, `IshaIllustration`; Dhuhr and Jummah share Dhuhr art). Shown above the hero time, **high interpolation**, **scaled to fit** within a fixed visual frame (~200pt width class in current layout).
- **Prayer strip:** SF Symbols in **fill** variant — sunrise, sun, cloud/sun, moon/stars, moon — tinted **accent** when unselected, **white** when selected.

## Components

- **card-surface:** White fill, `rounded.lg`, `softCard` shadow — quick-info three-up row on Home.
- **carousel-prayer:** Fixed width/height, white default; **selected** state uses **active gradient** (`accent` → `accent-deep`), white type and symbols, **intenseGlow** shadow; unselected uses **softCard**.
- **button-primary:** Prefer **accent** fill with **on-primary** label for high-emphasis actions (aligned with Settings primary actions using the same token family).
- **chip-status:** Optional compact live indicator; translucent dark capsule with **success** accent for values — only when product needs a live line; not required on the default Home hero.

When adding components, extend the YAML `components` map and reference `{colors.*}`, `{typography.*}`, `{rounded.*}`.

## Do's and Don'ts

**Do**

- Keep the **hero adhan time** the single strongest visual hierarchy (size + weight + `primary` color).
- Use **accent** for **selection**, links, and symbolic emphasis — not for all headings.
- Preserve **light surfaces** and **navy** type contrast for outdoor readability.
- Reuse **border-subtle** and **softCard** so white tiles separate cleanly from `surface-muted` backgrounds.

**Don't**

- Don’t default new Home surfaces to **dark gold** or **ink-only** palettes; those predate the current weather home.
- Don’t place **low-contrast gray** (`secondary`) on **accent** fills for primary content.
- Don’t add **neon or rainbow** gradients unrelated to prayer-time context.
- Don’t shrink touch targets or block **Dynamic Type** for core prayer information.

---

## References

- [What is DESIGN.md? (Stitch Docs)](https://stitch.withgoogle.com/docs/design-md/overview)
- [DESIGN.md specification & tooling](https://github.com/google-labs-code/design.md)

Optional validation (when using Node tooling in this repo): `npx @google/design.md lint docs/DESIGN.md` per upstream README.
