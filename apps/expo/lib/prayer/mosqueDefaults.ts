import type { Mosque } from "@/types/prayer";

export const DEFAULT_MOSQUE_SLUG = "muslim-welfare-house";

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
