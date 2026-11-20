import { describe, expect, it } from "vitest";
import { stranicaPozivnice, wellKnown } from "../src/pozivnica";

describe("pozivnice", () => {
  it("assetlinks navodi paket i oba otiska", async () => {
    const r = wellKnown("/.well-known/assetlinks.json")!;
    const j = (await r.json()) as any[];
    expect(j[0].target.package_name).toBe("rs.kviz.app");
    expect(j[0].target.sha256_cert_fingerprints).toHaveLength(2);
  });
  it("AASA otvara /i/*", async () => {
    const j = (await wellKnown("/.well-known/apple-app-site-association")!.json()) as any;
    expect(j.applinks.details[0].appIDs[0]).toBe("R3UC6PN8CF.rs.kviz.app");
  });
  it("stranica prikazuje kod velikim slovima", async () => {
    const r = stranicaPozivnice("/i/k7qx2m")!;
    expect(await r.text()).toContain("K7QX2M");
  });
  it("loš kod nije stranica", () => {
    expect(stranicaPozivnice("/i/<b>xx")).toBeNull();
    expect(stranicaPozivnice("/i/IIIIII")).toBeNull();
  });
});
