import type { Mosque } from "@/types/prayer";

export const DEFAULT_MOSQUE_SLUG = "muslim-welfare-house";

/** Stable key for grouping / settings (matches native `Mosque.cityGroupingKey`). */
export function cityGroupingKey(m: Pick<Mosque, "citySlug" | "cityName">): string {
  if (m.citySlug && m.citySlug.length > 0) {
    return `slug:${m.citySlug}`;
  }
  const label = (m.cityName ?? "Sheffield").toLowerCase();
  return `name:${label}`;
}

// ── Country ──

/** Stable key for grouping mosques by country (matches native `MosqueDefaults.countryGroupingKey`). */
export function countryGroupingKey(m: Pick<Mosque, "countryCode">): string {
  const code = (m.countryCode ?? "").trim();
  return code.length > 0 ? code.toUpperCase() : "unknown";
}

export function countryOptions(mosques: Mosque[]): { key: string; label: string }[] {
  const visible = visibleMosques(mosques);
  const map = new Map<string, Mosque[]>();
  for (const m of visible) {
    const k = countryGroupingKey(m);
    if (!map.has(k)) map.set(k, []);
    map.get(k)!.push(m);
  }
  const keys = [...map.keys()].sort((a, b) =>
    countryLabelForKey(map, a).localeCompare(countryLabelForKey(map, b), undefined, {
      sensitivity: "base",
    })
  );
  return keys.map((key) => ({ key, label: countryLabelForKey(map, key) }));
}

function countryLabelForKey(grouped: Map<string, Mosque[]>, key: string): string {
  const list = grouped.get(key);
  const first = list?.[0];
  return first?.countryName ?? first?.countryCode ?? key;
}

export function mosquesInCountry(key: string, mosques: Mosque[]): Mosque[] {
  return visibleMosques(mosques).filter((m) => countryGroupingKey(m) === key);
}

// ── City ──

export function cityOptions(
  mosques: Mosque[],
  countryKey?: string
): { key: string; label: string }[] {
  const filtered = countryKey && countryKey.length > 0
    ? mosquesInCountry(countryKey, mosques)
    : visibleMosques(mosques);
  if (filtered.length === 0) return [];
  const map = new Map<string, Mosque[]>();
  for (const m of filtered) {
    const k = cityGroupingKey(m);
    if (!map.has(k)) map.set(k, []);
    map.get(k)!.push(m);
  }
  const keys = [...map.keys()].sort((a, b) =>
    cityLabelForKey(map, a).localeCompare(cityLabelForKey(map, b), undefined, {
      sensitivity: "base",
    })
  );
  return keys.map((key) => ({ key, label: cityLabelForKey(map, key) }));
}

function cityLabelForKey(grouped: Map<string, Mosque[]>, key: string): string {
  const list = grouped.get(key);
  const first = list?.[0];
  return first?.cityName ?? first?.citySlug ?? key;
}

export function mosquesInCity(key: string, mosques: Mosque[]): Mosque[] {
  return visibleMosques(mosques).filter((m) => cityGroupingKey(m) === key);
}

export function visibleMosques(all: Mosque[]): Mosque[] {
  return all
    .filter((m) => !m.isHiddenResolved)
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
}

export function resolveSelectedMosque(
  mosques: Mosque[],
  selectedId: string | null | undefined,
  selectedSlug: string | null | undefined
): Mosque | null {
  const visible = visibleMosques(mosques);
  if (visible.length === 0) return null;
  if (selectedId) {
    const m = visible.find((m) => m.id === selectedId);
    if (m) return m;
  }
  if (selectedSlug) {
    const m = visible.find((m) => m.slug === selectedSlug);
    if (m) return m;
  }
  return visible.find((m) => m.slug === DEFAULT_MOSQUE_SLUG) ?? visible[0] ?? null;
}
