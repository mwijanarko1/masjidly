import { visibleMosques, resolveSelectedMosque, DEFAULT_MOSQUE_SLUG } from "@/lib/prayer/mosqueDefaults";
import type { Mosque } from "@/types/prayer";

function makeMosque(p: Partial<Mosque> & { id: string; name: string; slug: string }): Mosque {
  return {
    id: p.id,
    name: p.name,
    address: p.address ?? "",
    lat: p.lat ?? 0,
    lng: p.lng ?? 0,
    slug: p.slug,
    website: p.website ?? null,
    isHidden: p.isHidden ?? false,
    isHiddenResolved: p.isHidden ?? false,
  };
}

describe("MosqueDefaults", () => {
  it("filters hidden mosques", () => {
    const all: Mosque[] = [
      makeMosque({ id: "1", name: "Alpha", slug: "alpha", isHidden: false }),
      makeMosque({ id: "2", name: "Beta", slug: "beta", isHidden: true }),
      makeMosque({ id: "3", name: "Gamma", slug: "gamma", isHidden: false }),
    ];
    const visible = visibleMosques(all);
    expect(visible.length).toBe(2);
    expect(visible.map((m) => m.slug)).toEqual(["alpha", "gamma"]);
  });

  it("sorts visible mosques by name case-insensitively", () => {
    const all: Mosque[] = [
      makeMosque({ id: "1", name: "Zebra", slug: "zebra" }),
      makeMosque({ id: "2", name: "alpha", slug: "alpha" }),
      makeMosque({ id: "3", name: "Beta", slug: "beta" }),
    ];
    const visible = visibleMosques(all);
    expect(visible.map((m) => m.name)).toEqual(["alpha", "Beta", "Zebra"]);
  });

  it("resolves by selected id first", () => {
    const all: Mosque[] = [
      makeMosque({ id: "a", name: "A", slug: "a" }),
      makeMosque({ id: "b", name: "B", slug: "b" }),
    ];
    const resolved = resolveSelectedMosque(all, "b", undefined);
    expect(resolved?.slug).toBe("b");
  });

  it("resolves by selected slug when id misses", () => {
    const all: Mosque[] = [
      makeMosque({ id: "a", name: "A", slug: "a" }),
      makeMosque({ id: "b", name: "B", slug: "b" }),
    ];
    const resolved = resolveSelectedMosque(all, "bad-id", "b");
    expect(resolved?.slug).toBe("b");
  });

  it("falls back to default slug", () => {
    const all: Mosque[] = [
      makeMosque({ id: "a", name: "A", slug: "a" }),
      makeMosque({ id: "b", name: "B", slug: DEFAULT_MOSQUE_SLUG }),
    ];
    const resolved = resolveSelectedMosque(all, undefined, undefined);
    expect(resolved?.slug).toBe(DEFAULT_MOSQUE_SLUG);
  });

  it("falls back to first visible when default slug is absent", () => {
    const all: Mosque[] = [
      makeMosque({ id: "a", name: "A", slug: "a" }),
      makeMosque({ id: "b", name: "B", slug: "b" }),
    ];
    const resolved = resolveSelectedMosque(all, undefined, undefined);
    expect(resolved?.slug).toBe("a");
  });

  it("returns null when all are hidden", () => {
    const all: Mosque[] = [
      makeMosque({ id: "a", name: "A", slug: "a", isHidden: true }),
    ];
    expect(resolveSelectedMosque(all, undefined, undefined)).toBeNull();
  });
});
