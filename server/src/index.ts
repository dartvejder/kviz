// Kviz server: HTTP API (/api) i WebSocket za sobe (/ws/KOD).
import { KOD_REGEX, noviKod } from "./igra";
import { pocetakPerioda } from "./period";
import { stranicaPozivnice, wellKnown } from "./pozivnica";

export { Soba } from "./soba";

export interface Env {
  DB: D1Database;
  SOBA: DurableObjectNamespace;
}

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
          env.DB.prepare("DELETE FROM igraci WHERE id = ?").bind(ja.id),
        ]);
        return json({ obrisan: true });
      }
    }

    if (put === "/api/oblasti" && req.method === "GET") {
      const r = await env.DB.prepare("SELECT oblast, COUNT(*) AS broj FROM pitanja GROUP BY oblast ORDER BY oblast").all();
      return json(r.results);
    }

    // Nova soba: tvorac je moderator.
    if (put === "/api/sobe" && req.method === "POST") {
      const ja = await prijavljen(req, env);
      if (!ja) return greska("Nisi prijavljen.", 401);
      for (let pokusaj = 0; pokusaj < 5; pokusaj++) {
        const kod = noviKod();
        const soba = env.SOBA.get(env.SOBA.idFromName(kod));
        const r = await soba.fetch("https://soba/init", {
          method: "POST",
          body: JSON.stringify({ kod, moderatorId: ja.id }),
        });
        if (r.ok) return json({ kod, link: `https://kviz.dartchat.trade/i/${kod}` }, 201);
      }
      return greska("Pokušaj ponovo.", 503);
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
      const soba = env.SOBA.get(env.SOBA.idFromName(kod));
      return soba.fetch(new Request("https://soba/ws", { headers: zaglavlja }));
    }

    return greska("Nije pronađeno.", 404);
  },
} satisfies ExportedHandler<Env>;
