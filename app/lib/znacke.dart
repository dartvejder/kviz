// Značke: isti spisak kao na serveru (server/src/igra.ts, ZNACKE), za prikaz "Nova značka!" bez čekanja.
const znacke = <String, (String, String)>{
  'pobeda': ('🏆', 'Prva pobeda'),
  'savrseno': ('💯', 'Savršena partija'),
  'zaredom10': ('🔥', 'Deset zaredom'),
  'munja': ('⚡', 'Munja'),
  'drustvo': ('🎉', 'Veliko društvo'),
  'tim': ('🤝', 'Timski igrač'),
  'partija10': ('🎯', 'Deset partija'),
  'partija100': ('🏅', 'Sto partija'),
  'izazov7': ('📅', 'Nedelja izazova'),
  'izazov30': ('🗓️', 'Mesec izazova'),
};

/// Poruka u sobi za niz tačnih zaredom: na 3, 5, 10, 15... (null kad nema poruke).
String? porukaZaredom(int zaredom) {
  if (zaredom == 3) return '3 tačna zaredom';
  if (zaredom >= 5 && zaredom % 5 == 0) return '$zaredom tačnih zaredom!';
  return null;
}
