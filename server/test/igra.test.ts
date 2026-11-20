import { describe, expect, it } from "vitest";
import { bodujPitanje, ispravneOpcije, napraviPitanje, noviKod, novoStanje, pregledPartije, zapamtiOdgovore, KOD_REGEX, promesaj } from "../src/igra";
import { juce, nizDana, pocetakPerioda } from "../src/period";

describe("bodovanje", () => {
  it("tačan +3, najbrži tačan još +1, netačan −1", () => {
    const d = bodujPitanje(1, {
      a: { izbor: 1, vreme: 3000 },
      b: { izbor: 1, vreme: 1500 },
      c: { izbor: 0, vreme: 500 },
    });
    expect(d).toEqual({ a: 3, b: 4, c: -1 });
  });
  it("niko tačan: nema bonusa", () => {
    expect(bodujPitanje(2, { a: { izbor: 0, vreme: 1 } })).toEqual({ a: -1 });
  });
  it("bez odgovora nema promene", () => {
    expect(bodujPitanje(2, {})).toEqual({});
  });
});

describe("opcije", () => {
  it("korak je 1 s: vreme 5–30, pauza 1–20, podrazumevano 20 i 5", () => {
    expect(ispravneOpcije({ vreme: 13, pauza: 1 } as never, [])).toMatchObject({ vreme: 13, pauza: 1 });
    expect(ispravneOpcije({ vreme: 99, pauza: 0 } as never, [])).toMatchObject({ vreme: 30, pauza: 1 });
    expect(ispravneOpcije({} as never, [])).toMatchObject({ vreme: 20, pauza: 5 });
  });
  it("ograničava vreme i broj pitanja i izbacuje nepoznate oblasti", () => {
    expect(ispravneOpcije({ vreme: 2, pauza: 50, brojPitanja: 500, oblasti: ["Film", "X"] }, ["Film", "Sport"])).toEqual({
      vreme: 5,
      pauza: 20,
      brojPitanja: 50,
      oblasti: ["Film"],
      dzokeri: true,
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

describe("džokeri i izazov", () => {
  it("dupli poeni duplaju i plus i minus", async () => {
    const { primeniDupli } = await import("../src/igra");
    expect(primeniDupli({ a: 4, b: -1, c: 3 }, { a: true, b: true })).toEqual({ a: 8, b: -2, c: 3 });
  });
  it("50:50 sklanja dva netačna", async () => {
    const { polaPola } = await import("../src/igra");
    for (let t = 0; t < 4; t++) {
      const s = polaPola(t);
      expect(s).toHaveLength(2);
      expect(s).not.toContain(t);
      expect(new Set(s).size).toBe(2);
    }
  });
  it("seme daje isti niz za isti dan", async () => {
    const { seme } = await import("../src/igra");
    const a = seme("2026-11-20"), b = seme("2026-11-20"), c = seme("2026-11-21");
    const x = [a(), a(), a()];
    expect([b(), b(), b()]).toEqual(x);
    expect(c()).not.toBe(x[0]);
  });
  it("u izazovu nema bonusa za brzinu", () => {
    expect(bodujPitanje(1, { a: { izbor: 1, vreme: 10 } }, false)).toEqual({ a: 3 });
  });
  it("današnji dan po beogradskom vremenu", async () => {
    const { danas } = await import("../src/period");
    expect(danas(Date.UTC(2026, 10, 19, 23, 30))).toBe("2026-11-20");
  });
});

describe("pregled sobe", () => {
  it("faza, broj igrača, moderator i da li sam u sobi", async () => {
    const { novoStanje, pregledSobe } = await import("../src/igra");
    const s = novoStanje("K7QX2M", "a", 1000);
    s.igraci = [
      { id: "a", ime: "Ana", avatar: "🦊", spreman: false, uIgri: true, poeni: 0, tacnih: 0 },
      { id: "b", ime: "Bojan", avatar: "🐼", spreman: false, uIgri: true, poeni: 0, tacnih: 0 },
    ];
    expect(pregledSobe(s, "b", 10)).toEqual({ kod: "K7QX2M", faza: "cekaonica", igraca: 2, moderator: "Ana", ja: true, istice: 1010 });
    s.faza = "otkriveno";
    expect(pregledSobe(s, "x", 10)).toMatchObject({ faza: "igra", ja: false });
  });
});

describe("pregled posle partije", () => {
  it("pamti izbor svakog igrača po pitanju, null kad nije odgovorio", () => {
    const s = novoStanje("ABCDEF", "a", 0);
    s.igraci = [
      { id: "a", ime: "A", avatar: "🦊", spreman: true, uIgri: true, poeni: 0, tacnih: 0 },
      { id: "b", ime: "B", avatar: "🐼", spreman: true, uIgri: true, poeni: 0, tacnih: 0 },
      { id: "c", ime: "C", avatar: "🐯", spreman: false, uIgri: false, poeni: 0, tacnih: 0 },
    ];
    s.pitanja = [
      { id: 7, oblast: "Istorija", tekst: "P1", opcije: ["a", "b", "c", "d"], tacan: 2 },
      { id: 9, oblast: "Sport", tekst: "P2", opcije: ["a", "b", "c", "d"], tacan: 0 },
    ];
    s.trenutno = 0;
    s.odgovori = { a: { izbor: 2, vreme: 1 } };
    zapamtiOdgovore(s);
    s.trenutno = 1;
    s.odgovori = { a: { izbor: 1, vreme: 1 }, b: { izbor: 0, vreme: 1 } };
    zapamtiOdgovore(s);
    const p = pregledPartije(s);
    expect(p).toHaveLength(2);
    expect(p[0]).toMatchObject({ id: 7, tacan: 2, odgovori: { a: 2, b: null } });
    expect(p[1].odgovori).toEqual({ a: 1, b: 0 });
    expect("c" in p[0].odgovori).toBe(false);
  });
});

describe("niz dana izazova", () => {
  it("broji dane zaredom od danas ili od juče", () => {
    expect(nizDana(["2026-11-20", "2026-11-19", "2026-11-18", "2026-11-16"], "2026-11-20")).toEqual({ niz: 3, danas: true });
    expect(nizDana(["2026-11-19", "2026-11-18"], "2026-11-20")).toEqual({ niz: 2, danas: false });
    expect(nizDana(["2026-11-18"], "2026-11-20")).toEqual({ niz: 0, danas: false });
    expect(nizDana(["2026-03-01", "2026-02-28"], "2026-03-01")).toEqual({ niz: 2, danas: true });
    expect(juce("2026-01-01")).toBe("2025-12-31");
  });
});
