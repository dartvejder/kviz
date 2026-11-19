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

Postavljanje radi `.github/workflows/server.yml` na main grani (tajne
`CLOUDFLARE_API_TOKEN` i `CLOUDFLARE_ACCOUNT_ID`).

## WebSocket poruke

Klijent šalje: `spreman {da}`, `opcije {vreme, brojPitanja, oblasti}` (moderator),
`prozovi` (moderator), `pokreni` (moderator), `odgovor {pitanje, izbor}`,
`revans` (moderator), `izadji`. Server šalje `stanje` posle svake promene
(tačan odgovor tek u fazi `otkriveno`).
