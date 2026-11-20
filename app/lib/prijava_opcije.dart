// Google OAuth client ID-jevi za "Sačuvaj napredak" (nisu tajni, vide se u aplikaciji).
// Prazno = dugme za Google se ne prikazuje. Isti ID-jevi idu i u server/wrangler.toml (GOOGLE_CLIENT_IDS),
// a obrnuti iOS ID u ios/Runner/Info.plist (CFBundleURLSchemes).

/// "Web application" client iz Google Cloud-a: Android ga traži da bi dao ID token za server.
const googleWebClientId = '';

/// "iOS" client iz Google Cloud-a (bundle ID rs.kviz.app).
const googleIosClientId = '';
