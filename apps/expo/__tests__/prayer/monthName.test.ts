import { MONTH_NAMES, monthNameFromNumber } from "@/lib/prayer/monthName";

describe("MonthName", () => {
  it("MONTH_NAMES has 12 entries", () => {
    expect(MONTH_NAMES.length).toBe(12);
    expect(MONTH_NAMES[0]).toBe("january");
    expect(MONTH_NAMES[11]).toBe("december");
  });

  it("monthNameFromNumber returns correct month", () => {
    expect(monthNameFromNumber(1)).toBe("january");
    expect(monthNameFromNumber(12)).toBe("december");
  });

  it("monthNameFromNumber returns null for out-of-range", () => {
    expect(monthNameFromNumber(0)).toBeNull();
    expect(monthNameFromNumber(13)).toBeNull();
    expect(monthNameFromNumber(-1)).toBeNull();
  });
});
