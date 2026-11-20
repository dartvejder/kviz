// Prijava preko Google ili Apple naloga (opciona): proverava ID token (JWT, RS256) po javnim ključevima
// provajdera. Nalog za igru ostaje Kviz nalog; Google/Apple nalog ga samo čuva i vraća na novom telefonu.

export type Provajder = "google" | "apple";

export interface PrijavaEnv {
  /** Google OAuth client ID-jevi (web, iOS), odvojeni zarezom; aud u tokenu mora biti jedan od njih. */
  GOOGLE_CLIENT_IDS?: string;
  /** Apple: bundle ID aplikacije (aud u tokenu). */
  APPLE_AUDIENCE?: string;
}

export interface Identitet {
  provajder: Provajder;
  /** Stalni ID korisnika kod provajdera (sub). */
  sub: string;
  /** Ime iz Google naloga, kao predlog (Apple ga ne šalje u tokenu). */
  ime: string | null;
}

export class PrijavaGreska extends Error {
  constructor(
    poruka: string,
    readonly status = 401,
  ) {
    super(poruka);
  }
}

const PROVAJDERI: Record<Provajder, { kljucevi: string; izdavaci: string[] }> = {
  google: {
    kljucevi: "https://www.googleapis.com/oauth2/v3/certs",
    izdavaci: ["https://accounts.google.com", "accounts.google.com"],
  },
  apple: { kljucevi: "https://appleid.apple.com/auth/keys", izdavaci: ["https://appleid.apple.com"] },
};

export function publike(env: PrijavaEnv, p: Provajder): string[] {
  const sirovo = p === "google" ? env.GOOGLE_CLIENT_IDS : env.APPLE_AUDIENCE;
  return (sirovo ?? "")
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean);
}

function base64url(tekst: string): Uint8Array {
  const b = atob(tekst.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((tekst.length + 3) % 4));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}

type Jwk = JsonWebKey & { kid?: string };

/** Ključevi provajdera se drže u memoriji sat vremena. */
const kes = new Map<string, { do: number; kljucevi: Jwk[] }>();

async function kljuceviProvajdera(adresa: string, f: typeof fetch, sad: number): Promise<Jwk[]> {
  const k = kes.get(adresa);
  if (k && k.do > sad) return k.kljucevi;
  const r = await f(adresa);
  if (!r.ok) throw new PrijavaGreska("Provera prijave trenutno ne radi. Pokušaj ponovo.", 503);
  const { keys } = (await r.json()) as { keys: Jwk[] };
  kes.set(adresa, { do: sad + 3600_000, kljucevi: keys });
  return keys;
}

/** Proverava ID token i vraća identitet. Baca PrijavaGreska ako token ne važi. */
export async function proveriIdToken(
  provajder: Provajder,
  token: string,
  env: PrijavaEnv,
  f: typeof fetch = fetch,
  sad = Date.now(),
): Promise<Identitet> {
  const aud = publike(env, provajder);
  if (!aud.length) throw new PrijavaGreska("Prijava preko ovog naloga još nije uključena.", 503);
  const delovi = token.split(".");
  if (delovi.length !== 3) throw new PrijavaGreska("Neispravna prijava.");
  let zaglavlje: { alg?: string; kid?: string };
  let telo: { iss?: string; aud?: string | string[]; exp?: number; iat?: number; sub?: string; name?: string };
  try {
    zaglavlje = JSON.parse(new TextDecoder().decode(base64url(delovi[0])));
    telo = JSON.parse(new TextDecoder().decode(base64url(delovi[1])));
  } catch {
    throw new PrijavaGreska("Neispravna prijava.");
  }
  if (zaglavlje.alg !== "RS256" || !zaglavlje.kid) throw new PrijavaGreska("Neispravna prijava.");
  const p = PROVAJDERI[provajder];
  const kljucevi = await kljuceviProvajdera(p.kljucevi, f, sad);
  const jwk = kljucevi.find((k) => k.kid === zaglavlje.kid);
  if (!jwk) {
    kes.delete(p.kljucevi);
    throw new PrijavaGreska("Prijava je istekla. Pokušaj ponovo.");
  }
  const kljuc = await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const ispravan = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    kljuc,
    base64url(delovi[2]),
    new TextEncoder().encode(`${delovi[0]}.${delovi[1]}`),
  );
  if (!ispravan) throw new PrijavaGreska("Neispravna prijava.");
  const sekunde = Math.floor(sad / 1000);
  const audovi = Array.isArray(telo.aud) ? telo.aud : [telo.aud];
  if (!telo.iss || !p.izdavaci.includes(telo.iss)) throw new PrijavaGreska("Neispravna prijava.");
  if (!audovi.some((a) => a && aud.includes(a))) throw new PrijavaGreska("Prijava nije za ovu aplikaciju.");
  if (!telo.exp || telo.exp + 60 < sekunde) throw new PrijavaGreska("Prijava je istekla. Pokušaj ponovo.");
  if (!telo.sub || typeof telo.sub !== "string" || telo.sub.length > 255) throw new PrijavaGreska("Neispravna prijava.");
  const ime = typeof telo.name === "string" ? telo.name.trim().slice(0, 20) || null : null;
  return { provajder, sub: telo.sub, ime };
}
