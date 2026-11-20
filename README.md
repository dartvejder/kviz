# Kviz opšte kulture

Kviz na srpskom za više igrača. Igra se u Flutter aplikaciji (`app/`, Android i iPhone) preko servera na Cloudflare-u (`server/`).

Stara igra u pregledaču (PeerJS) je ugašena 20. 11. 2026: `index.html` na https://dartvejder.github.io/kviz/ sada samo kaže da je kviz aplikacija. Sajt ostaje zbog politike privatnosti (`privacy.html`).

Pitanja su u `questions.js`, koji se pravi skriptom `src/build.py` iz fajlova `src/*.txt` (format: `pitanje|tačan|netačan|netačan|netačan`); server ih uvozi u D1 bazu.

## Android aplikacija

Folder `android/` je mala Android aplikacija koja otvara sajt https://dartvejder.github.io/kviz/. GitHub Actions (`.github/workflows/apk.yml`) pravi potpisan `kviz.apk` i objavljuje ga kao Release. Najnovija verzija: https://github.com/dartvejder/kviz/releases/latest/download/kviz.apk

Za potpisivanje su potrebne dve tajne u Settings → Secrets and variables → Actions: `ANDROID_KEYSTORE` (keystore u base64) i `ANDROID_KEYSTORE_PASSWORD`. Ključ se ne čuva u repou; uvek koristiti isti ključ, inače telefon neće prihvatiti ažuriranje.

Nova verzija: u `version.json` povećati `versionCode`, promeniti `versionName` i `notes`, pa pushovati. Aplikacija čita `version.json` sa sajta i, kad je `versionCode` veći od instaliranog, prikazuje obaveštenje sa dugmetom za preuzimanje. Verzija se vidi u dnu ekrana.

## Google Play

Workflow `.github/workflows/play.yml` pravi potpisan paket `kviz-play.aab` nove Flutter aplikacije (`app/`) za Google Play, istim ključem kao APK (tajne `ANDROID_KEYSTORE` i `ANDROID_KEYSTORE_PASSWORD`, alias `kviz`). Pokreće se pri svakom pushu na `main` koji menja `app/`, ili ručno iz kartice Actions („Google Play” → „Run workflow”). Radi na Windows PC runneru (`self-hosted, Windows, dartchat-pc`). Paket se preuzima iz rezultata pokretanja (Artifacts → `kviz-play-bundle`, čuva se 1 dan) i postavlja u Play Console. Na pull requestu samo proverava da se paket prevodi.

Broj verzije je 2000 + broj pokretanja workflowa, pa je uvek veći od starih WebView verzija (1000+) iz `android/`.

Politika privatnosti: https://dartvejder.github.io/kviz/privacy.html

## iPhone (TestFlight)

Isto kao u Dart Chatu. `.github/workflows/ios-release.yml` pravi potpisanu iPhone aplikaciju na GitHub Mac mašini i šalje je na TestFlight (grupa „Prijatelji”). Pokreće se samo ručno iz kartice Actions, jer svaki build košta plaćene Mac minute (oko 15–20 minuta).

Tajne (Settings → Secrets and variables → Actions):
- `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY` (ceo .p8 fajl), ključ iz App Store Connect → Users and Access → Integrations, pristup App Manager.
- `IOS_CERTIFICATE_P12_BASE64` i `IOS_CERTIFICATE_PASSWORD`: pravi ih workflow „Create iPhone certificate” (jednom, na Linuxu, besplatno); uputstvo je u preuzetom fajlu.

Pomoćni skript `.github/scripts/appstore.py` sam registruje Bundle ID `rs.kviz.app`, pravi profil i daje build TestFlight grupi.
