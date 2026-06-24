# Prayer sky gradients

Reference for Masjidly home, timetable, settings, and widget backgrounds.

Implementation: `Masjidly - Official Masjid Prayer Times/Features/Home/HomeDesign.swift` (iOS) and `apps/android/app/src/main/kotlin/com/mikhailspeaks/masjidly/ui/home/HomeDesign.kt` (Android).

---

## Production assignment

These are configurable in **Settings → Theme → Sky gradients** (collapsible). Defaults: Fajr, Sunrise, and Maghrib use **Modern**; others use **Original**.

| Prayer   | Original | Modern |
|----------|----------|---------|
| Fajr     | Navy linear + orange glow | `#6274E7` → `#8752A3` linear |
| Sunrise  | Sunrise linear + glow | Linear Asr pastel colors |
| Dhuhr    | Original linear | `#EBF4F5` → `#B5C6E0` linear |
| Asr      | Original linear | `#FBD07C` → `#F7F779` linear |
| Maghrib  | Purple/pink linear | `#F2D7D9` → `#E786A7` linear |
| Isha     | Original linear | `#000328` → `#00458E` linear |

### Legacy production table

| Prayer   | Style   | Source palette                          | Rendering        |
|----------|---------|-----------------------------------------|------------------|
| Fajr     | Classic | Fajr classic                            | Linear + glow    |
| Sunrise  | Classic | Asr pastel colors                       | Linear (top → bottom) |

Linear colors: `#9FF1F2` → `#6CD4E4` → `#73E1EA` → `#BDE2BD`.
| Dhuhr    | Classic | Dhuhr classic                           | Linear + glow    |
| Asr      | Classic | Asr classic                             | Linear + glow    |
| Maghrib  | Pastel  | Maghrib pastel                          | Mesh composition |
| Isha     | Classic | Isha classic                            | Linear + glow    |
| Tahajjud | Classic | Tahajjud classic                        | Linear           |

### Text color (production)

| Prayer   | Text      |
|----------|-----------|
| Fajr     | `#FFFFFF` |
| Sunrise  | `#111111` |
| Dhuhr    | `#111111` |
| Asr      | `#111111` |
| Maghrib  | `#111111` |
| Isha     | `#FFFFFF` |
| Tahajjud | `#FFFFFF` |

---

## Original palettes (linear gradient, top → bottom)

Optional bottom radial **glow** is rendered separately in `AtmosphericSkyBackground`.

### Fajr
- `#6274E7` → `#8752A3` (linear, top → bottom — same angle as Dhuhr)
- Glow: none

### Sunrise
- `#6B7280`, `#C084FC`, `#FB923C`, `#F59E0B`
- Glow: `#FEF08A`

### Dhuhr
- `#E0F2FE`, `#7DD3FC`, `#38BDF8`
- Glow: `#38BDF8` @ 20% alpha

### Asr
- `#93C5FD`, `#FDE68A`, `#FDBA74`
- Glow: `#D6B38A`

### Maghrib
- `#6D3FA9`, `#A855F7`, `#F472B6`, `#FB7185`
- Glow: `#F59E0B`

### Isha
- `#000000`, `#020617`, `#0F172A`
- Glow: `#0F172A` @ 40% alpha

### Tahajjud
- `#000000`, `#01030A`, `#020617`
- Glow: none

---

## Pastel palettes (mesh composition)

Pastel skies stack overlapping **elliptical color blobs**, light **radial overlays**, and a subtle linear wash (18% opacity). See `AtmosphericSkyBackground.meshSkyLayer`.

### Fajr pastel
**Gradient stops:** `#DFEFF8` (0), `#A2ECF7` (0.26), `#84B3F4` (0.63), `#AB8DD6` (1)  
**Mesh base:** `#DFEFF8`  
**Radial overlay:** `#A2ECF7` @ (0.68, 0.08), opacity 0.45, radius 0.38  
**Mesh blobs:** `(0.10,0.06) #DFEFF8 0.98/0.82`, `(0.88,0.10) #A2ECF7 0.92/0.72`, `(0.42,0.38) #84B3F4 0.88/0.90`, `(0.78,0.82) #AB8DD6 0.94/0.78`, `(0.16,0.72) #96A1EA 0.80/0.68`

### Sunrise pastel
**Gradient stops:** `#F7D7C4` (0), `#F9BFA4` (0.28), `#F6A6B8` (0.62), `#A8D8F0` (1)  
**Mesh base:** `#F7D7C4`  
**Radial overlays:** `#FFE6B4` @ (0.50, 0.12) 0.50/0.32, `#A8D8F0` @ (0.22, 0.85) 0.42/0.40  
**Mesh blobs:** `(0.22,0.10) #F7D7C4`, `(0.62,0.18) #F9BFA4`, `(0.48,0.52) #F6A6B8`, `(0.82,0.78) #A8D8F0`, `(0.14,0.80) #F2C4D0`

### Dhuhr pastel
**Gradient stops:** `#D6EFFA` (0), `#DCEFFC` (0.22), `#7CB5F0` (0.65), `#62B1E0` (1)  
**Mesh base:** `#D6EFFA`  
**Radial overlay:** `#DCEFFC` @ (0.58, 0.05) 0.45/0.38  
**Mesh blobs:** `(0.14,0.08) #D6EFFA`, `(0.72,0.12) #DCEFFC`, `(0.50,0.46) #7CB5F0`, `(0.36,0.84) #62B1E0`, `(0.88,0.70) #6AB9F8`

### Asr pastel *(used for Sunrise in production)*
**Gradient stops:** `#9FF1F2` (0), `#6CD4E4` (0.32), `#73E1EA` (0.62), `#BDE2BD` (1)  
**Mesh base:** `#9FF1F2`  
**Radial overlays:** `#9FF1F2` @ (0.18, 0.06) 0.50/0.36, `#BDE2BD` @ (0.45, 0.88) 0.45/0.42  
**Mesh blobs:** `(0.20,0.10) #9FF1F2`, `(0.78,0.14) #6CD4E4`, `(0.52,0.44) #73E1EA`, `(0.30,0.82) #BDE2BD`, `(0.82,0.76) #88E8E8`

### Maghrib pastel
**Gradient stops:** `#F2D7D9` (0), `#E786A7` (1)
**Mesh base:** `#F2D7D9`
**Radial overlay:** `#F2D7D9` @ (0.18, 0.04) 0.48/0.38
**Mesh blobs:** `(0.16,0.08) #F2D7D9`, `(0.76,0.82) #E786A7`, `(0.20,0.78) #F0C4D8`

### Isha pastel
**Gradient stops:** `#1D1939` (0), `#1B122F` (0.34), `#221A2E` (0.68), `#050409` (1)  
**Mesh base:** `#1D1939`  
**Radial overlay:** `#221A2E` @ (0.55, 0.35) 0.55/0.45  
**Mesh blobs:** `(0.50,0.12) #1D1939`, `(0.18,0.38) #1B122F`, `(0.72,0.42) #221A2E`, `(0.48,0.78) #050409`, `(0.82,0.68) #2A2040`

---

## Mesh blob notation

Each blob: `center (x, y)`, `color`, `opacity`, `radiusFraction`.  
Coordinates are normalized `UnitPoint` (0–1).  
Widget target mirrors the same palettes in `MasjidlyWidgets/MasjidlyWidgets.swift`.

---

## Historical note

Earlier builds exposed per-prayer Original / Pastel / Classic Mesh pickers in Settings. That UI was removed; palettes above remain in code and in this document for design reference.
