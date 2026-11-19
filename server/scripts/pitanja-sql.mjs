// Pravi SQL za D1 iz questions.js (izvor ostaju src/*.txt + src/build.py).
// Upotreba: node scripts/pitanja-sql.mjs ../questions.js build/pitanja.sql
// Ključ je normalizovan tekst pitanja, pa ponovni uvoz menja postojeće redove
// umesto da pravi duplikate, i id pitanja ostaje isti (bitno za "odigrano").
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

const [ulaz = "../questions.js", izlaz = "build/pitanja.sql"] = process.argv.slice(2);
const js = readFileSync(ulaz, "utf8");
const BANK = new Function(js + "\nreturn BANK;")();

export const kljuc = (t) => t.toLowerCase().normalize("NFC").replace(/\s+/g, " ").replace(/[„”“"?.!,]/g, "").trim();
const s = (x) => "'" + String(x).replace(/'/g, "''") + "'";

const redovi = [];
const vidjeni = new Set();
for (const q of BANK) {
  if (!Array.isArray(q) || q.length !== 6) throw new Error("Loše pitanje: " + JSON.stringify(q));
  const k = kljuc(q[1]);
  if (vidjeni.has(k)) continue;
  vidjeni.add(k);
  redovi.push(`(${q.map(s).join(", ")}, ${s(k)})`);
}

let sql = "";
for (let i = 0; i < redovi.length; i += 200) {
  sql +=
    "INSERT INTO pitanja (oblast, tekst, tacan, netacan1, netacan2, netacan3, kljuc) VALUES\n" +
    redovi.slice(i, i + 200).join(",\n") +
    "\nON CONFLICT(kljuc) DO UPDATE SET oblast = excluded.oblast, tekst = excluded.tekst, tacan = excluded.tacan," +
    " netacan1 = excluded.netacan1, netacan2 = excluded.netacan2, netacan3 = excluded.netacan3;\n";
}
mkdirSync(dirname(izlaz), { recursive: true });
writeFileSync(izlaz, sql);
console.log(`${redovi.length} pitanja → ${izlaz}`);
