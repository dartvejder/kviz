// Jutarnji push (FCM) sa jučerašnjim rezultatom dnevnog izazova.
// Šalje ga Cron okidač u 8:00 po beogradskom vremenu. Ključ servisnog naloga Firebase-a je
// tajna FCM_SERVIS u Cloudflare-u; bez nje se ništa ne šalje.
import { danas } from "./period";

export interface PushEnv {
  DB: D1Database;
  /** JSON servisnog naloga iz Firebase-a (Project settings > Service accounts). */
  FCM_SERVIS?: string;
}

export const PLATFORME = ["android", "ios"] as const;
const MAX_TOKEN = 4096;

export function ispravanPushToken(x: unknown): string | null {
  if (typeof x !== "string") return null;
  const t = x.trim();
  return t.length >= 20 && t.length <= MAX_TOKEN && /^[\w:.\-]+$/.test(t) ? t : null;
}

/** Sat po beogradskom vremenu (0–23). */
export function satUBeogradu(sad = Date.now()): number {
  return +new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Belgrade", hour: "2-digit", hourCycle: "h23" }).format(new Date(sad));
}

/** Jučerašnji dan po beogradskom vremenu (pozvano ujutru, pa je razmak od 24 h siguran i oko pomeranja sata). */
export function juce(sad = Date.now()): string {
  return danas(sad - 24 * 60 * 60 * 1000);
}

export interface RedIzazova {
  igrac_id: string;
  ime: string;
  poeni: number;
  kraj: number;
}

/** Mesto svakog igrača, kao na top listi: više poena, pa ranije završeno. Isti rezultat = isto mesto. */
export function mesta(redovi: RedIzazova[]): Map<string, number> {
  const s = [...redovi].sort((a, b) => b.poeni - a.poeni || a.kraj - b.kraj);
  const m = new Map<string, number>();
  s.forEach((r, i) => {
    const p = s[i - 1];
    m.set(r.igrac_id, p && p.poeni === r.poeni && p.kraj === r.kraj ? m.get(p.igrac_id)! : i + 1);
  });
  return m;
}

export function poena(n: number): string {
  const a = Math.abs(n);
  return `${n} ${a % 10 === 1 && a % 100 !== 11 ? "poen" : "poena"}`;
}

/** Tekst push poruke za jednog igrača. */
export function tekstPoruke(mesto: number, ukupno: number, poeni: number, pobednik: string): { naslov: string; tekst: string } {
  const novi = "Novi izazov te čeka!";
  if (ukupno === 1) return { naslov: "Dnevni izazov", tekst: `Juče: jedini igrač izazova, ${poena(poeni)}. ${novi}` };
  if (mesto === 1) return { naslov: "🏆 Pobeda u dnevnom izazovu!", tekst: `Juče: 1. mesto od ${ukupno}, ${poena(poeni)}. ${novi}` };
  return { naslov: "Dnevni izazov", tekst: `Juče: ${mesto}. mesto od ${ukupno}, ${poena(poeni)}. Pobednik: ${pobednik}. ${novi}` };
}

// --- FCM HTTP v1 ---

interface Servis {
  project_id: string;
  client_email: string;
  private_key: string;
}

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
  const bajtovi = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = "";
  for (const x of bajtovi) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function pristupniToken(sv: Servis, f: typeof fetch): Promise<string> {
  const sad = Math.floor(Date.now() / 1000);
  const zaglavlje = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const telo = b64url(
    JSON.stringify({
      iss: sv.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: sad,
      exp: sad + 3600,
    }),
  );
  const pem = sv.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const kljuc = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const potpis = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", kljuc, new TextEncoder().encode(`${zaglavlje}.${telo}`));
  const r = await f("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${zaglavlje}.${telo}.${b64url(potpis)}`,
    }),
  });
  if (!r.ok) throw new Error(`Google token: ${r.status} ${await r.text()}`);
  return ((await r.json()) as { access_token: string }).access_token;
}

/** Šalje jednu poruku; vraća "ok", "nevazeci" (token treba obrisati) ili "greska". */
async function posalji(
  sv: Servis,
  pristup: string,
  token: string,
  p: { naslov: string; tekst: string },
  f: typeof fetch,
): Promise<"ok" | "nevazeci" | "greska"> {
  const r = await f(`https://fcm.googleapis.com/v1/projects/${sv.project_id}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${pristup}`, "content-type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: p.naslov, body: p.tekst },
        data: { tip: "izazov" },
        android: { priority: "high", notification: { channel_id: "izazov", tag: "izazov" } },
        apns: { payload: { aps: { sound: "default", "thread-id": "izazov" } } },
      },
    }),
  });
  if (r.ok) return "ok";
  const t = await r.text();
  if (r.status === 404 || /UNREGISTERED|INVALID_ARGUMENT.*registration/i.test(t)) return "nevazeci";
  console.log("FCM", r.status, t.slice(0, 300));
  return "greska";
}

/**
 * Jutarnja poruka svima koji su juče završili izazov i imaju push ključ.
 * Samo čita bazu; briše jedino ključeve koje FCM proglasi nevažećim.
 */
export async function jutarnjiPush(env: PushEnv, sad = Date.now(), f: typeof fetch = fetch): Promise<{ poslato: number; nevazecih: number }> {
  if (!env.FCM_SERVIS) {
    console.log("FCM_SERVIS nije podešen, push se ne šalje.");
    return { poslato: 0, nevazecih: 0 };
  }
  const sv = JSON.parse(env.FCM_SERVIS) as Servis;
  const dan = juce(sad);
  const [igraci, kljucevi] = await env.DB.batch([
    env.DB.prepare(
      "SELECT z.igrac_id, i.ime, z.poeni, z.kraj FROM izazov z JOIN igraci i ON i.id = z.igrac_id WHERE z.dan = ? AND z.kraj > 0",
    ).bind(dan),
    env.DB.prepare(
      "SELECT p.token, p.igrac_id FROM push_kljucevi p WHERE p.igrac_id IN (SELECT igrac_id FROM izazov WHERE dan = ? AND kraj > 0)",
    ).bind(dan),
  ]);
  const redovi = igraci.results as unknown as RedIzazova[];
  const tokeni = kljucevi.results as unknown as { token: string; igrac_id: string }[];
  if (!redovi.length || !tokeni.length) return { poslato: 0, nevazecih: 0 };

  const m = mesta(redovi);
  const poId = new Map(redovi.map((r) => [r.igrac_id, r]));
  const pobednik = redovi.find((r) => m.get(r.igrac_id) === 1)!.ime;
  const pristup = await pristupniToken(sv, f);

  let poslato = 0;
  const nevazeci: string[] = [];
  // Po 20 istovremeno, da Worker ne otvori previše veza odjednom.
  for (let i = 0; i < tokeni.length; i += 20) {
    const deo = tokeni.slice(i, i + 20);
    const ishodi = await Promise.all(
      deo.map((k) => {
        const r = poId.get(k.igrac_id)!;
        return posalji(sv, pristup, k.token, tekstPoruke(m.get(r.igrac_id)!, redovi.length, r.poeni, pobednik), f);
      }),
    );
    ishodi.forEach((x, j) => {
      if (x === "ok") poslato++;
      if (x === "nevazeci") nevazeci.push(deo[j].token);
    });
  }
  if (nevazeci.length) {
    await env.DB.batch(nevazeci.map((t) => env.DB.prepare("DELETE FROM push_kljucevi WHERE token = ?").bind(t)));
  }
  console.log(`Jutarnji push za ${dan}: poslato ${poslato}, nevažećih ključeva ${nevazeci.length}.`);
  return { poslato, nevazecih: nevazeci.length };
}
