# Kviz opšte kulture

Kviz na srpskom za 2–8 igrača. Domaćin upiše ime, izabere vreme po pitanju i broj pitanja i pošalje pozivnicu (link ili kod). Ostali upišu ime i uđu. Domaćin pokreće kviz.

Bodovanje: tačan odgovor +3, netačan −1, bez odgovora 0.

Igrači se povezuju direktno između pregledača (WebRTC, preko [PeerJS](https://peerjs.com)); nalog nije potreban. Domaćin mora da drži stranicu otvorenu do kraja igre.

Pitanja (oko 2000, 8 oblasti uključujući film i muziku) su u `questions.js`, koji se pravi skriptom `src/build.py` iz fajlova `src/*.txt` (format: `pitanje|tačan|netačan|netačan|netačan`). Domaćinov pregledač pamti već odigrana pitanja, pa se ona ne ponavljaju dok se ne iskoriste sva.

`peerjs.min.js` je PeerJS 1.5.4 (MIT licenca).
