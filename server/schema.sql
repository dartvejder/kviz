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
