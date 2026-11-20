// Kviz server: HTTP API (/api) i WebSocket za sobe (/ws/KOD).
import { KOD_REGEX, noviKod } from "./igra";
import { minVerzija } from "./verzija";
import { danas, pocetakPerioda } from "./period";
import {
  DartChatGreska,
  istekla,
  proveriToken,
  ispravanToken,
  teloSobe,
  tokenIzZaglavlja,
  type DartChatEnv,
  type DartChatKorisnik,
} from "./dartchat";
import { stranicaPozivnice, wellKnown } from "./pozivnica";
import { spisakTema, tema } from "./teme";
import { ispravanPushToken, jutarnjiPush, PLATFORME, satUBeogradu, type PushEnv } from "./push";

export { Soba } from "./soba";

export interface Env extends DartChatEnv, PushEnv {
  DB: D1Database;
  SOBA: DurableObjectNamespace;
  /** Najmanji build aplikacije koji sme da igra (Cloudflare promenljive, menjaju se bez postavljanja). */
  MIN_ANDROID?: string;
  MIN_IOS?: string;
}

const ZIVOT_SOBE = 24 * 60 * 60 * 1000;

const AVATARI = [
  "🦊", "🐼", "🐯", "🦁", "🐸", "🐵", "🐨", "🐙", "🦄", "🐲", "🦉", "🐧", "🐢",
  "🦖", "🐝", "🐬", "🦀", "🐺", "🐮", "🐷", "🦋", "🐞", "🐻", "🐰", "🦒",
];

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*" },
  });

const greska = (poruka: string, status: number) => json({ greska: poruka }, status);

async function sha256(tekst: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(tekst));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function cistoIme(x: unknown): string | null {
  if (typeof x !== "string") return null;
  const ime = x.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 20);
  return ime.length ? ime : null;
}

interface IgracRed {
  id: string;
  ime: string;
  avatar: string;
}

/** Igrač iz "Authorization: Bearer ID.TOKEN" ili iz ?id=&token= (za WebSocket). */
async function prijavljen(req: Request, env: Env): Promise<IgracRed | null> {
  const url = new URL(req.url);
  let id = url.searchParams.get("id");
  let token = url.searchParams.get("token");
  const auth = req.headers.get("authorization");
  if (auth?.startsWith("Bearer ")) [id, token] = auth.slice(7).split(".");
  if (!id || !token) return null;
  const red = await env.DB.prepare("SELECT id, ime, avatar, token_hash FROM igraci WHERE id = ?")
    .bind(id)
    .first<IgracRed & { token_hash: string }>();
  if (!red || red.token_hash !== (await sha256(token))) return null;
  return { id: red.id, ime: red.ime, avatar: red.avatar };
}

/** Dart Chat korisnik iz "Authorization: DartChat <token>", ili odgovor sa greškom. */
async function dartChatKorisnik(req: Request, env: Env): Promise<DartChatKorisnik | Response> {
  const token = tokenIzZaglavlja(req.headers.get("authorization"));
  if (!token) return greska("Nedostaje Dart Chat prijava.", 401);
  return proveriToken(token, env).catch((e) => {
    if (e instanceof DartChatGreska) return greska(e.message, e.status);
    throw e;
  });
}

async function novaSoba(
  env: Env,
  init: { moderatorId: string; izazov?: string; dartchat?: unknown; opcije?: unknown },
): Promise<string | null> {
  for (let pokusaj = 0; pokusaj < 5; pokusaj++) {
    const kod = noviKod();
    const soba = env.SOBA.get(env.SOBA.idFromName(kod));
    const r = await soba.fetch("https://soba/init", { method: "POST", body: JSON.stringify({ kod, ...init }) });
    if (r.ok) return kod;
  }
  return null;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const put = url.pathname;
    const staticno = wellKnown(put) ?? (req.method === "GET" ? stranicaPozivnice(put) : null);
    if (staticno) return staticno;

    if (req.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, POST, PUT, DELETE",
          "access-control-allow-headers": "authorization, content-type",
        },
      });
    }

    // Novi igrač: vraća id i token koje aplikacija čuva.
    if (put === "/api/igraci" && req.method === "POST") {
      const telo = (await req.json().catch(() => ({}))) as { ime?: unknown; avatar?: unknown };
      const ime = cistoIme(telo.ime);
      if (!ime) return greska("Upiši ime.", 400);
      const avatar = AVATARI.includes(telo.avatar as string) ? (telo.avatar as string) : AVATARI[0];
      const id = crypto.randomUUID();
      const token = [...crypto.getRandomValues(new Uint8Array(24))].map((b) => b.toString(16).padStart(2, "0")).join("");
      await env.DB.prepare("INSERT INTO igraci (id, token_hash, ime, avatar, napravljen) VALUES (?, ?, ?, ?, ?)")
        .bind(id, await sha256(token), ime, avatar, Date.now())
        .run();
      return json({ id, token, ime, avatar }, 201);
    }

    if (put === "/api/igraci/ja") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      if (req.method === "GET") return json(ja);
      if (req.method === "PUT") {
        const telo = (await req.json().catch(() => ({}))) as { ime?: unknown; avatar?: unknown };
        const ime = cistoIme(telo.ime) ?? ja.ime;
        const avatar = AVATARI.includes(telo.avatar as string) ? (telo.avatar as string) : ja.avatar;
        await env.DB.prepare("UPDATE igraci SET ime = ?, avatar = ? WHERE id = ?").bind(ime, avatar, ja.id).run();
        return json({ ...ja, ime, avatar });
      }
      // "Obriši nalog" (traže Google Play i App Store).
      if (req.method === "DELETE") {
        await env.DB.batch([
          env.DB.prepare("DELETE FROM rezultati WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM odigrano WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM statistika WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM izazov WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM dartchat_veze WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM push_kljucevi WHERE igrac_id = ?").bind(ja.id),
          env.DB.prepare("DELETE FROM igraci WHERE id = ?").bind(ja.id),
        ]);
        return json({ obrisan: true });
      }
    }

    // Push ključ telefona (FCM): POST ga prijavljuje, DELETE odjavljuje (isključen push ili odjava).
    if (put === "/api/push" && (req.method === "POST" || req.method === "DELETE")) {
      const telo = (await req.json().catch(() => ({}))) as { token?: unknown; platforma?: unknown };
      const token = ispravanPushToken(telo.token);
      if (!token) return greska("Neispravan push ključ.", 400);
      if (req.method === "DELETE") {
        await env.DB.prepare("DELETE FROM push_kljucevi WHERE token = ?").bind(token).run();
        return json({ ok: true });
      }
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const platforma = PLATFORME.includes(telo.platforma as (typeof PLATFORME)[number]) ? (telo.platforma as string) : "android";
      const sad = Date.now();
      // Upis samo kad je ključ nov, prešao na drugi nalog, ili nije osvežen nedelju dana.
      await env.DB.prepare(
        `INSERT INTO push_kljucevi (token, igrac_id, platforma, azuriran) VALUES (?, ?, ?, ?)
         ON CONFLICT(token) DO UPDATE SET igrac_id = excluded.igrac_id, platforma = excluded.platforma, azuriran = excluded.azuriran
         WHERE push_kljucevi.igrac_id != excluded.igrac_id OR push_kljucevi.azuriran < ?`,
      )
        .bind(token, ja.id, platforma, sad, sad - 7 * 24 * 60 * 60 * 1000)
        .run();
      return json({ ok: true });
    }

    // Moja statistika: ukupno i po oblastima.
    if (put === "/api/igraci/ja/statistika" && req.method === "GET") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const [ukupno, oblasti] = await env.DB.batch([
        env.DB.prepare(
          "SELECT COUNT(*) AS partija, COALESCE(SUM(poeni), 0) AS poena, COALESCE(MAX(poeni), 0) AS najvise FROM rezultati WHERE igrac_id = ?",
        ).bind(ja.id),
        env.DB.prepare("SELECT oblast, tacnih, ukupno FROM statistika WHERE igrac_id = ? ORDER BY ukupno DESC").bind(ja.id),
      ]);
      return json({ ...(ukupno.results[0] as object), oblasti: oblasti.results });
    }

    // Dnevni izazov: jedan pokušaj dnevno, ista pitanja za sve.
    if (put === "/api/izazov" && req.method === "POST") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const dan = danas();
      const upis = await env.DB.prepare("INSERT OR IGNORE INTO izazov (igrac_id, dan, poeni, tacnih, kraj) VALUES (?, ?, 0, 0, 0)")
        .bind(ja.id, dan)
        .run();
      if (!upis.meta.changes) return greska("Današnji izazov si već odigrao. Novi stiže u ponoć.", 409);
      const kod = await novaSoba(env, { moderatorId: ja.id, izazov: dan });
      if (kod) return json({ kod, dan }, 201);
      await env.DB.prepare("DELETE FROM izazov WHERE igrac_id = ? AND dan = ?").bind(ja.id, dan).run();
      return greska("Pokušaj ponovo.", 503);
    }

    // Današnja top lista izazova (i moj rezultat, ako sam prijavljen).
    if (put === "/api/izazov/top" && req.method === "GET") {
      const dan = danas();
      const lista = await env.DB.prepare(
        `SELECT i.id, i.ime, i.avatar, z.poeni, z.tacnih, z.kraj FROM izazov z JOIN igraci i ON i.id = z.igrac_id
         WHERE z.dan = ? AND z.kraj > 0 ORDER BY z.poeni DESC, z.kraj ASC LIMIT 50`,
      )
        .bind(dan)
        .all<{ id: string; poeni: number; kraj: number }>();
      const ja = await prijavljen(req, env);
      let moj: Record<string, unknown> | null = null;
      if (ja) {
        const r = await env.DB.prepare("SELECT poeni, tacnih, kraj FROM izazov WHERE dan = ? AND igrac_id = ?")
          .bind(dan, ja.id)
          .first<{ poeni: number; tacnih: number; kraj: number }>();
        if (r) {
          const ispred = r.kraj
            ? await env.DB.prepare(
                "SELECT COUNT(*) AS n FROM izazov WHERE dan = ? AND kraj > 0 AND (poeni > ? OR (poeni = ? AND kraj < ?))",
              )
                .bind(dan, r.poeni, r.poeni, r.kraj)
                .first<{ n: number }>()
            : null;
          moj = { ...r, zavrsen: r.kraj > 0, mesto: ispred ? ispred.n + 1 : null };
        }
      }
      return json({ dan, lista: lista.results, ja: moj });
    }

    // Teme izgleda: spisak za Podešavanja i cela tema za preuzimanje.
    if (put === "/api/teme" && req.method === "GET") {
      return json(await spisakTema());
    }
    const t = put.match(/^\/api\/teme\/([a-z0-9-]{1,40})$/);
    if (t && req.method === "GET") {
      const nadjena = await tema(t[1]);
      return nadjena ? json(nadjena) : greska("Tema ne postoji.", 404);
    }

    // Najmanja dozvoljena verzija: starija aplikacija traži ažuriranje pre igre.
    if (put === "/api/verzija" && req.method === "GET") return json(minVerzija(env));

    if (put === "/api/oblasti" && req.method === "GET") {
      const r = await env.DB.prepare("SELECT oblast, COUNT(*) AS broj FROM pitanja GROUP BY oblast ORDER BY oblast").all();
      return json(r.results);
    }

    // Nova soba: tvorac je moderator.
    if (put === "/api/sobe" && req.method === "POST") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const kod = await novaSoba(env, { moderatorId: ja.id });
      if (kod) return json({ kod, link: `https://kviz.dartchat.trade/i/${kod}` }, 201);
      return greska("Pokušaj ponovo.", 503);
    }

    // Dart Chat: ko sam (predlog imena pre pravljenja Kviz naloga).
    if (put === "/api/dartchat/ja" && req.method === "GET") {
      const dc = await dartChatKorisnik(req, env);
      if (dc instanceof Response) return dc;
      return json({ matrix_id: dc.matrixId, ime_predlog: dc.ime });
    }

    // Dart Chat pravi sobu u ime pozivara; njegov povezani Kviz nalog postaje moderator kad uđe.
    if (put === "/api/dartchat/sobe" && req.method === "POST") {
      const dc = await dartChatKorisnik(req, env);
      if (dc instanceof Response) return dc;
      const t = teloSobe(await req.json().catch(() => ({})));
      if ("greska" in t) return greska(t.greska, 400);
      const veza = await env.DB.prepare("SELECT igrac_id FROM dartchat_veze WHERE matrix_id = ?")
        .bind(dc.matrixId)
        .first<{ igrac_id: string }>();
      const kod = await novaSoba(env, {
        moderatorId: veza?.igrac_id ?? "",
        dartchat: { moderator: dc.matrixId, pozvani: t.pozvani.filter((p) => p !== dc.matrixId), chat: t.chat },
        opcije: t.opcije,
      });
      if (!kod) return greska("Pokušaj ponovo.", 503);
      return json(
        {
          kod,
          link: `https://kviz.dartchat.trade/i/${kod}`,
          istice: new Date(Date.now() + ZIVOT_SOBE).toISOString().replace(/\.\d{3}Z$/, "Z"),
        },
        201,
      );
    }

    // Pregled sobe za "Moje sobe" u aplikaciji (povratak u sobu posle izlaska sa ekrana).
    const pregled = put.match(/^\/api\/sobe\/([A-Za-z0-9]{6})$/);
    if (pregled && req.method === "GET") {
      const kod = pregled[1].toUpperCase();
      if (!KOD_REGEX.test(kod)) return greska("Pogrešan kod.", 400);
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const r = await env.SOBA.get(env.SOBA.idFromName(kod)).fetch(`https://soba/pregled?id=${encodeURIComponent(ja.id)}`);
      if (!r.ok) return greska("Soba je istekla.", 404);
      return json(await r.json());
    }

    // Stanje sobe za karticu u Dart Chatu.
    const dcSoba = put.match(/^\/api\/dartchat\/sobe\/([A-Za-z0-9]{6})$/);
    if (dcSoba && req.method === "GET") {
      const kod = dcSoba[1].toUpperCase();
      if (!KOD_REGEX.test(kod)) return greska("Pogrešan kod.", 400);
      const dc = await dartChatKorisnik(req, env);
      if (dc instanceof Response) return dc;
      const r = await env.SOBA.get(env.SOBA.idFromName(kod)).fetch("https://soba/dartchat");
      const telo = r.ok ? await r.json() : istekla(kod);
      return new Response(JSON.stringify(telo), {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "access-control-allow-origin": "*",
          "cache-control": "private, max-age=10",
        },
      });
    }

    // Kviz nalog se povezuje sa Dart Chat nalogom (link iz Dart Chata nosi #dc=TOKEN).
    if (put === "/api/dartchat/povezi" && req.method === "POST") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const telo = (await req.json().catch(() => ({}))) as { openid_token?: unknown };
      const token = ispravanToken(telo.openid_token);
      if (!token) return greska("Nedostaje Dart Chat prijava.", 400);
      let dc: DartChatKorisnik;
      try {
        dc = await proveriToken(token, env);
      } catch (e) {
        if (e instanceof DartChatGreska) return greska(e.message, e.status);
        throw e;
      }
      await env.DB.batch([
        env.DB.prepare("DELETE FROM dartchat_veze WHERE matrix_id = ? OR igrac_id = ?").bind(dc.matrixId, ja.id),
        env.DB.prepare("INSERT INTO dartchat_veze (matrix_id, igrac_id, povezan) VALUES (?, ?, ?)").bind(
          dc.matrixId,
          ja.id,
          Date.now(),
        ),
      ]);
      return json({ matrix_id: dc.matrixId, ime_predlog: dc.ime });
    }

    // Top lista: ?period=dan|nedelja|sve&poredak=ukupno|prosek
    if (put === "/api/top" && req.method === "GET") {
      const period = ["dan", "nedelja", "sve"].includes(url.searchParams.get("period") ?? "")
        ? url.searchParams.get("period")!
        : "nedelja";
      const prosek = url.searchParams.get("poredak") === "prosek";
      const od = pocetakPerioda(period);
      const r = await env.DB.prepare(
        `SELECT i.id, i.ime, i.avatar, COUNT(*) AS partija, SUM(r.poeni) AS ukupno,
                ROUND(AVG(r.poeni), 1) AS prosek
         FROM rezultati r JOIN igraci i ON i.id = r.igrac_id
         WHERE r.kraj >= ?
         GROUP BY i.id
         ${prosek ? "HAVING COUNT(*) >= 3" : ""}
         ORDER BY ${prosek ? "prosek" : "ukupno"} DESC, partija DESC
         LIMIT 50`,
      )
        .bind(od)
        .all<{ partija: number; prosek: number | null }>();
      // Prosek se prikazuje tek posle 3 partije.
      const lista = r.results.map((x) => ({ ...x, prosek: x.partija >= 3 ? x.prosek : null }));
      return json({ period, poredak: prosek ? "prosek" : "ukupno", od, lista });
    }

    // WebSocket: /ws/KOD?id=...&token=...
    const ws = put.match(/^\/ws\/([A-Z0-9]{6})$/);
    if (ws) {
      const kod = ws[1];
      if (!KOD_REGEX.test(kod)) return greska("Pogrešan kod.", 400);
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      const zaglavlja = new Headers(req.headers);
      zaglavlja.set("X-Igrac-Id", ja.id);
      zaglavlja.set("X-Igrac-Ime", encodeURIComponent(ja.ime));
      zaglavlja.set("X-Igrac-Avatar", encodeURIComponent(ja.avatar));
      const veza = await env.DB.prepare("SELECT matrix_id FROM dartchat_veze WHERE igrac_id = ?")
        .bind(ja.id)
        .first<{ matrix_id: string }>();
      if (veza) zaglavlja.set("X-Igrac-Matrix", veza.matrix_id);
      else zaglavlja.delete("X-Igrac-Matrix");
      const soba = env.SOBA.get(env.SOBA.idFromName(kod));
      return soba.fetch(new Request("https://soba/ws", { headers: zaglavlja }));
    }

    return greska("Nije pronađeno.", 404);
  },

  // Cron u 6:00 i 7:00 UTC: jedan od ta dva je 8:00 u Beogradu (zimsko i letnje vreme).
  async scheduled(_ctrl: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    if (satUBeogradu() !== 8) return;
    ctx.waitUntil(
      (async () => {
        await jutarnjiPush(env);
        // Ključevi telefona koji se dva meseca nisu javili.
        await env.DB.prepare("DELETE FROM push_kljucevi WHERE azuriran < ?").bind(Date.now() - 60 * 24 * 60 * 60 * 1000).run();
      })(),
    );
  },
} satisfies ExportedHandler<Env>;
