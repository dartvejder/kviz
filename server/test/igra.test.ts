import { describe, expect, it } from "vitest";
import { bodujPitanje, ispravneOpcije, napraviPitanje, noviKod, KOD_REGEX, promesaj } from "../src/igra";
import { pocetakPerioda } from "../src/period";

describe("bodovanje", () => {
  it("tačan +3, najbrži tačan još +2, netačan −1", () => {
    const d = bodujPitanje(1, {
      a: { izbor: 1, vreme: 3000 },
      b: { izbor: 1, vreme: 1500 },
      c: { izbor: 0, vreme: 500 },
    });
    expect(d).toEqual({ a: 3, b: 5, c: -1 });
  });
  it("niko tačan: nema bonusa", () => {
    expect(bodujPitanje(2, { a: { izbor: 0, vreme: 1 } })).toEqual({ a: -1 });
  });
  it("bez odgovora nema promene", () => {
    expect(bodujPitanje(2, {})).toEqual({});
  });
});

describe("opcije", () => {
  it("ograničava vreme i broj pitanja i izbacuje nepoznate oblasti", () => {
    expect(ispravneOpcije({ vreme: 5, brojPitanja: 500, oblasti: ["Film", "X"] }, ["Film", "Sport"])).toEqual({
      vreme: 10,
      brojPitanja: 50,
      oblasti: ["Film"],
    });
  });
});

describe("pitanje", () => {
  it("tačan indeks prati mešanje", () => {
    for (let k = 0; k < 20; k++) {
      const p = napraviPitanje({ id: 1, oblast: "X", tekst: "?", tacan: "T", netacan1: "a", netacan2: "b", netacan3: "c" });
      expect(p.opcije[p.tacan]).toBe("T");
      expect([...p.opcije].sort()).toEqual(["T", "a", "b", "c"]);
    }
  });
  it("mešanje ne gubi elemente", () => {
    expect(promesaj([1, 2, 3, 4, 5]).sort()).toEqual([1, 2, 3, 4, 5]);
  });
});

describe("kod sobe", () => {
  it("6 znakova bez 0/O/1/I", () => {
    for (let k = 0; k < 50; k++) expect(noviKod()).toMatch(KOD_REGEX);
  });
});

describe("periodi top liste (Beograd)", () => {
  it("dan počinje u ponoć po beogradskom vremenu", () => {
    // 19.11.2026. 22:30 UTC = 23:30 u Beogradu (zimsko, UTC+1) → ponoć je 18.11. 23:00 UTC
    expect(pocetakPerioda("dan", Date.UTC(2026, 10, 19, 22, 30))).toBe(Date.UTC(2026, 10, 18, 23, 0));
    // 23:30 UTC = 00:30 sledećeg dana u Beogradu
    expect(pocetakPerioda("dan", Date.UTC(2026, 10, 19, 23, 30))).toBe(Date.UTC(2026, 10, 19, 23, 0));
  });
  it("nedelja počinje u ponedeljak", () => {
    // četvrtak 19.11.2026 → ponedeljak 16.11. 00:00 Beograd = 15.11. 23:00 UTC
    expect(pocetakPerioda("nedelja", Date.UTC(2026, 10, 19, 12))).toBe(Date.UTC(2026, 10, 15, 23, 0));
  });
  it("leto (UTC+2)", () => {
    expect(pocetakPerioda("dan", Date.UTC(2026, 6, 1, 12))).toBe(Date.UTC(2026, 5, 30, 22, 0));
  });
  it("sve = 0", () => expect(pocetakPerioda("sve")).toBe(0));
});
