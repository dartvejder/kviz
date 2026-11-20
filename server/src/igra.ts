// Čista logika igre, bez Cloudflare API-ja, da može da se testira.

export const BODOVI = { tacan: 3, najbrzi: 1, netacan: -1 } as const;

export type Faza = "cekaonica" | "pitanje" | "otkriveno" | "kraj";

export interface Opcije {
  vreme: number; // sekundi po pitanju, 5–30
  pauza: number; // sekundi između pitanja (posle otkrivanja), 1–20
  brojPitanja: number; // 5–50
  oblasti: string[]; // prazno = sve oblasti
  dzokeri: boolean; // 50:50 i Dupli poeni, po jednom u partiji
}

export const PODRAZUMEVANE_OPCIJE: Opcije = { vreme: 20, pauza: 5, brojPitanja: 10, oblasti: [], dzokeri: true };

export interface Igrac {
  id: string;
  ime: string;
  avatar: string;
  spreman: boolean;
  uIgri: boolean; // igra trenutnu partiju (kasnilci čekaju revanš)
  poeni: number;
  tacnih: number;
  /** Iskorišćeni džokeri u ovoj partiji. */
  dzokeri?: { pola?: boolean; dupli?: boolean };
  /** Po oblasti: [tačnih, pitanja] u ovoj partiji, za statistiku. */
  poOblasti?: Record<string, [number, number]>;
  /** Matrix ID, ako je igrač povezao Dart Chat. */
  matrix?: string;
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
  /** Ko je na trenutnom pitanju uključio Dupli poeni. */
  dupli?: Record<string, true>;
  /** Dnevni izazov: dan "2026-11-20" (beogradsko vreme); samo tvorac igra. */
  izazov?: string;
  /** Soba napravljena iz Dart Chata. */
  dartchat?: {
    /** Matrix ID pozivara: njegov Kviz nalog postaje moderator kad uđe. */
    moderator: string;
    pozvani: string[];
    /** Matrix soba iz koje je poziv poslat; samo se vraća u događajima. */
    chat: string | null;
  };
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
  const pauza = Math.round(Number(o.pauza));
  const broj = Math.round(Number(o.brojPitanja));
  const oblasti = Array.isArray(o.oblasti) ? o.oblasti.filter((x) => sveOblasti.includes(x)) : [];
  return {
    vreme: Number.isFinite(vreme) ? Math.min(30, Math.max(5, vreme)) : PODRAZUMEVANE_OPCIJE.vreme,
    pauza: Number.isFinite(pauza) ? Math.min(20, Math.max(1, pauza)) : PODRAZUMEVANE_OPCIJE.pauza,
    brojPitanja: Number.isFinite(broj) ? Math.min(50, Math.max(5, broj)) : PODRAZUMEVANE_OPCIJE.brojPitanja,
    oblasti: [...new Set(oblasti)],
    dzokeri: o.dzokeri !== false,
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
 * Bodovanje jednog pitanja: tačan +3, najbrži tačan još +1, netačan −1,
 * bez odgovora 0. Vraća promenu poena po igraču.
 */
export function bodujPitanje(
  tacan: number,
  odgovori: Record<string, Odgovor>,
  bonus = true,
): Record<string, number> {
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
  if (najbrzi && bonus) delta[najbrzi] += BODOVI.najbrzi;
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

/** Dupli poeni: promena poena (i plus i minus) se duplira za one koji su ga uključili. */
export function primeniDupli(delta: Record<string, number>, dupli: Record<string, true> = {}): Record<string, number> {
  return Object.fromEntries(Object.entries(delta).map(([id, d]) => [id, id in dupli ? d * 2 : d]));
}

/** 50:50: dva nasumična netačna odgovora koja se sklanjaju. */
export function polaPola(tacan: number, rnd: () => number = Math.random): number[] {
  return promesaj([0, 1, 2, 3].filter((i) => i !== tacan), rnd).slice(0, 2).sort();
}

/** Ponovljiv generator brojeva [0,1) iz semena (mulberry32). */
export function seme(tekst: string): () => number {
  let h = 1779033703 ^ tekst.length;
  for (let i = 0; i < tekst.length; i++) {
    h = Math.imul(h ^ tekst.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = h >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Dnevni izazov: 10 pitanja, 15 s, pauza 3 s, bez džokera, isto za sve. */
export const IZAZOV_OPCIJE: Opcije = { vreme: 15, pauza: 3, brojPitanja: 10, oblasti: [], dzokeri: false };

export const REAKCIJE = ["👏", "😂", "😮", "🔥", "😅", "👍"];
