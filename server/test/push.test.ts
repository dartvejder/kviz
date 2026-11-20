import { describe, expect, it } from "vitest";
import { ispravanPushToken, juce, mesta, poena, satUBeogradu, tekstPoruke } from "../src/push";

describe("jutarnji push", () => {
  it("8:00 u Beogradu je 7:00 UTC zimi i 6:00 UTC leti", () => {
    expect(satUBeogradu(Date.UTC(2026, 10, 21, 7, 0))).toBe(8);
    expect(satUBeogradu(Date.UTC(2026, 10, 21, 6, 0))).toBe(7);
    expect(satUBeogradu(Date.UTC(2026, 6, 21, 6, 0))).toBe(8);
    expect(satUBeogradu(Date.UTC(2026, 6, 21, 7, 0))).toBe(9);
  });

  it("jučerašnji dan, i na dan pomeranja sata", () => {
    expect(juce(Date.UTC(2026, 10, 21, 7, 0))).toBe("2026-11-20");
    expect(juce(Date.UTC(2026, 2, 29, 6, 0))).toBe("2026-03-28");
    expect(juce(Date.UTC(2026, 9, 25, 7, 0))).toBe("2026-10-24");
  });

  it("mesta kao na top listi, isti rezultat deli mesto", () => {
    const m = mesta([
      { igrac_id: "a", ime: "A", poeni: 10, kraj: 5 },
      { igrac_id: "b", ime: "B", poeni: 20, kraj: 9 },
      { igrac_id: "c", ime: "C", poeni: 10, kraj: 3 },
      { igrac_id: "d", ime: "D", poeni: 10, kraj: 5 },
      { igrac_id: "e", ime: "E", poeni: -2, kraj: 1 },
    ]);
    expect(Object.fromEntries(m)).toEqual({ b: 1, c: 2, a: 3, d: 3, e: 5 });
  });

  it("poen ili poena", () => {
    expect([1, 2, 5, 11, 21, 24, 0, -1].map(poena)).toEqual([
      "1 poen", "2 poena", "5 poena", "11 poena", "21 poen", "24 poena", "0 poena", "-1 poen",
    ]);
  });

  it("tekst poruke", () => {
    expect(tekstPoruke(7, 23, 24, "Dart").tekst).toBe("Juče: 7. mesto od 23, 24 poena. Pobednik: Dart. Novi izazov te čeka!");
    expect(tekstPoruke(1, 23, 31, "Dart")).toEqual({
      naslov: "🏆 Pobeda u dnevnom izazovu!",
      tekst: "Juče: 1. mesto od 23, 31 poen. Novi izazov te čeka!",
    });
    expect(tekstPoruke(1, 1, 12, "Ja").tekst).toBe("Juče: jedini igrač izazova, 12 poena. Novi izazov te čeka!");
  });

  it("push ključ", () => {
    expect(ispravanPushToken("fXyz123:APA91bH-abc_def.ghi" + "x".repeat(40))).toBeTruthy();
    expect(ispravanPushToken("kratak")).toBeNull();
    expect(ispravanPushToken("ima razmak u sebi i dugačak je dovoljno")).toBeNull();
    expect(ispravanPushToken(42)).toBeNull();
  });
});

import { generateKeyPairSync } from "node:crypto";
import { jutarnjiPush } from "../src/push";

describe("jutarnjiPush", () => {
  it("šalje svakom sa ključem, briše nevažeće, bez tajne ne radi ništa", async () => {
    const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
    const servis = JSON.stringify({
      project_id: "kviz-test",
      client_email: "push@kviz-test.iam.gserviceaccount.com",
      private_key: privateKey.export({ type: "pkcs8", format: "pem" }),
    });
    const upiti: string[] = [];
    const brisano: unknown[] = [];
    const db = {
      prepare: (sql: string) => ({
        bind: (...a: unknown[]) => ({ sql, a }),
      }),
      batch: async (st: { sql: string; a: unknown[] }[]) => {
        upiti.push(...st.map((x) => x.sql));
        if (st[0].sql.startsWith("DELETE")) {
          brisano.push(...st.map((x) => x.a[0]));
          return [];
        }
        expect(st[0].a).toEqual(["2026-11-20"]);
        return [
          {
            results: [
              { igrac_id: "a", ime: "Ana", poeni: 24, kraj: 5 },
              { igrac_id: "b", ime: "Dart", poeni: 30, kraj: 9 },
            ],
          },
          { results: [{ token: "t-ana", igrac_id: "a" }, { token: "t-stari", igrac_id: "a" }, { token: "t-dart", igrac_id: "b" }] },
        ];
      },
    } as unknown as D1Database;
    const poslate: { token: string; body: string }[] = [];
    const f = (async (url: string, init: RequestInit) => {
      if (url.includes("oauth2")) return new Response(JSON.stringify({ access_token: "pristup" }));
      expect(url).toBe("https://fcm.googleapis.com/v1/projects/kviz-test/messages:send");
      const m = JSON.parse(init.body as string).message;
      if (m.token === "t-stari") return new Response('{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}', { status: 404 });
      poslate.push({ token: m.token, body: m.notification.body });
      return new Response("{}");
    }) as unknown as typeof fetch;

    const sad = Date.UTC(2026, 10, 21, 7, 0);
    expect(await jutarnjiPush({ DB: db }, sad, f)).toEqual({ poslato: 0, nevazecih: 0 });
    expect(await jutarnjiPush({ DB: db, FCM_SERVIS: servis }, sad, f)).toEqual({ poslato: 2, nevazecih: 1 });
    expect(poslate).toEqual([
      { token: "t-ana", body: "Juče: 2. mesto od 2, 24 poena. Pobednik: Dart. Novi izazov te čeka!" },
      { token: "t-dart", body: "Juče: 1. mesto od 2, 30 poena. Novi izazov te čeka!" },
    ]);
    expect(brisano).toEqual(["t-stari"]);
  });
});
