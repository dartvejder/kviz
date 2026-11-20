// Upisuje podrazumevanu temu u aplikaciju (app/assets/tema-studio.json),
// da aplikacija ima izgled i pre prvog preuzimanja sa servera.
import { writeFileSync } from "node:fs";
import { PODRAZUMEVANA, tema } from "../src/teme";

const t = await tema(PODRAZUMEVANA);
writeFileSync(new URL("../../app/assets/tema-studio.json", import.meta.url), JSON.stringify(t, null, 1) + "\n");
console.log("Upisano:", t?.id, t?.verzija);
