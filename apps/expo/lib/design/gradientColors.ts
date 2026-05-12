/** Helpers for smoother sky gradients (extra stops + rgba) to match native interpolation. */

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const h = hex.replace("#", "").trim();
  const full = h.length === 3 ? h.split("").map((c) => c + c).join("") : h;
  const r = parseInt(full.slice(0, 2), 16);
  const g = parseInt(full.slice(2, 4), 16);
  const b = parseInt(full.slice(4, 6), 16);
  return { r, g, b };
}

function clamp255(n: number): number {
  return Math.max(0, Math.min(255, Math.round(n)));
}

export function rgbaHex(hex: string, alpha: number): string {
  const { r, g, b } = hexToRgb(hex);
  const a = Math.max(0, Math.min(1, alpha));
  return `rgba(${r},${g},${b},${a})`;
}

export function mixHex(a: string, b: string, t: number): string {
  const A = hexToRgb(a);
  const B = hexToRgb(b);
  const u = Math.max(0, Math.min(1, t));
  const r = clamp255(A.r + (B.r - A.r) * u);
  const g = clamp255(A.g + (B.g - A.g) * u);
  const bl = clamp255(A.b + (B.b - A.b) * u);
  return `#${[r, g, bl].map((x) => x.toString(16).padStart(2, "0")).join("")}`;
}

/**
 * Inserts evenly spaced RGB midpoints along each segment (reduces visible banding on Android).
 * @param extraStopsPerSegment e.g. 2 → up to two interior samples per original segment
 */
export function densifyGradientStops(
  colors: string[],
  extraStopsPerSegment: number
): { colors: string[]; locations: number[] } {
  if (colors.length < 2) {
    return { colors: [...colors], locations: colors.map(() => 0) };
  }
  const segCount = colors.length - 1;
  const outColors: string[] = [];
  const locations: number[] = [];

  for (let s = 0; s < segCount; s++) {
    const t0 = s / segCount;
    const t1 = (s + 1) / segCount;
    if (s === 0) {
      locations.push(t0);
      outColors.push(colors[s]);
    }
    for (let k = 1; k <= extraStopsPerSegment; k++) {
      const u = k / (extraStopsPerSegment + 1);
      const t = t0 + (t1 - t0) * u;
      locations.push(t);
      outColors.push(mixHex(colors[s], colors[s + 1], u));
    }
    locations.push(t1);
    outColors.push(colors[s + 1]);
  }

  return { colors: outColors, locations };
}

/** Vertical gradient approximating SwiftUI RadialGradient horizon glow (screen blend not available). */
export function horizonGlowLinearGradient(
  glowHex: string,
  glowBaseAlpha: number
): { colors: string[]; locations: number[] } {
  const peak = 0.6 * glowBaseAlpha;
  const mid = 0.3 * glowBaseAlpha;
  return {
    colors: [
      rgbaHex(glowHex, Math.min(1, peak * 0.92)),
      rgbaHex(glowHex, peak * 0.68),
      rgbaHex(glowHex, peak * 0.42),
      rgbaHex(glowHex, mid),
      rgbaHex(glowHex, mid * 0.22),
      rgbaHex(glowHex, mid * 0.06),
      "transparent",
    ],
    locations: [0, 0.07, 0.14, 0.26, 0.44, 0.66, 1],
  };
}
