// Čista logika igre, bez Cloudflare API-ja, da može da se testira.

export const BODOVI = { tacan: 3, najbrzi: 2, netacan: -1 } as const;

export type Faza = "cekaonica" | "pitanje" | "otkriveno" | "kraj";

export interface Opcije {
  vreme: number; // sekundi po pitanju, 10–60
  brojPitanja: number; // 5–50
  oblasti: string[]; // prazno = sve oblasti
}

export const PODRAZUMEVANE_OPCIJE: Opcije = { vreme: 20, brojPitanja: 10, oblasti: [] };

export interface Igrac {
  id: string;
  ime: string;
  avatar: string;
  spreman: boolean;
  uIgri: boolean; // igra trenutnu partiju (kasnilci čekaju revanš)
  poeni: number;
  tacnih: number;
}

export interface Pitanje {
  id: number;
  oblast: string;
  tekst: string;
  opcije: string[]; // izmešane
  tacan: number; // indeks tačne u opcije
}

export interface Odgovor {
  izbor: number;
  vreme: number; // ms od početka pitanja
}

export interface Stanje {
  kod: string;
  moderatorId: string;
  napravljena: number;
  faza: Faza;
  opcije: Opcije;
  igraci: Igrac[];
  pitanja: Pitanje[];
  trenutno: number; // indeks pitanja
  pocetakPitanja: number; // epoch ms
  krajPitanja: number; // epoch ms
  odgovori: Record<string, Odgovor>;
  poslednjiPoeni: Record<string, number>; // za prikaz posle otkrivanja
  pocetakIgre: number;
  prozivkaDo: number; // 0 = nema prozivke
}

export function novoStanje(kod: string, moderatorId: string, sad: number): Stanje {
  return {
    kod,
    moderatorId,
    napravljena: sad,
    faza: "cekaonica",
    opcije: { ...PODRAZUMEVANE_OPCIJE },
    igraci: [],
    pitanja: [],
    trenutno: 0,
    pocetakPitanja: 0,
    krajPitanja: 0,
    odgovori: {},
    poslednjiPoeni: {},
    pocetakIgre: 0,
    prozivkaDo: 0,
  };
}

export function ispravneOpcije(o: Partial<Opcije>, sveOblasti: string[]): Opcije {
  const vreme = Math.round(Number(o.vreme));
  const broj = Math.round(Number(o.brojPitanja));
  const oblasti = Array.isArray(o.oblasti) ? o.oblasti.filter((x) => sveOblasti.includes(x)) : [];
  return {
    vreme: Number.isFinite(vreme) ? Math.min(60, Math.max(10, vreme)) : PODRAZUMEVANE_OPCIJE.vreme,
    brojPitanja: Number.isFinite(broj) ? Math.min(50, Math.max(5, broj)) : PODRAZUMEVANE_OPCIJE.brojPitanja,
    oblasti: [...new Set(oblasti)],
  };
}

/** Fisher–Yates; rnd vraća [0,1). */
export function promesaj<T>(niz: T[], rnd: () => number = Math.random): T[] {
  const a = niz.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function napraviPitanje(
  red: { id: number; oblast: string; tekst: string; tacan: string; netacan1: string; netacan2: string; netacan3: string },
  rnd: () => number = Math.random,
): Pitanje {
  const opcije = promesaj([red.tacan, red.netacan1, red.netacan2, red.netacan3], rnd);
  return { id: red.id, oblast: red.oblast, tekst: red.tekst, opcije, tacan: opcije.indexOf(red.tacan) };
}

/**
 * Bodovanje jednog pitanja: tačan +3, najbrži tačan još +2, netačan −1,
 * bez odgovora 0. Vraća promenu poena po igraču.
 */
export function bodujPitanje(tacan: number, odgovori: Record<string, Odgovor>): Record<string, number> {
  const delta: Record<string, number> = {};
  let najbrzi: string | null = null;
  let najbrzeVreme = Infinity;
  for (const [id, o] of Object.entries(odgovori)) {
    if (o.izbor === tacan) {
      delta[id] = BODOVI.tacan;
      if (o.vreme < najbrzeVreme) {
        najbrzeVreme = o.vreme;
        najbrzi = id;
      }
    } else {
      delta[id] = BODOVI.netacan;
    }
  }
  if (najbrzi) delta[najbrzi] += BODOVI.najbrzi;
  return delta;
}

export function svePrimljeno(s: Stanje): boolean {
  return s.igraci.filter((i) => i.uIgri).every((i) => i.id in s.odgovori);
}

const SLOVA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export function noviKod(rnd: () => number = Math.random): string {
  let k = "";
  for (let i = 0; i < 6; i++) k += SLOVA[Math.floor(rnd() * SLOVA.length)];
  return k;
}
export const KOD_REGEX = /^[A-HJ-NP-Z2-9]{6}$/;
