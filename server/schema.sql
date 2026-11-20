-- Kviz baza (D1). Pitanja se pune iz questions.js (scripts/pitanja-sql.mjs).
CREATE TABLE IF NOT EXISTS pitanja (
  id INTEGER PRIMARY KEY,
  oblast TEXT NOT NULL,
  tekst TEXT NOT NULL,
  tacan TEXT NOT NULL,
  netacan1 TEXT NOT NULL,
  netacan2 TEXT NOT NULL,
  netacan3 TEXT NOT NULL,
  kljuc TEXT NOT NULL UNIQUE          -- normalizovan tekst, da id ostane isti pri ponovnom uvozu
);
CREATE INDEX IF NOT EXISTS pitanja_oblast ON pitanja(oblast);

-- Otisak poslednjeg uvoza pitanja, da se isti sadržaj ne uvozi ponovo.
CREATE TABLE IF NOT EXISTS uvoz (
  kljuc TEXT PRIMARY KEY,
  vrednost TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS igraci (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL,
  ime TEXT NOT NULL,
  avatar TEXT NOT NULL,
  napravljen INTEGER NOT NULL
);

-- Koja pitanja je igrač već video, da se ne ponavljaju.
CREATE TABLE IF NOT EXISTS odigrano (
  igrac_id TEXT NOT NULL,
  pitanje_id INTEGER NOT NULL,
  PRIMARY KEY (igrac_id, pitanje_id)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS igre (
  id TEXT PRIMARY KEY,
  soba TEXT NOT NULL,
  pocetak INTEGER NOT NULL,
  kraj INTEGER NOT NULL,
  broj_pitanja INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS rezultati (
  igra_id TEXT NOT NULL,
  igrac_id TEXT NOT NULL,
  poeni INTEGER NOT NULL,
  tacnih INTEGER NOT NULL,
  kraj INTEGER NOT NULL,
  PRIMARY KEY (igra_id, igrac_id)
);
CREATE INDEX IF NOT EXISTS rezultati_kraj ON rezultati(kraj);
CREATE INDEX IF NOT EXISTS rezultati_igrac ON rezultati(igrac_id);

-- Statistika igrača po oblastima (zbir svih partija).
CREATE TABLE IF NOT EXISTS statistika (
  igrac_id TEXT NOT NULL,
  oblast TEXT NOT NULL,
  tacnih INTEGER NOT NULL,
  ukupno INTEGER NOT NULL,
  PRIMARY KEY (igrac_id, oblast)
) WITHOUT ROWID;

-- Dnevni izazov: jedan pokušaj dnevno po igraču.
CREATE TABLE IF NOT EXISTS izazov (
  igrac_id TEXT NOT NULL,
  dan TEXT NOT NULL,
  poeni INTEGER NOT NULL,
  tacnih INTEGER NOT NULL,
  kraj INTEGER NOT NULL,
  PRIMARY KEY (dan, igrac_id)
) WITHOUT ROWID;

-- Dart Chat: jedan Matrix ID je povezan sa najviše jednim Kviz nalogom (novo povezivanje preuzima vezu).
CREATE TABLE IF NOT EXISTS dartchat_veze (
  matrix_id TEXT PRIMARY KEY,
  igrac_id TEXT NOT NULL UNIQUE,
  povezan INTEGER NOT NULL
) WITHOUT ROWID;

-- Provereni Dart Chat tokeni (po SHA-256 otisku, ne sam token), dok važe a najviše 1 h.
CREATE TABLE IF NOT EXISTS dartchat_tokeni (
  hash TEXT PRIMARY KEY,
  matrix_id TEXT NOT NULL,
  ime TEXT NOT NULL,
  istice INTEGER NOT NULL
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS dartchat_tokeni_istice ON dartchat_tokeni(istice);

-- Nalozi Google Play robota (Firebase Test Lab, pre-launch izveštaj): ne prikazuju se na top listama.
CREATE TABLE IF NOT EXISTS roboti (
  igrac_id TEXT PRIMARY KEY,
  vreme INTEGER NOT NULL
) WITHOUT ROWID;

-- Prijave loših pitanja (jedna po igraču i pitanju; nova zamenjuje staru).
CREATE TABLE IF NOT EXISTS prijave (
  pitanje_id INTEGER NOT NULL,
  igrac_id TEXT NOT NULL,
  razlog TEXT NOT NULL,
  napomena TEXT NOT NULL DEFAULT '',
  vreme INTEGER NOT NULL,
  PRIMARY KEY (pitanje_id, igrac_id)
) WITHOUT ROWID;

-- Uspeh svih igrača po pitanju: od toga se računa težina (lako / srednje / teško).
CREATE TABLE IF NOT EXISTS pitanja_stat (
  pitanje_id INTEGER PRIMARY KEY,
  tacnih INTEGER NOT NULL,
  ukupno INTEGER NOT NULL
);

-- Osvojene značke (spisak značaka je u src/igra.ts, ZNACKE).
CREATE TABLE IF NOT EXISTS znacke (
  igrac_id TEXT NOT NULL,
  znacka TEXT NOT NULL,
  vreme INTEGER NOT NULL,
  PRIMARY KEY (igrac_id, znacka)
) WITHOUT ROWID;

-- Pozivi prijateljima u sobu (važe 24 sata, dok soba traje).
CREATE TABLE IF NOT EXISTS pozivi (
  kome TEXT NOT NULL,
  kod TEXT NOT NULL,
  od TEXT NOT NULL,
  vreme INTEGER NOT NULL,
  PRIMARY KEY (kome, kod)
) WITHOUT ROWID;

-- Prijava preko Google/Apple naloga (opciona): koji nalog provajdera čuva koji Kviz nalog.
CREATE TABLE IF NOT EXISTS veze_naloga (
  provajder TEXT NOT NULL,            -- google | apple
  sub TEXT NOT NULL,                  -- stalni ID korisnika kod provajdera (mejl se ne čuva)
  igrac_id TEXT NOT NULL,
  povezan INTEGER NOT NULL,
  PRIMARY KEY (provajder, sub)
) WITHOUT ROWID;
CREATE UNIQUE INDEX IF NOT EXISTS veze_naloga_igrac ON veze_naloga(igrac_id, provajder);

-- Dodatni tokeni istog igrača (drugi telefon posle prijave), po SHA-256 otisku.
CREATE TABLE IF NOT EXISTS tokeni (
  hash TEXT PRIMARY KEY,
  igrac_id TEXT NOT NULL,
  napravljen INTEGER NOT NULL
) WITHOUT ROWID;

-- Push ključevi (FCM) telefona, za jutarnju poruku sa rezultatom izazova.
-- Upisuje se samo kad se ključ promeni ili jednom nedeljno, da se štede D1 upisi.
CREATE TABLE IF NOT EXISTS push_kljucevi (
  token TEXT PRIMARY KEY,
  igrac_id TEXT NOT NULL,
  platforma TEXT NOT NULL,
  azuriran INTEGER NOT NULL
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS push_kljucevi_igrac ON push_kljucevi(igrac_id);
