// Pozivnice: stranica /i/KOD i fajlovi koji telefonu kažu da taj link
// otvara aplikaciju (Android App Links i iPhone Universal Links).
import { KOD_REGEX } from "./igra";

const PAKET = "rs.kviz.app";
const APPLE_TIM = "R3UC6PN8CF";

// Google Play potpisuje aplikaciju svojim ključem, a mi otpremamo svojim.
const OTISCI = [
  "25:F7:98:E0:1E:AE:6B:B3:17:91:6F:47:95:E9:34:73:DF:F0:A4:3C:4D:26:7A:DE:FA:4E:25:E7:60:5C:AC:54", // Play
  "40:41:AA:EE:36:72:60:96:4E:3C:6F:DA:42:1F:1B:39:19:C2:AB:8E:00:9A:81:BA:A1:9F:3B:F0:86:8D:F6:67", // naš ključ
];

const PLAY = `https://play.google.com/store/apps/details?id=${PAKET}`;

const jsonOdgovor = (data: unknown) =>
  new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json", "cache-control": "public, max-age=3600" },
  });

export function wellKnown(put: string): Response | null {
  if (put === "/.well-known/assetlinks.json") {
    return jsonOdgovor([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: { namespace: "android_app", package_name: PAKET, sha256_cert_fingerprints: OTISCI },
      },
    ]);
  }
  if (put === "/.well-known/apple-app-site-association") {
    return jsonOdgovor({
      applinks: { details: [{ appIDs: [`${APPLE_TIM}.${PAKET}`], components: [{ "/": "/i/*" }] }] },
    });
  }
  return null;
}

/** Stranica za onoga ko nema aplikaciju (ili ko otvori link u pregledaču). */
export function stranicaPozivnice(put: string): Response | null {
  const m = put.match(/^\/i\/([A-Za-z0-9]{6})\/?$/);
  if (!m) return null;
  const kod = m[1].toUpperCase();
  if (!KOD_REGEX.test(kod)) return null;
  // Na Androidu "intent:" otvara aplikaciju ako je instalirana, a inače vodi na Play.
  const intent = `intent://kviz.dartchat.trade/i/${kod}#Intent;scheme=https;package=${PAKET};S.browser_fallback_url=${encodeURIComponent(PLAY)};end`;
  const html = `<!doctype html>
<html lang="sr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Poziv u Kviz opšte kulture</title>
<meta property="og:title" content="Igraj Kviz opšte kulture sa mnom!">
<meta property="og:description" content="Kod sobe: ${kod}">
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#0F1E6E;color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
main{max-width:420px;padding:24px}
.kod{font-size:44px;font-weight:800;letter-spacing:8px;margin:12px 0 24px;color:#FFD34D}
a.dugme{display:block;background:#FFD34D;color:#0F1E6E;font-weight:700;font-size:18px;padding:16px;border-radius:16px;text-decoration:none;margin:12px 0}
a.sporedno{background:transparent;color:#fff;border:2px solid #FFD34D}
p{opacity:.85}
</style></head><body><main>
<h1>Pozvan si u kviz!</h1>
<p>Kod sobe</p>
<div class="kod">${kod}</div>
<a class="dugme" id="otvori" href="${intent}">Otvori u aplikaciji</a>
<a class="dugme sporedno" href="${PLAY}">Preuzmi za Android</a>
<p>Na iPhone-u: otvori aplikaciju Kviz, klikni „Uđi kodom” i upiši kod.</p>
</main>
<script>if(!/Android/i.test(navigator.userAgent)){document.getElementById('otvori').style.display='none'}</script>
</body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}
