// Teme izgleda aplikacije. Aplikacija preuzme izabranu temu i čuva je na
// telefonu; kad se tema ovde promeni, menja joj se "verzija" (otisak sadržaja)
// pa je telefon pri sledećem pokretanju preuzme ponovo.
//
// Nova tema: dodaj objekat u TEME (jedinstven id) i postavi server.
// Boje su "#RRGGBB" ili "#RRGGBBAA". Fontovi su imena sa Google Fonts koja
// imaju srpska latinična slova (č, ć, š, ž, đ).
//
// Pozadina: osnovna boja + slojevi gradijenata (prvi je na dnu).
//   linear: { tip, boje, stopovi?, ugao? } ugao 180 = odozgo nadole
//   radial: { tip, boje, stopovi?, centar: [x, y] od -1 do 1, radijus: deo šire strane }
// Ukrasi su crteži ugrađeni u aplikaciju, kojima tema daje boje:
//   reflektori, neonMreza, krugovi, cilim, ram, mehurici, zvezde, planeta, pikselOblaci

type Boja = string;

export interface Senka {
  x: number;
  y: number;
  blur: number;
  boja: Boja;
}

export interface Gradijent {
  tip: "linear" | "radial";
  boje: Boja[];
  stopovi?: number[];
  ugao?: number;
  centar?: [number, number];
  radijus?: number;
}

export interface Ukras {
  tip: string;
  [k: string]: unknown;
}

export interface Tema {
  id: string;
  naziv: string;
  opis: string;
  svetla: boolean;
  font: { naslov: string; tekst: string; naslovTezina: number; skala?: number };
  logo: { tekst?: string; velicina: number; razmak?: number; kurziv?: boolean; senke?: Senka[]; gradijent?: Boja[] };
  boje: {
    tekst: Boja;
    povrsina: Boja;
    povrsina2: Boja;
    naPovrsini?: Boja;
    primarna: Boja;
    naPrimarnoj: Boja;
    tacno: Boja;
    netacno: Boja;
    logo: Boja;
    podnaslov?: Boja;
    slovoPozadina: Boja;
    slovoTekst: Boja;
    tajmerPozadina: Boja;
    ivica?: Boja;
    ivicaPrimarna?: Boja;
    istaknut?: Boja;
  };
  pozadina: { boja: Boja; slojevi: Gradijent[] };
  dugme: {
    zaobljenje: number;
    ivica?: number;
    isprekidana?: boolean;
    senka?: Senka[];
    senkaPrimarna?: Senka[];
    slovoZaobljenje?: number;
  };
  traka: Boja[];
  odgovori: "lista" | "mreza";
  bojeOdgovora?: Boja[];
  ukrasi: Ukras[];
  /** Tri boje za sličicu u Podešavanjima. */
  uzorak: Boja[];
}

export const PODRAZUMEVANA = "studio";

export const TEME: Tema[] = [
  {
    id: "studio",
    naziv: "Studio",
    opis: "Večernji TV kviz: reflektori i zlatna dugmad.",
    svetla: false,
    font: { naslov: "Montserrat", tekst: "Nunito Sans", naslovTezina: 800 },
    logo: {
      velicina: 56,
      senke: [
        { x: 0, y: 3, blur: 0, boja: "#b5741b" },
        { x: 0, y: 0, blur: 28, boja: "#ffd65a73" },
      ],
    },
    boje: {
      tekst: "#ffffff",
      povrsina: "#ffffff17",
      povrsina2: "#ffffff12",
      primarna: "#ffc83d",
      naPrimarnoj: "#1a1340",
      tacno: "#21b26b",
      netacno: "#e2463f",
      logo: "#ffd65a",
      slovoPozadina: "#ffc83d",
      slovoTekst: "#1a1340",
      tajmerPozadina: "#0d1557",
      ivica: "#ffffff24",
    },
    pozadina: {
      boja: "#070b36",
      slojevi: [
        {
          tip: "radial",
          centar: [0, -1.15],
          radijus: 1.6,
          boje: ["#3e56d6", "#1a2780", "#0a1150", "#070b36"],
          stopovi: [0, 0.38, 0.7, 1],
        },
      ],
    },
    dugme: { zaobljenje: 14, ivica: 1, senkaPrimarna: [{ x: 0, y: 6, blur: 22, boja: "#ffc83d59" }] },
    traka: ["#ffc83d", "#ff8a3d"],
    odgovori: "lista",
    ukrasi: [{ tip: "reflektori", boja: "#ffecaa3d" }],
    uzorak: ["#0a1150", "#3e56d6", "#ffc83d"],
  },
  {
    id: "neon",
    naziv: "Neon",
    opis: "Arkada iz osamdesetih: svetleće roze i tirkizne ivice.",
    svetla: false,
    font: { naslov: "Exo 2", tekst: "Exo 2", naslovTezina: 800 },
    logo: {
      velicina: 58,
      kurziv: true,
      senke: [
        { x: 0, y: 0, blur: 6, boja: "#ffffff" },
        { x: 0, y: 0, blur: 16, boja: "#ff2fb3" },
        { x: 0, y: 0, blur: 34, boja: "#ff2fb3" },
      ],
    },
    boje: {
      tekst: "#f4ecff",
      povrsina: "#ffffff0a",
      povrsina2: "#22e6ff12",
      primarna: "#ff2fb3",
      naPrimarnoj: "#ffffff",
      tacno: "#13c98b",
      netacno: "#ff3d5a",
      logo: "#ffffff",
      podnaslov: "#22e6ff",
      slovoPozadina: "#00000000",
      slovoTekst: "#22e6ff",
      tajmerPozadina: "#1a0538",
      ivica: "#22e6ff8c",
      ivicaPrimarna: "#ff8ad6",
    },
    pozadina: {
      boja: "#120327",
      slojevi: [{ tip: "linear", ugao: 180, boje: ["#120327", "#1d0640", "#2b0a52"], stopovi: [0, 0.55, 1] }],
    },
    dugme: {
      zaobljenje: 10,
      ivica: 1.5,
      slovoZaobljenje: 4,
      senka: [{ x: 0, y: 0, blur: 12, boja: "#22e6ff38" }],
      senkaPrimarna: [{ x: 0, y: 0, blur: 18, boja: "#ff2fb3bf" }],
    },
    traka: ["#22e6ff", "#ff2fb3"],
    odgovori: "lista",
    ukrasi: [{ tip: "neonMreza", boja: "#ff2fb38c" }],
    uzorak: ["#1d0640", "#ff2fb3", "#22e6ff"],
  },
  {
    id: "bojanka",
    naziv: "Bojanka",
    opis: "Svetla i vesela, četiri obojena polja za odgovore.",
    svetla: true,
    font: { naslov: "Baloo 2", tekst: "Baloo 2", naslovTezina: 800 },
    logo: { tekst: "Kviz!", velicina: 60 },
    boje: {
      tekst: "#1f2a44",
      povrsina: "#ffffff",
      povrsina2: "#ffffff",
      primarna: "#5b3df5",
      naPrimarnoj: "#ffffff",
      tacno: "#1fb46a",
      netacno: "#f0473c",
      logo: "#5b3df5",
      slovoPozadina: "#ffffff4d",
      slovoTekst: "#ffffff",
      tajmerPozadina: "#ffffff",
      istaknut: "#5b3df5",
    },
    pozadina: { boja: "#f1f6ff", slojevi: [] },
    dugme: {
      zaobljenje: 18,
      slovoZaobljenje: 10,
      senka: [{ x: 0, y: 4, blur: 0, boja: "#d5dcec" }],
      senkaPrimarna: [{ x: 0, y: 5, blur: 0, boja: "#3a22b8" }],
    },
    traka: ["#ffb300", "#ffb300"],
    odgovori: "mreza",
    bojeOdgovora: ["#ff5d73", "#2f8cff", "#ffa21f", "#18b38f"],
    ukrasi: [
      {
        tip: "krugovi",
        krugovi: [
          { x: 0.12, y: 0.18, r: 0.16, boja: "#ffd8e4" },
          { x: 0.92, y: 0.08, r: 0.22, boja: "#d6ecff" },
          { x: 0.85, y: 0.92, r: 0.24, boja: "#fff0bf" },
        ],
      },
    ],
    uzorak: ["#ff5d73", "#2f8cff", "#ffa21f"],
  },
  {
    id: "pirot",
    naziv: "Pirot",
    opis: "Šara pirotskog ćilima: crvena, crna i krem.",
    svetla: true,
    font: { naslov: "Alegreya", tekst: "Alegreya Sans", naslovTezina: 800 },
    logo: { velicina: 56 },
    boje: {
      tekst: "#2a1414",
      povrsina: "#fffaf2",
      povrsina2: "#fffaf2",
      primarna: "#a3161a",
      naPrimarnoj: "#fff7ea",
      tacno: "#2f6b3a",
      netacno: "#a3161a",
      logo: "#a3161a",
      slovoPozadina: "#2a1414",
      slovoTekst: "#f6efe4",
      tajmerPozadina: "#f6efe4",
      ivica: "#2a1414",
      ivicaPrimarna: "#2a1414",
    },
    pozadina: { boja: "#f6efe4", slojevi: [] },
    dugme: {
      zaobljenje: 6,
      ivica: 1.5,
      slovoZaobljenje: 3,
      senka: [{ x: 3, y: 3, blur: 0, boja: "#2a1414" }],
      senkaPrimarna: [{ x: 3, y: 3, blur: 0, boja: "#2a1414" }],
    },
    traka: ["#a3161a", "#2a1414"],
    odgovori: "lista",
    ukrasi: [{ tip: "cilim", boje: ["#e7b34a", "#a3161a", "#2a1414"], visina: 34 }],
    uzorak: ["#f6efe4", "#a3161a", "#2a1414"],
  },
  {
    id: "tabla",
    naziv: "Školska tabla",
    opis: "Zelena tabla u drvenom ramu, sve ispisano kredom.",
    svetla: false,
    font: { naslov: "Patrick Hand", tekst: "Patrick Hand", naslovTezina: 400, skala: 1.2 },
    logo: { velicina: 68, senke: [{ x: 0, y: 0, blur: 2, boja: "#ffffff99" }] },
    boje: {
      tekst: "#f4f2ea",
      povrsina: "#ffffff0d",
      povrsina2: "#ffffff0f",
      primarna: "#ffe27a",
      naPrimarnoj: "#2d4a3b",
      tacno: "#4f9a57",
      netacno: "#c4564c",
      logo: "#ffffff",
      slovoPozadina: "#00000000",
      slovoTekst: "#ffe27a",
      tajmerPozadina: "#2d4a3b",
      ivica: "#f4f2ea99",
      ivicaPrimarna: "#ffe27a",
    },
    pozadina: {
      boja: "#2d4a3b",
      slojevi: [
        { tip: "radial", centar: [-0.4, -0.6], radijus: 0.6, boje: ["#ffffff12", "#ffffff00"] },
        { tip: "radial", centar: [0.6, 0.4], radijus: 0.5, boje: ["#ffffff0d", "#ffffff00"] },
      ],
    },
    dugme: { zaobljenje: 10, ivica: 2, isprekidana: true, slovoZaobljenje: 99 },
    traka: ["#f4f2ea", "#f4f2ea"],
    odgovori: "lista",
    ukrasi: [{ tip: "ram", boja: "#8a5a33", boja2: "#5b3a1f", debljina: 10 }],
    uzorak: ["#2d4a3b", "#8a5a33", "#ffe27a"],
  },
  {
    id: "okean",
    naziv: "Okean",
    opis: "Od tirkizne površine do dubokog plavog dna.",
    svetla: false,
    font: { naslov: "Comfortaa", tekst: "Comfortaa", naslovTezina: 700 },
    logo: { velicina: 56, senke: [{ x: 0, y: 4, blur: 0, boja: "#00285059" }] },
    boje: {
      tekst: "#ffffff",
      povrsina: "#ffffff29",
      povrsina2: "#001e3c47",
      primarna: "#ff7a59",
      naPrimarnoj: "#ffffff",
      tacno: "#14b88a",
      netacno: "#ff5370",
      logo: "#ffffff",
      slovoPozadina: "#ffffffe6",
      slovoTekst: "#0b7fae",
      tajmerPozadina: "#0b6d99",
      ivica: "#ffffff4d",
    },
    pozadina: {
      boja: "#05213f",
      slojevi: [
        { tip: "linear", ugao: 180, boje: ["#19c6d6", "#0b7fae", "#073a6b", "#05213f"], stopovi: [0, 0.42, 0.78, 1] },
        { tip: "radial", centar: [0, -1.1], radijus: 0.7, boje: ["#ffffff59", "#ffffff00"] },
      ],
    },
    dugme: {
      zaobljenje: 26,
      ivica: 1,
      slovoZaobljenje: 99,
      senkaPrimarna: [{ x: 0, y: 6, blur: 16, boja: "#ff7a5973" }],
    },
    traka: ["#ffd166", "#ffd166"],
    odgovori: "lista",
    ukrasi: [{ tip: "mehurici", boja: "#ffffff2e" }],
    uzorak: ["#19c6d6", "#073a6b", "#ff7a59"],
  },
  {
    id: "retro",
    naziv: "Retro 70",
    opis: "Senf, narandžasta i braon, pruge zalaska sunca.",
    svetla: true,
    font: { naslov: "Righteous", tekst: "Nunito Sans", naslovTezina: 400 },
    logo: {
      velicina: 64,
      senke: [
        { x: 3, y: 3, blur: 0, boja: "#e7832b" },
        { x: 6, y: 6, blur: 0, boja: "#c4471d" },
        { x: 9, y: 9, blur: 0, boja: "#6b3a1e" },
      ],
    },
    boje: {
      tekst: "#3b2314",
      povrsina: "#fbeccb",
      povrsina2: "#fbeccb",
      primarna: "#c4471d",
      naPrimarnoj: "#fff4de",
      tacno: "#5c8f3a",
      netacno: "#a83a1f",
      logo: "#f5c23d",
      podnaslov: "#6b3a1e",
      slovoPozadina: "#e7832b",
      slovoTekst: "#ffffff",
      tajmerPozadina: "#f3d9a4",
      ivica: "#6b3a1e",
      ivicaPrimarna: "#6b3a1e",
    },
    pozadina: {
      boja: "#f3d9a4",
      slojevi: [
        {
          tip: "linear",
          ugao: 180,
          boje: ["#f3d9a4", "#f3d9a4", "#e7832b", "#e7832b", "#f5c23d", "#f5c23d", "#c4471d", "#c4471d", "#6b3a1e", "#6b3a1e"],
          stopovi: [0, 0.8, 0.8, 0.84, 0.84, 0.88, 0.88, 0.92, 0.92, 1],
        },
      ],
    },
    dugme: { zaobljenje: 28, ivica: 2, slovoZaobljenje: 99 },
    traka: ["#e7832b", "#c4471d"],
    odgovori: "lista",
    ukrasi: [],
    uzorak: ["#f5c23d", "#e7832b", "#6b3a1e"],
  },
  {
    id: "bela",
    naziv: "Bela",
    opis: "Čista i mirna, bez ukrasa.",
    svetla: true,
    font: { naslov: "Inter", tekst: "Inter", naslovTezina: 800 },
    logo: { tekst: "Kviz.", velicina: 58, razmak: -2.5 },
    boje: {
      tekst: "#121214",
      povrsina: "#f1f1f3",
      povrsina2: "#f6f6f8",
      primarna: "#121214",
      naPrimarnoj: "#ffffff",
      tacno: "#16a34a",
      netacno: "#dc2626",
      logo: "#121214",
      slovoPozadina: "#ffffff",
      slovoTekst: "#121214",
      tajmerPozadina: "#ffffff",
      istaknut: "#2563eb",
    },
    pozadina: { boja: "#ffffff", slojevi: [] },
    dugme: { zaobljenje: 12, slovoZaobljenje: 6 },
    traka: ["#2563eb", "#2563eb"],
    odgovori: "lista",
    ukrasi: [],
    uzorak: ["#ffffff", "#121214", "#2563eb"],
  },
  {
    id: "svemir",
    naziv: "Svemir",
    opis: "Zvezdano nebo, maglina i planeta sa prstenom.",
    svetla: false,
    font: { naslov: "Space Grotesk", tekst: "Space Grotesk", naslovTezina: 700 },
    logo: { velicina: 58, gradijent: ["#ffffff", "#a99dff"] },
    boje: {
      tekst: "#e8ecff",
      povrsina: "#ffffff0f",
      povrsina2: "#ffffff0f",
      primarna: "#8b7bff",
      naPrimarnoj: "#ffffff",
      tacno: "#22c55e",
      netacno: "#f43f5e",
      logo: "#ffffff",
      slovoPozadina: "#8b7bff40",
      slovoTekst: "#cfc8ff",
      tajmerPozadina: "#0a0b25",
      ivica: "#a0b4ff47",
    },
    pozadina: {
      boja: "#05061a",
      slojevi: [
        { tip: "radial", centar: [0.6, -0.7], radijus: 0.9, boje: ["#8c46dc8c", "#8c46dc00"] },
        { tip: "radial", centar: [-0.8, 0.7], radijus: 0.9, boje: ["#145ab480", "#145ab400"] },
      ],
    },
    dugme: {
      zaobljenje: 16,
      ivica: 1,
      slovoZaobljenje: 99,
      senkaPrimarna: [{ x: 0, y: 0, blur: 24, boja: "#8b7bff99" }],
    },
    traka: ["#5eead4", "#8b7bff"],
    odgovori: "lista",
    ukrasi: [
      { tip: "zvezde", boja: "#ffffff", broj: 70 },
      { tip: "planeta", boje: ["#ffb38a", "#d0533c", "#5a1a2e"], prsten: "#ffd2b48c" },
    ],
    uzorak: ["#05061a", "#8c46dc", "#ffb38a"],
  },
  {
    id: "piksel",
    naziv: "Piksel",
    opis: "Stara video igra: krupni pikseli i četvrtasta dugmad.",
    svetla: false,
    font: { naslov: "VT323", tekst: "VT323", naslovTezina: 400, skala: 1.4 },
    logo: {
      velicina: 76,
      senke: [
        { x: 4, y: 4, blur: 0, boja: "#c0392b" },
        { x: 8, y: 8, blur: 0, boja: "#000000" },
      ],
    },
    boje: {
      tekst: "#ffffff",
      povrsina: "#f4f4f4",
      povrsina2: "#00000059",
      naPovrsini: "#1b1b2f",
      primarna: "#ffcc00",
      naPrimarnoj: "#1b1b2f",
      tacno: "#2fae3f",
      netacno: "#e43b44",
      logo: "#ffcc00",
      slovoPozadina: "#1b1b2f",
      slovoTekst: "#ffcc00",
      tajmerPozadina: "#ffcc00",
      ivica: "#000000",
      ivicaPrimarna: "#000000",
    },
    pozadina: {
      boja: "#2a2a5c",
      slojevi: [
        {
          tip: "linear",
          ugao: 180,
          boje: ["#2a2a5c", "#4b3d8f", "#d97a6c", "#3a8a2e", "#3a8a2e", "#5ac43e", "#5ac43e", "#7a4a24", "#7a4a24"],
          stopovi: [0, 0.55, 0.88, 0.88, 0.9, 0.9, 0.92, 0.92, 1],
        },
      ],
    },
    dugme: {
      zaobljenje: 0,
      ivica: 4,
      slovoZaobljenje: 0,
      senka: [{ x: 4, y: 4, blur: 0, boja: "#000000" }],
      senkaPrimarna: [{ x: 4, y: 4, blur: 0, boja: "#000000" }],
    },
    traka: ["#ffcc00", "#ffcc00"],
    odgovori: "lista",
    ukrasi: [{ tip: "pikselOblaci", boja: "#ffffff80" }],
    uzorak: ["#2a2a5c", "#ffcc00", "#5ac43e"],
  },
];

async function otisak(t: Tema): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(t)));
  return [...new Uint8Array(h).slice(0, 6)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Spisak tema za Podešavanja (bez detalja). */
export async function spisakTema() {
  return {
    podrazumevana: PODRAZUMEVANA,
    teme: await Promise.all(
      TEME.map(async (t) => ({ id: t.id, naziv: t.naziv, opis: t.opis, uzorak: t.uzorak, verzija: await otisak(t) })),
    ),
  };
}

/** Cela tema sa verzijom, ili null. */
export async function tema(id: string) {
  const t = TEME.find((x) => x.id === id);
  return t ? { ...t, verzija: await otisak(t) } : null;
}
