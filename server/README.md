# Kviz server

Cloudflare Worker na `kviz.dartchat.trade/api/*` i `/ws/*`, jedan Durable
Object (`Soba`) po sobi, D1 baza `kviz`.

- `src/igra.ts` – bodovanje (+3 tačan, +2 najbrži tačan, −1 netačan), opcije, mešanje
- `src/soba.ts` – soba: čekaonica, spremnost, prozivka, tajmer (alarm), kraj partije, revanš
- `src/index.ts` – API: `POST /api/igraci`, `GET|PUT|DELETE /api/igraci/ja`, `POST /api/sobe`,
  `GET /api/oblasti`, `GET /api/top?period=dan|nedelja|sve&poredak=ukupno|prosek`, `GET /ws/KOD`
- `schema.sql` – tabele; `scripts/pitanja-sql.mjs` – pitanja iz `questions.js` u SQL

Lokalno:

```
npm ci
npx wrangler d1 execute kviz --local --file schema.sql
npm run pitanja && npx wrangler d1 execute kviz --local --file build/pitanja.sql
npx wrangler dev
```

## Dart Chat

Ugovor: https://claude.ai/artifact/UvZjUecCpVXmjfU7fEXoWg. Kod je u `src/dartchat.ts`.

- `GET /api/dartchat/ja`, `POST /api/dartchat/sobe`, `GET /api/dartchat/sobe/KOD` – zaglavlje `Authorization: DartChat <token>`
- `POST /api/dartchat/povezi {openid_token}` – Kviz nalog (`Bearer ID.TOKEN`) dobija Matrix ID
- Token proverava Dart Chat dodatak (`POST /_dartchat/v1/quiz/whoami`); Kviz pamti samo otisak, najviše 1 h.
- Soba iz Dart Chata javlja `usao`, `pocelo`, `kraj`, `istekla` na `POST /_dartchat/v1/quiz/status`.

Podešavanja Workera (Cloudflare → Workers → kviz-server → Settings → Variables):
`DARTCHAT_URL` (npr. `https://chat.dartchat.trade`), tajna `KVIZ_KLJUC` (ista kao `quiz_api_key` u Home Assistantu)
i, samo za probu, `DARTCHAT_TEST=1` (prihvata token `test:@ime:chat.dartchat.trade`). Bez njih Dart Chat putanje
vraćaju 503, a ostatak servera radi kao i pre.

Lokalno: `npx wrangler dev --var DARTCHAT_TEST:1`.

Postavljanje radi `.github/workflows/server.yml` na main grani (tajna
`CLOUDFLARE_API_TOKEN`).

## WebSocket poruke

Klijent šalje: `spreman {da}`, `opcije {vreme, brojPitanja, oblasti}` (moderator),
`prozovi` (moderator), `pokreni` (moderator), `odgovor {pitanje, izbor}`,
`revans` (moderator), `izadji`. Server šalje `stanje` posle svake promene
(tačan odgovor tek u fazi `otkriveno`).
