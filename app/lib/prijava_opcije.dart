// Google OAuth client ID-jevi za "Sačuvaj napredak" (nisu tajni, vide se u aplikaciji).
// Prazno = dugme za Google se ne prikazuje. Isti ID-jevi idu i u server/wrangler.toml (GOOGLE_CLIENT_IDS),
// a obrnuti iOS ID u ios/Runner/Info.plist (CFBundleURLSchemes).

/// "Web application" client iz Google Cloud-a: Android ga traži da bi dao ID token za server.
const googleWebClientId = '861174080262-rcjlu7emvt2nlq8sea1r9em6a4itjt5o.apps.googleusercontent.com';

/// "iOS" client iz Google Cloud-a (bundle ID rs.kviz.app).
const googleIosClientId = '';
