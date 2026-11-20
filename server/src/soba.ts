// Jedna soba = jedan Durable Object. Drži igrače, opcije, tajmer i bodovanje.
// WebSocket hibernacija: stanje je uvek u storage-u, ne samo u memoriji.
import { DurableObject } from "cloudflare:workers";
import {
  IZAZOV_OPCIJE,
  PODRAZUMEVANE_OPCIJE,
  REAKCIJE,
  pregledSobe,
  bodujPitanje,
  ispravneOpcije,
  polaPola,
  primeniDupli,
  seme,
  napraviPitanje,
  novoStanje,
  noviKod,
  pregledPartije,
  svePrimljeno,
  zapamtiOdgovore,
  type Igrac,
  type Stanje,
} from "./igra";
import type { Env } from "./index";
import { javiDartChatu, poredak, stanjeZaDartChat, type Dogadjaj } from "./dartchat";

/** Pauza posle otkrivanja odgovora; starije sobe nemaju opciju pa važi 5 s. */
const pauzaMs = (s: { opcije: { pauza?: number } }) => (s.opcije.pauza ?? 5) * 1000;
const ZIVOT_SOBE = 24 * 60 * 60 * 1000;
const PROZIVKA = 60_000;
const MAX_IGRACA = 30;

interface Prikljucak {
  igracId: string;
}

export class Soba extends DurableObject<Env> {
  private stanje: Stanje | null = null;
  /** Poslednja reakcija po igraču (u memoriji), da se ne zatrpa soba. */
  private reakcije = new Map<string, number>();

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
    if (s.faza === "otkriveno") rokovi.push(s.krajPitanja + pauzaMs(s));
    if (s.prozivkaDo) rokovi.push(s.prozivkaDo);
    await this.ctx.storage.setAlarm(Math.min(...rokovi));
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/init" && req.method === "POST") {
      const { kod, moderatorId, izazov, dartchat, opcije } = (await req.json()) as {
        kod: string;
        moderatorId: string;
        izazov?: string;
        dartchat?: Stanje["dartchat"];
        opcije?: Record<string, unknown> | null;
      };
      if (await this.ucitaj()) return new Response("postoji", { status: 409 });
      const s = novoStanje(kod, moderatorId, Date.now());
      if (izazov) {
        s.izazov = izazov;
        s.opcije = { ...IZAZOV_OPCIJE };
      }
      const oblasti = await this.env.DB.prepare("SELECT DISTINCT oblast FROM pitanja ORDER BY oblast").all<{ oblast: string }>();
      const sveOblasti = oblasti.results.map((r) => r.oblast);
      await this.ctx.storage.put("oblasti", sveOblasti);
      if (dartchat) s.dartchat = dartchat;
      // Predlog iz Dart Chata ili opcije prethodne sobe ("Igraj ponovo"); moderator ih menja u čekaonici.
      if (opcije && !izazov) s.opcije = ispravneOpcije({ ...PODRAZUMEVANE_OPCIJE, ...opcije } as never, sveOblasti);
      await this.sacuvaj(s);
      return new Response("ok");
    }
    // Kratak pregled za "Moje sobe" u aplikaciji.
    if (url.pathname === "/pregled") {
      const s = await this.ucitaj();
      if (!s) return new Response("nema sobe", { status: 404 });
      return Response.json(pregledSobe(s, url.searchParams.get("id") ?? "", ZIVOT_SOBE));
    }
    if (url.pathname === "/dartchat") {
      const s = await this.ucitaj();
      if (!s) return new Response("nema sobe", { status: 404 });
      return Response.json(stanjeZaDartChat(s, ZIVOT_SOBE));
    }
    if (url.pathname === "/ws") {
      if (req.headers.get("Upgrade") !== "websocket") return new Response("ocekujem websocket", { status: 426 });
      const s = await this.ucitaj();
      if (!s) return new Response("nema sobe", { status: 404 });
      const id = req.headers.get("X-Igrac-Id")!;
      const ime = decodeURIComponent(req.headers.get("X-Igrac-Ime") ?? "Igrač");
      const avatar = decodeURIComponent(req.headers.get("X-Igrac-Avatar") ?? "🦊");
      const matrix = req.headers.get("X-Igrac-Matrix") || undefined;
      let igrac = s.igraci.find((i) => i.id === id);
      const nov = !igrac;
      if (!igrac) {
        if (s.izazov && id !== s.moderatorId) return new Response("izazov se igra sam", { status: 403 });
        if (s.igraci.length >= MAX_IGRACA) return new Response("soba je puna", { status: 403 });
        igrac = { id, ime, avatar, spreman: false, uIgri: false, poeni: 0, tacnih: 0 };
        s.igraci.push(igrac);
      } else {
        igrac.ime = ime;
        igrac.avatar = avatar;
      }
      if (matrix) igrac.matrix = matrix;
      else delete igrac.matrix;
      // Soba iz Dart Chata: pozivar je moderator čim uđe; do tada je to prvi koji uđe.
      if (s.dartchat && matrix === s.dartchat.moderator) s.moderatorId = id;
      else if (!s.moderatorId) s.moderatorId = id;
      if (nov) this.javi(s, "usao", { igrac: igrac.matrix ?? null, ime: igrac.ime });
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
        if (!jeModerator || s.faza !== "cekaonica" || s.izazov) return;
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
        // Dnevni izazov se igra jednom.
        if (s.izazov && s.pitanja.length) return;
        if (!(await this.pokreni(s))) {
          ws.send(JSON.stringify({ t: "greska", poruka: "Nema dovoljno pitanja za izabrane oblasti." }));
          return;
        }
        this.javi(s, "pocelo");
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
      case "dzoker": {
        if (s.faza !== "pitanje" || !igrac.uIgri || !s.opcije.dzokeri || igracId in s.odgovori) return;
        if (m.pitanje !== s.trenutno) return;
        igrac.dzokeri ??= {};
        if (m.vrsta === "pola" && !igrac.dzokeri.pola) {
          igrac.dzokeri.pola = true;
          // Koji odgovori nestaju zna samo taj igrač.
          ws.send(JSON.stringify({ t: "pola", pitanje: s.trenutno, sakrij: polaPola(s.pitanja[s.trenutno].tacan) }));
        } else if (m.vrsta === "dupli" && !igrac.dzokeri.dupli) {
          igrac.dzokeri.dupli = true;
          s.dupli = { ...s.dupli, [igracId]: true };
        } else return;
        break;
      }
      case "reakcija": {
        const e = String(m.e);
        if (!REAKCIJE.includes(e)) return;
        const sad = Date.now();
        if (sad - (this.reakcije.get(igracId) ?? 0) < 800) return;
        this.reakcije.set(igracId, sad);
        const poruka = JSON.stringify({ t: "reakcija", id: igracId, e });
        for (const w of this.ctx.getWebSockets()) {
          try {
            w.send(poruka);
          } catch {
            // zatvoren priključak
          }
        }
        return;
      }
      case "ponovo": {
        // Ista ekipa, nova soba (novih 24 sata), iste opcije; svi iz ove sobe prelaze tamo.
        if (!jeModerator || s.faza !== "kraj" || s.izazov) return;
        if (!s.sledeca) {
          const kod = await this.novaSoba(s);
          if (!kod) {
            ws.send(JSON.stringify({ t: "greska", poruka: "Nova soba nije napravljena. Pokušaj ponovo." }));
            return;
          }
          s.sledeca = kod;
        }
        break;
      }
      case "revans":
        if (!jeModerator || s.faza !== "kraj" || s.izazov) return;
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
      this.javi(s, "istekla");
      for (const ws of this.ctx.getWebSockets()) ws.close(4001, "soba je istekla");
      await this.ctx.storage.deleteAll();
      this.stanje = null;
      return;
    }
    if (s.prozivkaDo && sad >= s.prozivkaDo) s.prozivkaDo = 0;
    if (s.faza === "pitanje" && sad >= s.krajPitanja) this.otkrij(s);
    else if (s.faza === "otkriveno" && sad >= s.krajPitanja + pauzaMs(s)) await this.sledece(s);
    await this.sacuvaj(s);
    this.posaljiSvima(s);
  }

  private async pokreni(s: Stanje): Promise<boolean> {
    const igraju = s.igraci.filter((i) => i.spreman || i.id === s.moderatorId);
    if (!igraju.length) return false;
    const { brojPitanja, oblasti } = s.opcije;
    const pitanja = s.izazov
      ? await this.pitanjaIzazova(s.izazov, brojPitanja)
      : await this.izaberiPitanja(igraju.map((i) => i.id), oblasti, brojPitanja);
    if (pitanja.length < Math.min(5, brojPitanja)) return false;
    delete s.sledeca;
    for (const i of s.igraci) {
      i.uIgri = igraju.includes(i);
      i.poeni = 0;
      i.tacnih = 0;
      i.dzokeri = {};
      i.poOblasti = {};
    }
    // U izazovu su i redosled odgovora isti za sve.
    const rnd = s.izazov ? seme(`odgovori-${s.izazov}`) : Math.random;
    s.pitanja = pitanja.map((r) => napraviPitanje(r, rnd));
    s.istorija = {};
    s.trenutno = -1;
    s.pocetakIgre = Date.now();
    s.prozivkaDo = 0;
    await this.sledece(s);
    return true;
  }

  /** Ista pitanja za sve tog dana: redosled po otisku id-a i dana. */
  private async pitanjaIzazova(dan: string, broj: number) {
    const k = Math.floor(seme(`pitanja-${dan}`)() * 1_000_000) + 1;
    const r = await this.env.DB.prepare(
      `SELECT id, oblast, tekst, tacan, netacan1, netacan2, netacan3 FROM pitanja
       ORDER BY ((id * 2654435761 + ?) % 1000003), id LIMIT ?`,
    )
      .bind(k, broj)
      .all<{ id: number; oblast: string; tekst: string; tacan: string; netacan1: string; netacan2: string; netacan3: string }>();
    return r.results;
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
    s.dupli = {};
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
    const delta = primeniDupli(bodujPitanje(p.tacan, s.odgovori, !s.izazov), s.dupli);
    zapamtiOdgovore(s);
    for (const i of s.igraci) {
      if (!i.uIgri) continue;
      const d = delta[i.id] ?? 0;
      i.poeni += d;
      const tacno = s.odgovori[i.id]?.izbor === p.tacan;
      if (tacno) i.tacnih++;
      i.poOblasti ??= {};
      const [t, u] = i.poOblasti[p.oblast] ?? [0, 0];
      i.poOblasti[p.oblast] = [t + (tacno ? 1 : 0), u + 1];
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
        Object.entries(i.poOblasti ?? {}).map(([oblast, [t, u]]) =>
          this.env.DB.prepare(
            `INSERT INTO statistika (igrac_id, oblast, tacnih, ukupno) VALUES (?, ?, ?, ?)
             ON CONFLICT (igrac_id, oblast) DO UPDATE SET tacnih = tacnih + excluded.tacnih, ukupno = ukupno + excluded.ukupno`,
          ).bind(i.id, oblast, t, u),
        ),
      ),
      ...(s.izazov
        ? igraju.map((i) =>
            this.env.DB.prepare("UPDATE izazov SET poeni = ?, tacnih = ?, kraj = ? WHERE dan = ? AND igrac_id = ?").bind(
              i.poeni,
              i.tacnih,
              kraj,
              s.izazov,
              i.id,
            ),
          )
        : []),
      ...igraju.flatMap((i) =>
        s.pitanja.map((p) =>
          this.env.DB.prepare("INSERT OR IGNORE INTO odigrano (igrac_id, pitanje_id) VALUES (?, ?)").bind(i.id, p.id),
        ),
      ),
    ];
    await this.env.DB.batch(upiti);
    for (const i of s.igraci) i.spreman = false;
    this.javi(s, "kraj", { poredak: poredak(s.igraci) });
  }

  /** Nova soba sa istim moderatorom i opcijama ("Igraj ponovo"). */
  private async novaSoba(s: Stanje): Promise<string | null> {
    for (let pokusaj = 0; pokusaj < 5; pokusaj++) {
      const kod = noviKod();
      const r = await this.env.SOBA.get(this.env.SOBA.idFromName(kod)).fetch("https://soba/init", {
        method: "POST",
        body: JSON.stringify({ kod, moderatorId: s.moderatorId, opcije: s.opcije }),
      });
      if (r.ok) return kod;
    }
    return null;
  }

  /** Događaj za Dart Chat (samo sobe napravljene iz Dart Chata); igra ne čeka odgovor. */
  private javi(s: Stanje, dogadjaj: Dogadjaj, dodatak: { igrac?: string | null; ime?: string; poredak?: unknown } = {}) {
    if (!s.dartchat) return;
    this.ctx.waitUntil(javiDartChatu(this.env, { kod: s.kod, chat: s.dartchat.chat, dogadjaj, ...dodatak }));
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
      izazov: s.izazov ?? null,
      sledeca: s.faza === "kraj" ? (s.sledeca ?? null) : null,
      pregled: s.faza === "kraj" ? pregledPartije(s) : null,
      dupli: Object.keys(s.dupli ?? {}),
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
              id: p.id,
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
