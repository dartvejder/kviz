// Najmanji build aplikacije po platformi. Postavlja se u Cloudflare-u (MIN_ANDROID, MIN_IOS) bez novog postavljanja.
export const PRODAVNICA = {
  android: "https://play.google.com/store/apps/details?id=rs.kviz.app",
  ios: "https://testflight.apple.com/join/wsu5cUPK",
};

const broj = (x: string | undefined) => {
  const n = Number.parseInt(x ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
};

export function minVerzija(env: { MIN_ANDROID?: string; MIN_IOS?: string }) {
  return {
    android: { min: broj(env.MIN_ANDROID), prodavnica: PRODAVNICA.android },
    ios: { min: broj(env.MIN_IOS), prodavnica: PRODAVNICA.ios },
  };
}
