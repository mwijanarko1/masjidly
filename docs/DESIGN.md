---
version: beta
name: Masjidly
description: Minimalist, time-adaptive visual identity for official masjid prayer times — full-bleed gradients, custom line-art sun phases, and Comfortaa typography matching the 3D rounded logo aesthetic.
colors:
  primary: "#111111"
  on-primary: "#FFFFFF"
  secondary: "#9095A1"
  accent: "#47A6FF"
  accent-deep: "#2E8DFF"
  success: "#58D66D"
  surface: "#FFFFFF"
  glass-border: "#F0F0F0"
  
  # Atmospheric Sky Themes (Layered Gradients)
  # Each theme uses a 3-layer base linear sky + a radial horizon glow (center: 50% 82%)
  
  theme-fajr:
    sky: ["#020326", "#06114F", "#0B1E6D", "#3B2A5A"]
    glow: "#F08A4B"
    mood: "Deep pre-dawn blue with faint warm horizon light and fading night atmosphere"
    
  theme-sunrise:
    sky: ["#6B7280", "#C084FC", "#FB923C", "#F59E0B"]
    glow: "#FEF08A"
    mood: "Warm golden sunrise with purple clouds and bright horizon light"
    
  theme-dhuhr:
    sky: ["#E0F2FE", "#7DD3FC", "#38BDF8"]
    glow: "#38BDF8" (Subtle)
    mood: "Bright clean midday sky"
    
  theme-asr:
    sky: ["#93C5FD", "#FDE68A", "#FDBA74"]
    glow: "#D6B38A"
    mood: "Dusty late-afternoon sunlight"
    
  theme-maghrib:
    sky: ["#6D3FA9", "#A855F7", "#F472B6", "#FB7185"]
    glow: "#F59E0B"
    mood: "Vivid purple-pink sunset with warm orange horizon light"
    
  theme-isha:
    sky: ["#000000", "#020617", "#0F172A"]
    glow: "#0F172A" (Haze)
    mood: "Deep quiet night"
    
  theme-tahajjud:
    sky: ["#000000", "#01030A", "#020617"]
    glow: null
    mood: "Silent late-night darkness"

typography:
  display-adhan-time:
    fontFamily: Comfortaa
    fontSize: 88px
    fontWeight: 300 (Light)
    kerning: -1.76
  title-iqamah-subtitle:
    fontFamily: Comfortaa
    fontSize: 26px
    fontWeight: 400 (Regular)
    tracking: 0.6
  title-prayer-name:
    fontFamily: Comfortaa
    fontSize: 36px
    fontWeight: 400 (Regular)
    kerning: -0.36
  label-date-main:
    fontFamily: Comfortaa
    fontSize: 13px
    fontWeight: 600 (Semibold)
    kerning: 1.0
  label-date-hijri:
    fontFamily: Comfortaa
    fontSize: 10px
    fontWeight: 500 (Medium)
    kerning: 0.8
  label-shortcut:
    fontFamily: Comfortaa
    fontSize: 20px
    fontWeight: 400 (Regular)

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

shadows:
  soft-card: "rgba(0,0,0,0.04) 15px blur, 8px offset-y"
  intense-glow: "rgba(71,166,255,0.4) 25px blur, 12px offset-y"
  warm-glow: "rgba(71,166,255,0.3) 20px blur, 10px offset-y"
---

## Overview

Masjidly delivers **official mosque prayer times** through a **minimalist, atmospheric interface** that adapts its visual language to the current prayer. The design moves away from static cards and lists toward a **full-bleed, immersive experience** where color, light, and iconography shift to reflect the spiritual rhythm of the day.

The emotional tone is **ethereal and focused** — prioritizing the immediate prayer time while providing a tactile, physical feel through smooth transitions and high-end typography.

## Design Pillars

### 1. Time-Adaptive Atmosphere
The background is a dynamic `LinearGradient` that shifts based on the active prayer (Fajr through Isha). 
- **Light Themes (Sunrise-Maghrib):** Use dark text (`#111111`) for maximum legibility against vibrant, airy skies.
- **Dark Themes (Fajr, Isha, Tahajjud):** Use white text (`#FFFFFF`) against deep navy and indigo voids.

### 2. Custom Line-Art Sun Phases
Instead of traditional icons or heavy illustrations, Masjidly uses **Canvas-drawn line art** to represent the sun's position. These icons are:
- **Minimalist:** Constructed from thin (1.8pt) and medium (2.2pt) strokes.
- **Symbolic:** Use geometric primitives (semicircles, stars, arrows, rays) to communicate dawn, midday, sunset, and night.
- **Dynamic:** Colors match the theme's primary text color for perfect integration.

### 3. Comfortaa Typography
The entire app is voiced in **Comfortaa**. This completely rounded, geometric font perfectly mirrors the continuous tubular aesthetic of the 3D logo icon.
- **Hierarchy:** The Adhan time is the hero, using a light weight and tight kerning to feel elegant yet dominant, like bent neon tubes.
- **Support:** Iqamah times and prayer names use regular weights with generous tracking/kerning to maintain a "premium clock" aesthetic.

## Colors & Gradients

- **Theme Gradients:** Each prayer has a curated palette (e.g., Maghrib uses a purple → pink → orange progression).
- **Primary Text:** Either `#111111` or `#FFFFFF` depending on the background brightness.
- **Accent Blue (`#47A6FF`):** Used sparingly for interactive elements like the settings/calendar button backgrounds (at 18% opacity) and selection states.

## Layout & Components

### Home Screen (MinimalistPrayerPage)
The layout follows a vertical central axis with specific spatial anchors:
- **Top Chrome:** Calendar (Left) and Settings (Right) buttons housed in circular blurred white containers (`opacity: 0.18`).
- **Date Header:** Center-aligned Gregorian and Hijri dates in small-caps style.
- **Hero Icon:** The `PrayerSunPhaseIcon` sits prominently above the clock.
- **The Clock:** Hero Adhan time followed by a localized "Iqamah: [time]" subtitle.
- **Prayer Picker:** A horizontal "Letter Picker" (F, S, D, A, M, I) allows quick navigation between prayers with haptic feedback.

### Depth & Elevation
- **Glows:** Selected items or interactive zones use `intense-glow` or `warm-glow` to feel "alive" and elevated without using heavy drop shadows.
- **Soft Cards:** Secondary UI (like quick-info tiles in other views) use a very faint `soft-card` shadow to separate from the background.

## Icons & Symbols

- **Sun Phase Icons:** 
    - **Fajr:** Star + thin horizon.
    - **Sunrise:** Semicircle + upward rays.
    - **Dhuhr:** Sunburst (circle + 8 rays).
    - **Asr:** Post + long diagonal shadow.
    - **Maghrib:** Sunset arrow pointing to horizon.
    - **Isha:** Trio of stars (sparkles).
- **System Icons:** SF Symbols (gearshape.fill, calendar) are used for secondary controls.

## Do's and Don'ts

**Do**
- Keep typography weights **light or regular** to match the thin line icons.
- Ensure **haptic feedback** on every interactive element (picker, buttons).
- Use **full-bleed gradients** for all primary surfaces.
- Preserve the **88pt Hero Time** as the focal point.

**Don't**
- Don't use **heavy card containers** or opaque backgrounds on the home screen.
- Don't mix **Comfortaa** with other decorative typefaces.
- Don't use **high-opacity blacks** for shadows; keep them airy and tinted where possible.

---

## References

- [SF Pro Rounded Design Guidelines](https://developer.apple.com/fonts/)
- [Masjidly UI Components (Swift Implementation)](file:///Masjidly%20-%20Official%20Masjid%20Prayer%20Times/Features/Home/HomeUIComponents.swift)
