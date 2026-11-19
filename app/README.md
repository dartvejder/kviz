# Kviz – Flutter aplikacija

Android, iPhone i web klijent za server iz `../server`.

- `lib/api.dart` – nalog (id + token u shared_preferences), sobe, top lista, WebSocket
- `lib/ekrani/igra.dart` – čekaonica, pitanje, otkrivanje, kraj/revanš, „Vežbaj sam”
- `lib/ekrani/profil.dart` – ime, avatar, „Obriši nalog”
- `lib/ekrani/top.dart` – top lista dan/nedelja/sve, ukupno/prosek

Lokalno protiv lokalnog servera:

```
flutter run -d chrome --dart-define=KVIZ_SERVER=http://localhost:8787
```

Paket: `rs.kviz.app` (isti kao Play aplikacija, da je nova verzija ažurira).
