// Jedna soba = jedan Durable Object. Drži igrače, opcije, tajmer i bodovanje.
// WebSocket hibernacija: stanje je uvek u storage-u, ne samo u memoriji.
import { DurableObject } from "cloudflare:workers";
import {
  bodujPitanje,
  ispravneOpcije,
  napraviPitanje,
  novoStanje,
  svePrimljeno,
  type Igrac,
  type Stanje,
} from "./igra";
import type { Env } from "./index";

const PAUZA_POSLE_OTKRIVANJA = 5_000;
const ZIVOT_SOBE = 24 * 60 * 60 * 1000;
const PROZIVKA = 60_000;
const MAX_IGRACA = 30;

interface Prikljucak {
  igracId: string;
}

export class Soba extends DurableObject<Env> {
  private stanje: Stanje | null = null;

  private async ucitaj(): Promise<Stanje | null> {
    if (!this.stanje) this.stanje = (await this.ctx.storage.get<Stanje>("s")) ?? null;
    return this.stanje;
  }

  private async sacuvaj(s: Stanje) {
    this.stanje = s;
    await this.ctx.storage.put("s", s);
    await this.zakaziAlarm(s);
  }

  private async zakaziAlarm(s: Stanje) {
    const rokovi = [s.napravljena + ZIVOT_SOBE];
    if (s.faza === "pitanje") rokovi.push(s.krajPitanja);
    if (s.faza === "otkriveno") rokovi.push(s.krajPitanja + PAUZA_POSLE_OTKRIVANJA);
    if (s.prozivkaDo) rokovi.push(s.prozivkaDo);
    await this.ctx.storage.setAlarm(Math.min(...rokovi));
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/init" && req.method === "POST") {
      const { kod, moderatorId } = (await req.json()) as { kod: string; moderatorId: string };
      if (await this.ucitaj()) return new Response("postoji", { status: 409 });
      const s = novoStanje(kod, moderatorId, Date.now());
      const oblasti = await this.env.DB.prepare("SELECT DISTINCT oblast FROM pitanja ORDER BY oblast").all<{ oblast: string }>();
      await this.ctx.storage.put("oblasti", oblasti.results.map((r) => r.oblast));
      await this.sacuvaj(s);
      return new Response("ok");
    }
    if (url.pathname === "/ws") {
      if (req.headers.get("Upgrade") !== "websocket") return new Response("ocekujem websocket", { status: 426 });
      const s = await this.ucitaj();
      if (!s) return new Response("nema sobe", { status: 404 });
      const id = req.headers.get("X-Igrac-Id")!;
      const ime = decodeURIComponent(req.headers.get("X-Igrac-Ime") ?? "Igrač");
      const avatar = decodeURIComponent(req.headers.get("X-Igrac-Avatar") ?? "🦊");
      let igrac = s.igraci.find((i) => i.id === id);
      if (!igrac) {
        if (s.igraci.length >= MAX_IGRACA) return new Response("soba je puna", { status: 403 });
        igrac = { id, ime, avatar, spreman: false, uIgri: false, poeni: 0, tacnih: 0 };
        s.igraci.push(igrac);
      } else {
        igrac.ime = ime;
        igrac.avatar = avatar;
      }
      const par = new WebSocketPair();
      // Stari priključak istog igrača (npr. drugi tab) se zatvara.
      for (const ws of this.ctx.getWebSockets(id)) ws.close(4000, "novi priključak");
      this.ctx.acceptWebSocket(par[1], [id]);
      par[1].serializeAttachment({ igracId: id } satisfies Prikljucak);
      await this.sacuvaj(s);
      this.posaljiSvima(s);
      return new Response(null, { status: 101, webSocket: par[0] });
    }
    return new Response("nije pronađeno", { status: 404 });
  }

  async webSocketMessage(ws: WebSocket, poruka: string | ArrayBuffer) {
    const s = await this.ucitaj();
    if (!s || typeof poruka !== "string") return;
    const { igracId } = ws.deserializeAttachment() as Prikljucak;
    const igrac = s.igraci.find((i) => i.id === igracId);
    if (!igrac) return;
    let m: Record<string, unknown>;
    try {
      m = JSON.parse(poruka);
    } catch {
      return;
    }
    const jeModerator = igracId === s.moderatorId;
    switch (m.t) {
      case "spreman":
        if (s.faza !== "cekaonica" && s.faza !== "kraj") return;
        igrac.spreman = Boolean(m.da);
        break;
      case "opcije": {
        if (!jeModerator || s.faza !== "cekaonica") return;
        const sve = (await this.ctx.storage.get<string[]>("oblasti")) ?? [];
        s.opcije = ispravneOpcije(m as never, sve);
        break;
      }
      case "prozovi":
        if (!jeModerator || s.faza !== "cekaonica") return;
        s.prozivkaDo = Date.now() + PROZIVKA;
        // TODO: push obaveštenje (FCM) igračima koji nisu povezani.
        break;
      case "pokreni":
        if (!jeModerator || (s.faza !== "cekaonica" && s.faza !== "kraj")) return;
        if (!(await this.pokreni(s))) {
          ws.send(JSON.stringify({ t: "greska", poruka: "Nema dovoljno pitanja za izabrane oblasti." }));
          return;
        }
        break;
      case "odgovor": {
        if (s.faza !== "pitanje" || !igrac.uIgri || igracId in s.odgovori) return;
        if (m.pitanje !== s.trenutno) return;
        const izbor = Number(m.izbor);
        if (!Number.isInteger(izbor) || izbor < 0 || izbor > 3) return;
        const sad = Date.now();
        if (sad > s.krajPitanja) return;
        s.odgovori[igracId] = { izbor, vreme: sad - s.pocetakPitanja };
        if (svePrimljeno(s)) this.otkrij(s);
        break;
      }
      case "revans":
        if (!jeModerator || s.faza !== "kraj") return;
        s.faza = "cekaonica";
        for (const i of s.igraci) {
          i.spreman = false;
          i.uIgri = false;
        }
        break;
      case "izadji":
        s.igraci = s.igraci.filter((i) => i.id !== igracId);
        ws.close(1000, "izašao");
        if (jeModerator && s.igraci.length) s.moderatorId = s.igraci[0].id;
        break;
      default:
        return;
    }
    await this.sacuvaj(s);
    this.posaljiSvima(s);
  }

  async webSocketClose(ws: WebSocket) {
    const s = await this.ucitaj();
    if (s) this.posaljiSvima(s);
  }

  async alarm() {
    const s = await this.ucitaj();
    if (!s) return;
    const sad = Date.now();
    if (sad >= s.napravljena + ZIVOT_SOBE && (s.faza === "cekaonica" || s.faza === "kraj")) {
      for (const ws of this.ctx.getWebSockets()) ws.close(4001, "soba je istekla");
      await this.ctx.storage.deleteAll();
      this.stanje = null;
      return;
    }
    if (s.prozivkaDo && sad >= s.prozivkaDo) s.prozivkaDo = 0;
    if (s.faza === "pitanje" && sad >= s.krajPitanja) this.otkrij(s);
    else if (s.faza === "otkriveno" && sad >= s.krajPitanja + PAUZA_POSLE_OTKRIVANJA) await this.sledece(s);
    await this.sacuvaj(s);
    this.posaljiSvima(s);
  }

  private async pokreni(s: Stanje): Promise<boolean> {
    const igraju = s.igraci.filter((i) => i.spreman || i.id === s.moderatorId);
    if (!igraju.length) return false;
    const { brojPitanja, oblasti } = s.opcije;
    const pitanja = await this.izaberiPitanja(igraju.map((i) => i.id), oblasti, brojPitanja);
    if (pitanja.length < Math.min(5, brojPitanja)) return false;
    for (const i of s.igraci) {
      i.uIgri = igraju.includes(i);
      i.poeni = 0;
      i.tacnih = 0;
    }
    s.pitanja = pitanja.map((r) => napraviPitanje(r));
    s.trenutno = -1;
    s.pocetakIgre = Date.now();
    s.prozivkaDo = 0;
    await this.sledece(s);
    return true;
  }

  private async izaberiPitanja(igraci: string[], oblasti: string[], broj: number) {
    type Red = { id: number; oblast: string; tekst: string; tacan: string; netacan1: string; netacan2: string; netacan3: string };
    const uslovOblasti = oblasti.length ? `AND oblast IN (${oblasti.map(() => "?").join(",")})` : "";
    const nevidjena = await this.env.DB.prepare(
      `SELECT id, oblast, tekst, tacan, netacan1, netacan2, netacan3 FROM pitanja
       WHERE 1=1 ${uslovOblasti}
       AND id NOT IN (SELECT pitanje_id FROM odigrano WHERE igrac_id IN (${igraci.map(() => "?").join(",")}))
       ORDER BY random() LIMIT ?`,
    )
      .bind(...oblasti, ...igraci, broj)
      .all<Red>();
    if (nevidjena.results.length >= broj) return nevidjena.results;
    // Kad su sva pitanja viđena, dopuni nasumičnim (ponavljanje je bolje od prekida).
    const dopuna = await this.env.DB.prepare(
      `SELECT id, oblast, tekst, tacan, netacan1, netacan2, netacan3 FROM pitanja
       WHERE 1=1 ${uslovOblasti} ORDER BY random() LIMIT ?`,
    )
      .bind(...oblasti, broj)
      .all<Red>();
    const vec = new Set(nevidjena.results.map((r) => r.id));
    return [...nevidjena.results, ...dopuna.results.filter((r) => !vec.has(r.id))].slice(0, broj);
  }

  private async sledece(s: Stanje) {
    s.trenutno++;
    s.odgovori = {};
    s.poslednjiPoeni = {};
    if (s.trenutno >= s.pitanja.length) {
      await this.zavrsi(s);
      return;
    }
    s.faza = "pitanje";
    s.pocetakPitanja = Date.now();
    s.krajPitanja = s.pocetakPitanja + s.opcije.vreme * 1000;
  }

  private otkrij(s: Stanje) {
    const p = s.pitanja[s.trenutno];
    const delta = bodujPitanje(p.tacan, s.odgovori);
    for (const i of s.igraci) {
      if (!i.uIgri) continue;
      const d = delta[i.id] ?? 0;
      i.poeni += d;
      if (s.odgovori[i.id]?.izbor === p.tacan) i.tacnih++;
    }
    s.poslednjiPoeni = delta;
    s.faza = "otkriveno";
    s.krajPitanja = Date.now();
  }

  private async zavrsi(s: Stanje) {
    s.faza = "kraj";
    const kraj = Date.now();
    const igraId = crypto.randomUUID();
    const igraju = s.igraci.filter((i) => i.uIgri);
    const upiti = [
      this.env.DB.prepare("INSERT INTO igre (id, soba, pocetak, kraj, broj_pitanja) VALUES (?, ?, ?, ?, ?)").bind(
        igraId,
        s.kod,
        s.pocetakIgre,
        kraj,
        s.pitanja.length,
      ),
      ...igraju.map((i) =>
        this.env.DB.prepare("INSERT INTO rezultati (igra_id, igrac_id, poeni, tacnih, kraj) VALUES (?, ?, ?, ?, ?)").bind(
          igraId,
          i.id,
          i.poeni,
          i.tacnih,
          kraj,
        ),
      ),
      ...igraju.flatMap((i) =>
        s.pitanja.map((p) =>
          this.env.DB.prepare("INSERT OR IGNORE INTO odigrano (igrac_id, pitanje_id) VALUES (?, ?)").bind(i.id, p.id),
        ),
      ),
    ];
    await this.env.DB.batch(upiti);
    for (const i of s.igraci) i.spreman = false;
  }

  /** Šta klijent vidi: tačan odgovor tek posle otkrivanja, tuđi izbori nikad pre kraja pitanja. */
  private prikaz(s: Stanje) {
    const povezani = new Set(
      this.ctx.getWebSockets().map((ws) => (ws.deserializeAttachment() as Prikljucak | null)?.igracId),
    );
    const p = s.pitanja[s.trenutno];
    const otkriveno = s.faza === "otkriveno";
    return {
      t: "stanje",
      kod: s.kod,
      faza: s.faza,
      moderatorId: s.moderatorId,
      opcije: s.opcije,
      prozivkaDo: s.prozivkaDo,
      igraci: s.igraci.map((i: Igrac) => ({
        ...i,
        povezan: povezani.has(i.id),
        odgovorio: i.id in s.odgovori,
      })),
      pitanje:
        (s.faza === "pitanje" || otkriveno) && p
          ? {
              n: s.trenutno,
              ukupno: s.pitanja.length,
              oblast: p.oblast,
              tekst: p.tekst,
              opcije: p.opcije,
              krajU: s.krajPitanja,
              ...(otkriveno
                ? {
                    tacan: p.tacan,
                    odgovori: Object.fromEntries(Object.entries(s.odgovori).map(([k, v]) => [k, v.izbor])),
                    poeni: s.poslednjiPoeni,
                  }
                : {}),
            }
          : null,
      sad: Date.now(),
    };
  }

  private posaljiSvima(s: Stanje) {
    const poruka = JSON.stringify(this.prikaz(s));
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(poruka);
      } catch {
        // zatvoren priključak; ignoriše se
      }
    }
  }
}
