# Kviz opšte kulture

Kviz na srpskom za 2–8 igrača. Domaćin upiše ime, izabere vreme po pitanju i broj pitanja i pošalje pozivnicu (link ili kod). Ostali upišu ime i uđu. Domaćin pokreće kviz.

Bodovanje: tačan odgovor +3, netačan −1, bez odgovora 0.

Igrači se povezuju direktno između pregledača (WebRTC, preko [PeerJS](https://peerjs.com)); nalog nije potreban. Domaćin mora da drži stranicu otvorenu do kraja igre.

Pitanja (oko 7000, 18 oblasti; domaćin u čekaonici bira koje oblasti ulaze u igru) su u `questions.js`, koji se pravi skriptom `src/build.py` iz fajlova `src/*.txt` (format: `pitanje|tačan|netačan|netačan|netačan`). Domaćinov pregledač pamti već odigrana pitanja, pa se ona ne ponavljaju dok se ne iskoriste sva.

`peerjs.min.js` je PeerJS 1.5.4 (MIT licenca).

## Android aplikacija

Folder `android/` je mala Android aplikacija koja otvara sajt https://dartvejder.github.io/kviz/. GitHub Actions (`.github/workflows/apk.yml`) pravi potpisan `kviz.apk` i objavljuje ga kao Release. Najnovija verzija: https://github.com/dartvejder/kviz/releases/latest/download/kviz.apk

Za potpisivanje su potrebne dve tajne u Settings → Secrets and variables → Actions: `ANDROID_KEYSTORE` (keystore u base64) i `ANDROID_KEYSTORE_PASSWORD`. Ključ se ne čuva u repou; uvek koristiti isti ključ, inače telefon neće prihvatiti ažuriranje.

Nova verzija: u `version.json` povećati `versionCode`, promeniti `versionName` i `notes`, pa pushovati. Aplikacija čita `version.json` sa sajta i, kad je `versionCode` veći od instaliranog, prikazuje obaveštenje sa dugmetom za preuzimanje. Verzija se vidi u dnu ekrana.
