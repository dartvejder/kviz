import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'obavestenja.dart';
import 'push_opcije.dart';

/// Push sa servera (FCM): ujutru stiže jučerašnji rezultat dnevnog izazova.
/// Prati prekidač "Podseti me" iz Podešavanja. Ključ se šalje serveru samo kad se
/// promeni ili jednom nedeljno, da server ne upisuje bez potrebe.
class Push {
  Push._();
  static final Push i = Push._();

  bool _spreman = false;

  /// Push radi na ovom telefonu i ključ je prijavljen serveru.
  bool get aktivan => _spreman && Obavestenja.i.ukljuceno && _prijavljen;
  bool _prijavljen = false;

  Future<void> ucitaj() async {
    final opcije = PushOpcije.trenutne;
    if (opcije == null || kIsWeb) return;
    try {
      await Firebase.initializeApp(options: opcije);
      final p = await SharedPreferences.getInstance();
      _prijavljen = p.getString('push_token') != null;
      _spreman = true;
      // Poruka koja stigne dok je aplikacija otvorena: prikaže se kao i lokalni podsetnik.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) Obavestenja.i.prikazi(n.title ?? 'Dnevni izazov', n.body ?? '');
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _posalji(t, uvek: true));
    } catch (e) {
      debugPrint('Push: $e');
    }
  }

  /// Usklađuje ključ sa serverom: prijavljuje ga ako su podsetnici uključeni, inače odjavljuje.
  Future<void> uskladi() async {
    if (!_spreman || Api.i.nalog == null) return;
    try {
      if (!Obavestenja.i.ukljuceno) {
        await _odjavi();
        return;
      }
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, sound: true, badge: false);
      final t = await m.getToken();
      if (t != null) await _posalji(t);
    } catch (e) {
      debugPrint('Push: $e');
    }
  }

  Future<void> _posalji(String token, {bool uvek = false}) async {
    if (Api.i.nalog == null || !Obavestenja.i.ukljuceno) return;
    final p = await SharedPreferences.getInstance();
    final sad = DateTime.now().millisecondsSinceEpoch;
    final kljuc = '${Api.i.nalog!.id}|$token';
    final staro = p.getInt('push_poslat') ?? 0;
    if (!uvek && p.getString('push_token') == kljuc && sad - staro < const Duration(days: 6).inMilliseconds) return;
    final platforma = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await Api.i.pushKljuc(token, platforma);
    await p.setString('push_token', kljuc);
    await p.setInt('push_poslat', sad);
    _prijavljen = true;
  }

  Future<void> _odjavi() async {
    final p = await SharedPreferences.getInstance();
    final kljuc = p.getString('push_token');
    if (kljuc == null) return;
    await Api.i.pushKljuc(kljuc.substring(kljuc.indexOf('|') + 1), '', odjavi: true);
    await p.remove('push_token');
    _prijavljen = false;
  }
}
