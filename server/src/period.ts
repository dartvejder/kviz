// Periodi top liste po beogradskom vremenu.

/** Početak današnjeg dana i ove nedelje (ponedeljak) po beogradskom vremenu, u ms. */
export function pocetakPerioda(period: string, sad = Date.now()): number {
  if (period === "sve") return 0;
  const delovi = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Belgrade",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
    weekday: "short",
  }).formatToParts(new Date(sad));
  const d = Object.fromEntries(delovi.map((p) => [p.type, p.value]));
  const lokalnoKaoUtc = Date.UTC(+d.year, +d.month - 1, +d.day, +d.hour, +d.minute, +d.second);
  const pomak = lokalnoKaoUtc - Math.floor(sad / 1000) * 1000; // razlika Beograd − UTC
  let ponoc = Date.UTC(+d.year, +d.month - 1, +d.day) - pomak;
  if (period === "nedelja") {
    const dani = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indexOf(d.weekday);
    ponoc -= dani * 24 * 60 * 60 * 1000;
  }
  return ponoc;
}

/** Današnji dan po beogradskom vremenu, "2026-11-20". */
export function danas(sad = Date.now()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Belgrade", year: "numeric", month: "2-digit", day: "2-digit" }).format(
    new Date(sad),
  );
}
