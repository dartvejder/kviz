import { describe, expect, it } from "vitest";
import { minVerzija } from "../src/verzija";

describe("najmanja verzija", () => {
  it("čita promenljive, a bez njih je 0 (nema obaveznog ažuriranja)", () => {
    expect(minVerzija({}).android.min).toBe(0);
    expect(minVerzija({ MIN_ANDROID: "2030", MIN_IOS: "5" })).toMatchObject({ android: { min: 2030 }, ios: { min: 5 } });
    expect(minVerzija({ MIN_ANDROID: "abc", MIN_IOS: "-3" })).toMatchObject({ android: { min: 0 }, ios: { min: 0 } });
    expect(minVerzija({}).ios.prodavnica).toMatch(/^https:\/\/testflight\.apple\.com\//);
  });
});
