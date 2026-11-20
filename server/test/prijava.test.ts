import { describe, expect, it } from "vitest";
import { PrijavaGreska, proveriIdToken } from "../src/prijava";

const b64 = (x: Uint8Array | string) =>
  btoa(String.fromCharCode(...(typeof x === "string" ? new TextEncoder().encode(x) : x)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

async function provajder() {
  const par = (await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
  const jwk = { ...(await crypto.subtle.exportKey("jwk", par.publicKey)), kid: "k1" };
  const potpisi = async (telo: Record<string, unknown>, kid = "k1") => {
    const glava = b64(JSON.stringify({ alg: "RS256", kid }));
    const sadrzaj = b64(JSON.stringify(telo));
    const potpis = new Uint8Array(
      await crypto.subtle.sign("RSASSA-PKCS1-v1_5", par.privateKey, new TextEncoder().encode(`${glava}.${sadrzaj}`)),
    );
    return `${glava}.${sadrzaj}.${b64(potpis)}`;
  };
  const f = (async () => new Response(JSON.stringify({ keys: [jwk] }))) as unknown as typeof fetch;
  return { potpisi, f };
}

const SAD = 1_800_000_000_000;
const env = { GOOGLE_CLIENT_IDS: "web.apps.googleusercontent.com, ios.apps.googleusercontent.com", APPLE_AUDIENCE: "rs.kviz.app" };

describe("prijava preko Google/Apple", () => {
  it("prihvata ispravan Google token i vraća sub i ime", async () => {
    const { potpisi, f } = await provajder();
    const token = await potpisi({
      iss: "https://accounts.google.com",
      aud: "ios.apps.googleusercontent.com",
      sub: "1234",
      name: "Marko Marković",
      exp: SAD / 1000 + 600,
    });
    expect(await proveriIdToken("google", token, env, f, SAD)).toEqual({ provajder: "google", sub: "1234", ime: "Marko Marković" });
  });

  it("odbija tuđu aplikaciju, istekao token i loš potpis", async () => {
    const { potpisi, f } = await provajder();
    const tudji = await potpisi({ iss: "https://appleid.apple.com", aud: "com.drugi", sub: "a", exp: SAD / 1000 + 600 });
    await expect(proveriIdToken("apple", tudji, env, f, SAD)).rejects.toThrow("nije za ovu aplikaciju");
    const istekao = await potpisi({ iss: "https://appleid.apple.com", aud: "rs.kviz.app", sub: "a", exp: SAD / 1000 - 600 });
    await expect(proveriIdToken("apple", istekao, env, f, SAD)).rejects.toThrow("istekla");
    const dobar = await potpisi({ iss: "https://appleid.apple.com", aud: "rs.kviz.app", sub: "a", exp: SAD / 1000 + 600 });
    const [g, t] = dobar.split(".");
    const lazni = `${g}.${b64(JSON.stringify({ iss: "https://appleid.apple.com", aud: "rs.kviz.app", sub: "b", exp: SAD / 1000 + 600 }))}.${dobar.split(".")[2]}`;
    await expect(proveriIdToken("apple", lazni, env, f, SAD)).rejects.toBeInstanceOf(PrijavaGreska);
    expect((await proveriIdToken("apple", `${g}.${t}.${dobar.split(".")[2]}`, env, f, SAD)).sub).toBe("a");
  });

  it("bez podešenih client ID-jeva prijava nije uključena", async () => {
    const { potpisi, f } = await provajder();
    const token = await potpisi({ iss: "accounts.google.com", aud: "x", sub: "1", exp: SAD / 1000 + 600 });
    await expect(proveriIdToken("google", token, {}, f, SAD)).rejects.toMatchObject({ status: 503 });
  });
});
