import { describe, expect, it } from "vitest";
import {
  DartChatGreska,
  imeIzDartChata,
  javiDartChatu,
  poredak,
  proveriToken,
  stanjeZaDartChat,
  teloSobe,
  testKorisnik,
  tokenIzZaglavlja,
} from "../src/dartchat";
import { novoStanje, type Igrac } from "../src/igra";

/** Najmanja D1 zamena: pamti tokene u mapi. */
function lazniDB() {
  const tokeni = new Map<string, { matrix_id: string; ime: string; istice: number }>();
  const upiti: string[] = [];
  const prepare = (sql: string) => ({
    bind: (...a: any[]) => ({
      sql,
      a,
      first: async () => {
        upiti.push(sql);
        const r = tokeni.get(a[0]);
        return r && r.istice > a[1] ? r : null;
      },
    }),
  });
  const batch = async (st: { sql: string; a: any[] }[]) => {
    for (const s of st) {
      upiti.push(s.sql);
      if (s.sql.startsWith("INSERT")) tokeni.set(s.a[0], { matrix_id: s.a[1], ime: s.a[2], istice: s.a[3] });
    }
    return [];
  };
  return { db: { prepare, batch } as unknown as D1Database, tokeni, upiti };
}

const igrac = (id: string, poeni: number, tacnih: number, extra: Partial<Igrac> = {}): Igrac => ({
  id,
  ime: id,
  avatar: "🦊",
  spreman: false,
  uIgri: true,
  poeni,
  tacnih,
  ...extra,
});

describe("Dart Chat", () => {
  it("token iz zaglavlja", () => {
    expect(tokenIzZaglavlja("DartChat abc.def")).toBe("abc.def");
    expect(tokenIzZaglavlja("Bearer abc")).toBeNull();
    expect(tokenIzZaglavlja("DartChat ")).toBeNull();
    expect(tokenIzZaglavlja("DartChat " + "x".repeat(513))).toBeNull();
    expect(tokenIzZaglavlja(null)).toBeNull();
  });

  it("lažni token važi samo u test režimu", () => {
    const { db } = lazniDB();
    expect(testKorisnik("test:@marko:chat.dartchat.trade", { DB: db, DARTCHAT_TEST: "1" })).toEqual({
      matrixId: "@marko:chat.dartchat.trade",
      ime: "marko",
    });
    expect(testKorisnik("test:@marko:chat.dartchat.trade", { DB: db })).toBeNull();
    expect(testKorisnik("test:marko", { DB: db, DARTCHAT_TEST: "1" })).toBeNull();
  });

  it("proverava token preko Dart Chata i pamti ga", async () => {
    const { db, tokeni } = lazniDB();
    const env = { DB: db, DARTCHAT_URL: "https://chat.dartchat.trade/", KVIZ_KLJUC: "tajna" };
    const pozivi: { url: string; init: RequestInit }[] = [];
    const f = (async (url: string, init: RequestInit) => {
      pozivi.push({ url, init });
      return Response.json({ matrix_id: "@ana:chat.dartchat.trade", displayname: "Ana", expires_in: 7200 });
    }) as unknown as typeof fetch;
    const k = await proveriToken("tok123", env, f);
    expect(k).toEqual({ matrixId: "@ana:chat.dartchat.trade", ime: "Ana" });
    expect(pozivi[0].url).toBe("https://chat.dartchat.trade/_dartchat/v1/quiz/whoami");
    expect((pozivi[0].init.headers as Record<string, string>).authorization).toBe("Bearer tajna");
    expect(JSON.parse(pozivi[0].init.body as string)).toEqual({ openid_token: "tok123" });
    // U bazi je otisak, ne token, i najviše sat vremena.
    const [[hash, red]] = [...tokeni.entries()];
    expect(hash).not.toContain("tok123");
    expect(hash).toHaveLength(64);
    expect(red.istice - Date.now()).toBeLessThanOrEqual(3600_000);
    // Drugi put iz keša, bez poziva.
    await proveriToken("tok123", env, f);
    expect(pozivi).toHaveLength(1);
  });

  it("odbijen token je 401, a bez podešavanja 503", async () => {
    const { db } = lazniDB();
    const f = (async () => new Response("", { status: 401 })) as unknown as typeof fetch;
    await expect(proveriToken("x", { DB: db, DARTCHAT_URL: "https://c", KVIZ_KLJUC: "k" }, f)).rejects.toMatchObject({
      status: 401,
    });
    await expect(proveriToken("x", { DB: db }, f)).rejects.toBeInstanceOf(DartChatGreska);
    await expect(proveriToken("x", { DB: db }, f)).rejects.toMatchObject({ status: 503 });
  });

  it("ime iz Dart Chata", () => {
    expect(imeIzDartChata("  Dottore ", "@dottore:x")).toBe("Dottore");
    expect(imeIzDartChata("", "@marko:chat.dartchat.trade")).toBe("marko");
    expect(imeIzDartChata("a".repeat(30), "@x:y")).toHaveLength(20);
  });

  it("telo za novu sobu", () => {
    expect(teloSobe({})).toEqual({ pozvani: [], chat: null, opcije: null });
    expect(teloSobe({ pozvani: ["@a:x", "@a:x"], chat: "!r:x", opcije: { brojPitanja: 15 } })).toEqual({
      pozvani: ["@a:x"],
      chat: "!r:x",
      opcije: { brojPitanja: 15 },
    });
    expect(teloSobe({ pozvani: Array.from({ length: 30 }, (_, i) => `@p${i}:x`) })).toHaveProperty("greska");
    expect(teloSobe({ pozvani: ["marko"] })).toHaveProperty("greska");
    expect(teloSobe({ chat: "soba" })).toHaveProperty("greska");
  });

  it("stanje za karticu: faze, moderator, poredak samo na kraju", () => {
    const s = novoStanje("K7QX2M", "", Date.parse("2026-11-20T10:00:00Z"));
    s.dartchat = { moderator: "@dottore:x", pozvani: ["@ana:x"], chat: null };
    s.igraci = [igrac("a", 5, 2, { matrix: "@ana:x" }), igrac("b", 9, 3), igrac("c", 9, 4), igrac("d", 1, 0, { uIgri: false })];
    let st = stanjeZaDartChat(s, 24 * 3600_000);
    expect(st.faza).toBe("cekaonica");
    expect(st.moderator).toBe("@dottore:x");
    expect(st.poredak).toBeNull();
    expect(st.istice).toBe("2026-11-21T10:00:00Z");
    expect(st.igraci[0].matrix_id).toBe("@ana:x");
    expect(st.igraci[1].matrix_id).toBeNull();
    s.faza = "otkriveno";
    expect(stanjeZaDartChat(s, 1).faza).toBe("igra");
    s.faza = "kraj";
    st = stanjeZaDartChat(s, 1);
    expect(st.poredak!.map((p) => p.ime)).toEqual(["c", "b", "a"]);
  });

  it("poredak preskače one koji nisu igrali", () => {
    expect(poredak([igrac("x", 1, 0, { uIgri: false }), igrac("y", 0, 0)]).map((p) => p.ime)).toEqual(["y"]);
  });

  it("događaj: tri pokušaja, pa odustaje; 4xx se ne ponavlja", async () => {
    let n = 0;
    const pauze: number[] = [];
    const pada = (async () => {
      n++;
      throw new Error("mreža");
    }) as unknown as typeof fetch;
    const env = { DB: {} as D1Database, DARTCHAT_URL: "https://c", KVIZ_KLJUC: "k" };
    const telo = { kod: "K7QX2M", chat: "!r:x", dogadjaj: "kraj" as const };
    expect(await javiDartChatu(env, telo, pada, async (ms) => void pauze.push(ms))).toBe(false);
    expect(n).toBe(3);
    expect(pauze.reduce((a, b) => a + b, 0)).toBeLessThanOrEqual(60_000);

    n = 0;
    const odbija = (async () => {
      n++;
      return new Response("", { status: 400 });
    }) as unknown as typeof fetch;
    expect(await javiDartChatu(env, telo, odbija, async () => {})).toBe(false);
    expect(n).toBe(1);

    let poslato: any;
    const ok = (async (_u: string, init: RequestInit) => {
      poslato = JSON.parse(init.body as string);
      return new Response("{}");
    }) as unknown as typeof fetch;
    expect(await javiDartChatu(env, telo, ok, async () => {})).toBe(true);
    expect(poslato).toEqual({ kod: "K7QX2M", chat: "!r:x", dogadjaj: "kraj", igrac: null, poredak: null });
    // Bez podešavanja se ništa ne šalje.
    expect(await javiDartChatu({ DB: {} as D1Database }, telo, ok)).toBe(false);
  });
});
