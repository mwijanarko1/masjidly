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

export function cityOptions(mosques: Mosque[]): { key: string; label: string }[] {
  const visible = visibleMosques(mosques);
  const map = new Map<string, Mosque[]>();
  for (const m of visible) {
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
