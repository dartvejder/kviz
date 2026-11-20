// Veza sa Dart Chatom: Dart Chat pravi sobu i prati je, a igrači povezuju svoj Kviz nalog sa Matrix ID-jem.
// Token koji Dart Chat šalje je za Kviz neproziran: proverava ga Dart Chat dodatak (quiz/whoami).
import type { Igrac, Stanje } from "./igra";

export interface DartChatEnv {
  DB: D1Database;
  /** Adresa Dart Chat dodatka, npr. https://chat.dartchat.trade */
  DARTCHAT_URL?: string;
  /** Zajednička tajna sa Dart Chat dodatkom (quiz_api_key u Home Assistantu). */
  KVIZ_KLJUC?: string;
  /** "1" = prihvata i lažni token test:@ime:server, za testiranje bez Dart Chata. */
  DARTCHAT_TEST?: string;
}

export interface DartChatKorisnik {
  matrixId: string;
  ime: string;
}

export const MAX_POZVANIH = 29;
const MAX_TOKEN = 512;
const NAJDUZE_KESIRANJE = 3600;
const MATRIX_ID = /^@[a-z0-9._=\-/+]{1,255}:[a-z0-9.\-]{1,255}(:\d{1,5})?$/;

export const jeMatrixId = (x: unknown): x is string => typeof x === "string" && x.length <= 255 && MATRIX_ID.test(x);

/** Token iz "Authorization: DartChat <token>". */
export function tokenIzZaglavlja(auth: string | null): string | null {
  if (!auth?.startsWith("DartChat ")) return null;
  return ispravanToken(auth.slice(9).trim());
}

export function ispravanToken(x: unknown): string | null {
  if (typeof x !== "string") return null;
  const t = x.trim();
  return t.length > 0 && t.length <= MAX_TOKEN && !/[\s\u0000-\u001f]/.test(t) ? t : null;
}

/** Lažni token "test:@ime:server" važi samo kad je uključen test režim. */
export function testKorisnik(token: string, env: DartChatEnv): DartChatKorisnik | null {
  if (env.DARTCHAT_TEST !== "1" || !token.startsWith("test:")) return null;
  const matrixId = token.slice(5);
  if (!jeMatrixId(matrixId)) return null;
  return { matrixId, ime: matrixId.slice(1).split(":")[0] };
}

async function sha256(tekst: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(tekst));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export class DartChatGreska extends Error {
  constructor(
    poruka: string,
    readonly status: number,
  ) {
    super(poruka);
  }
}

/**
 * Ko je vlasnik tokena. Rezultat se pamti u D1 (po otisku tokena, ne po samom tokenu)
 * dok token važi, a najviše sat vremena, da kartice u Dart Chatu ne opterećuju kućni server.
 */
export async function proveriToken(token: string, env: DartChatEnv, f: typeof fetch = fetch): Promise<DartChatKorisnik> {
  const test = testKorisnik(token, env);
  if (test) return test;
  if (!env.DARTCHAT_URL || !env.KVIZ_KLJUC) throw new DartChatGreska("Veza sa Dart Chatom nije podešena.", 503);
  const hash = await sha256(token);
  const sad = Date.now();
  const red = await env.DB.prepare("SELECT matrix_id, ime FROM dartchat_tokeni WHERE hash = ? AND istice > ?")
    .bind(hash, sad)
    .first<{ matrix_id: string; ime: string }>();
  if (red) return { matrixId: red.matrix_id, ime: red.ime };

  let r: Response;
  try {
    r = await f(`${env.DARTCHAT_URL.replace(/\/+$/, "")}/_dartchat/v1/quiz/whoami`, {
      method: "POST",
      headers: { authorization: `Bearer ${env.KVIZ_KLJUC}`, "content-type": "application/json" },
      body: JSON.stringify({ openid_token: token }),
    });
  } catch {
    throw new DartChatGreska("Dart Chat se ne javlja.", 502);
  }
  if (r.status === 401 || r.status === 403) throw new DartChatGreska("Dart Chat prijava nije važeća.", 401);
  if (!r.ok) throw new DartChatGreska("Dart Chat se ne javlja.", 502);
  const j = (await r.json().catch(() => null)) as { matrix_id?: unknown; displayname?: unknown; expires_in?: unknown } | null;
  if (!j || !jeMatrixId(j.matrix_id)) throw new DartChatGreska("Dart Chat je vratio neispravan odgovor.", 502);
  const ime = imeIzDartChata(j.displayname, j.matrix_id);
  const traje = Math.min(NAJDUZE_KESIRANJE, Math.max(0, Math.floor(Number(j.expires_in) || 0)) || NAJDUZE_KESIRANJE);
  await env.DB.batch([
    env.DB.prepare("DELETE FROM dartchat_tokeni WHERE istice <= ?").bind(sad),
    env.DB.prepare("INSERT OR REPLACE INTO dartchat_tokeni (hash, matrix_id, ime, istice) VALUES (?, ?, ?, ?)").bind(
      hash,
      j.matrix_id,
      ime,
      sad + traje * 1000,
    ),
  ]);
  return { matrixId: j.matrix_id, ime };
}

/** Ime za predlog: Dart Chat ime, a ako ga nema, deo Matrix ID-ja pre dvotačke. Do 20 znakova kao u Kvizu. */
export function imeIzDartChata(displayname: unknown, matrixId: string): string {
  const d = typeof displayname === "string" ? displayname.replace(/[\u0000-\u001f]/g, "").trim() : "";
  return (d || matrixId.slice(1).split(":")[0]).slice(0, 20);
}

/** Telo za POST /api/dartchat/sobe, provereno. */
export function teloSobe(t: unknown):
  | { pozvani: string[]; chat: string | null; opcije: Record<string, unknown> | null }
  | { greska: string } {
  const o = (t && typeof t === "object" ? t : {}) as Record<string, unknown>;
  const pozvani = o.pozvani ?? [];
  if (!Array.isArray(pozvani)) return { greska: "pozvani mora biti spisak." };
  if (pozvani.length > MAX_POZVANIH) return { greska: `Najviše ${MAX_POZVANIH} pozvanih.` };
  if (!pozvani.every(jeMatrixId)) return { greska: "Neispravan Matrix ID u spisku pozvanih." };
  let chat: string | null = null;
  if (o.chat != null) {
    if (typeof o.chat !== "string" || !o.chat.startsWith("!") || o.chat.length > 255) return { greska: "Neispravan chat." };
    chat = o.chat;
  }
  const opcije = o.opcije && typeof o.opcije === "object" && !Array.isArray(o.opcije) ? (o.opcije as Record<string, unknown>) : null;
  return { pozvani: [...new Set(pozvani as string[])], chat, opcije };
}

export type DartChatFaza = "cekaonica" | "igra" | "kraj" | "istekla";

export function fazaZaDartChat(s: Pick<Stanje, "faza">): DartChatFaza {
  return s.faza === "cekaonica" ? "cekaonica" : s.faza === "kraj" ? "kraj" : "igra";
}

/** Poredak igrača poslednje partije: poeni, pa broj tačnih. */
export function poredak(igraci: Igrac[]) {
  return igraci
    .filter((i) => i.uIgri)
    .sort((a, b) => b.poeni - a.poeni || b.tacnih - a.tacnih)
    .map((i) => ({ matrix_id: i.matrix ?? null, ime: i.ime, poeni: i.poeni }));
}

const ISO = (ms: number) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z");

/** Ono što vidi kartica u Dart Chatu (GET /api/dartchat/sobe/KOD). */
export function stanjeZaDartChat(s: Stanje, zivotSobe: number) {
  const moderator = s.igraci.find((i) => i.id === s.moderatorId);
  const faza = fazaZaDartChat(s);
  return {
    kod: s.kod,
    faza,
    moderator: moderator?.matrix ?? s.dartchat?.moderator ?? null,
    opcije: { brojPitanja: s.opcije.brojPitanja, vreme: s.opcije.vreme, oblasti: s.opcije.oblasti },
    igraci: s.igraci.map((i) => ({
      ime: i.ime,
      avatar: i.avatar,
      matrix_id: i.matrix ?? null,
      spreman: i.spreman,
      uIgri: i.uIgri,
    })),
    pozvani: s.dartchat?.pozvani ?? [],
    poredak: faza === "kraj" ? poredak(s.igraci).slice(0, 3) : null,
    istice: ISO(s.napravljena + zivotSobe),
  };
}

export const istekla = (kod: string) => ({
  kod,
  faza: "istekla" as const,
  moderator: null,
  opcije: null,
  igraci: [],
  pozvani: [],
  poredak: null,
  istice: null,
});

export type Dogadjaj = "usao" | "pocelo" | "kraj" | "istekla";

/**
 * Javlja Dart Chatu šta se desilo u sobi (faza 2: Dart Bot objavljuje u grupi).
 * Tri pokušaja u roku od oko minut; igra nikad ne čeka na ovo.
 */
export async function javiDartChatu(
  env: DartChatEnv,
  telo: { kod: string; chat: string | null; dogadjaj: Dogadjaj; igrac?: string | null; ime?: string; poredak?: unknown },
  f: typeof fetch = fetch,
  cekaj: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<boolean> {
  if (!env.DARTCHAT_URL || !env.KVIZ_KLJUC) return false;
  const pauze = [0, 10_000, 40_000];
  for (const p of pauze) {
    if (p) await cekaj(p);
    try {
      const r = await f(`${env.DARTCHAT_URL.replace(/\/+$/, "")}/_dartchat/v1/quiz/status`, {
        method: "POST",
        headers: { authorization: `Bearer ${env.KVIZ_KLJUC}`, "content-type": "application/json" },
        body: JSON.stringify({ igrac: null, poredak: null, ...telo }),
      });
      if (r.ok) return true;
      if (r.status >= 400 && r.status < 500) return false; // ponavljanje ne pomaže
    } catch {
      // mreža; pokušava ponovo
    }
  }
  return false;
}
