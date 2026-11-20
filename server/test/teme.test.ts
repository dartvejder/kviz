import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { PODRAZUMEVANA, TEME, spisakTema, tema } from "../src/teme";

const BOJA = /^#[0-9a-f]{6}([0-9a-f]{2})?$/i;

function boje(x: unknown, put: string, greske: string[]) {
  if (typeof x === "string" && x.startsWith("#") && !BOJA.test(x)) greske.push(`${put}: ${x}`);
  else if (Array.isArray(x)) x.forEach((y, i) => boje(y, `${put}[${i}]`, greske));
  else if (x && typeof x === "object") for (const [k, v] of Object.entries(x)) boje(v, `${put}.${k}`, greske);
}

describe("teme", () => {
  it("ima 10 tema, jedinstveni id, Studio je podrazumevana", () => {
    expect(TEME).toHaveLength(10);
    expect(new Set(TEME.map((t) => t.id)).size).toBe(10);
    expect(PODRAZUMEVANA).toBe("studio");
    expect(TEME[0].id).toBe("studio");
  });
  it("sve boje su #RRGGBB ili #RRGGBBAA", () => {
    const g: string[] = [];
    boje(TEME, "TEME", g);
    expect(g).toEqual([]);
  });
  it("gradijenti imaju stopove koliko i boja", () => {
    for (const t of TEME)
      for (const s of t.pozadina.slojevi) if (s.stopovi) expect(s.stopovi.length, t.id).toBe(s.boje.length);
  });
  it("mreža odgovora ima četiri boje", () => {
    for (const t of TEME) if (t.odgovori === "mreza") expect(t.bojeOdgovora).toHaveLength(4);
  });
  it("verzija se menja kad se tema promeni", async () => {
    const a = (await tema("studio"))!.verzija;
    const s = await spisakTema();
    expect(s.teme.find((x) => x.id === "studio")!.verzija).toBe(a);
    const stara = TEME[0].boje.primarna;
    TEME[0].boje.primarna = "#000000";
    expect((await tema("studio"))!.verzija).not.toBe(a);
    TEME[0].boje.primarna = stara;
    expect(await tema("nema")).toBeNull();
  });
});

describe("ugrađena tema u aplikaciji", () => {
  it("app/assets/tema-studio.json je ista kao Studio na serveru (npm run tema-studio)", async () => {
    const ugradjena = JSON.parse(readFileSync(new URL("../../app/assets/tema-studio.json", import.meta.url), "utf8"));
    expect(ugradjena).toEqual(await tema("studio"));
  });
});
