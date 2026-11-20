import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'push.dart';

/// Podsetnici za dnevni izazov (podrazumevano jedan, u 8:00 po beogradskom vremenu).
/// Korisnik u Podešavanjima menja vremena i dodaje nove. Telefon ih sam zakazuje
/// za narednih 7 dana; dan kad je izazov odigran se preskače. Kad radi push sa servera,
/// jutro posle odigranog izazova stiže push sa rezultatom, pa se jutarnji podsetnici
/// (do 8:30) tog dana preskaču da ne bude duplo.
class Obavestenja {
  Obavestenja._();
  static final Obavestenja i = Obavestenja._();

  static const _dana = 7;
  static const najvise = 5;

  /// Vremena podsetnika, "08:00", poređana.
  List<String> vremena = ['08:00'];
  String? _odigranDan;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _spreman = false;
  bool ukljuceno = true;

  Future<void> ucitaj() async {
    final p = await SharedPreferences.getInstance();
    ukljuceno = p.getBool('jutarnje') ?? true;
    vremena = p.getStringList('podsetnici') ?? ['08:00'];
    _odigranDan = p.getString('izazov_odigran');
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Belgrade'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _spreman = true;
    } catch (e) {
      debugPrint('Obaveštenja: $e');
    }
  }

  /// Uključuje ili isključuje; pri uključivanju traži dozvolu.
  Future<bool> postavi(bool da, {String? odigranDan}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('jutarnje', ukljuceno = da);
    if (da) {
      final dozvola = await _trazi();
      if (!dozvola) return false;
    }
    await zakazi(odigranDan: odigranDan);
    return true;
  }

  Future<bool> _trazi() async {
    if (!_spreman) return false;
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final r = await a?.requestNotificationsPermission() ?? await i?.requestPermissions(alert: true, sound: true);
    return r ?? true;
  }

  /// Menja spisak vremena podsetnika i ponovo ih zakazuje.
  Future<void> postaviVremena(List<String> nova) async {
    vremena = ({...nova}.toList()..sort()).take(najvise).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('podsetnici', vremena);
    await zakazi();
  }

  /// Zakazuje obaveštenja za narednih 7 dana. [odigranDan] ("2026-11-20") se preskače.
  Future<void> zakazi({String? odigranDan, bool traziDozvolu = false}) async {
    if (!_spreman) return;
    if (odigranDan != null) {
      _odigranDan = odigranDan;
      final p = await SharedPreferences.getInstance();
      await p.setString('izazov_odigran', odigranDan);
    }
    try {
      await _plugin.cancelAll();
      if (!ukljuceno) return;
      if (traziDozvolu && !await _trazi()) return;
      final sad = tz.TZDateTime.now(tz.local);
      for (var d = 0; d < _dana; d++) {
        for (final (k, v) in vremena.indexed) {
          final hm = v.split(':');
          final kad = tz.TZDateTime(tz.local, sad.year, sad.month, sad.day + d, int.parse(hm[0]), int.parse(hm[1]));
          if (!kad.isAfter(sad)) continue;
          if (_dan(kad) == _odigranDan) continue;
          if (_jutroPosle(kad) && Push.i.aktivan) continue;
          await _plugin.zonedSchedule(
            id: 900 + d * 10 + k,
            title: 'Dnevni izazov je spreman',
            body: '10 novih pitanja, isto za sve. Koliko ćeš danas?',
            scheduledDate: kad,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'izazov',
                'Dnevni izazov',
                channelDescription: 'Jutarnje obaveštenje za dnevni izazov',
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (e) {
      debugPrint('Obaveštenja: $e');
    }
  }

  /// Jutro (do 8:30) posle dana kad je izazov odigran: tada stiže push sa rezultatom.
  bool _jutroPosle(tz.TZDateTime kad) {
    if (_odigranDan == null || kad.hour * 60 + kad.minute > 8 * 60 + 30) return false;
    final juce = tz.TZDateTime(tz.local, kad.year, kad.month, kad.day - 1);
    return _dan(juce) == _odigranDan;
  }

  /// Odmah prikazuje obaveštenje (push koji stigne dok je aplikacija otvorena).
  Future<void> prikazi(String naslov, String tekst) async {
    if (!_spreman) return;
    try {
      await _plugin.show(
        id: 899,
        title: naslov,
        body: tekst,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('izazov', 'Dnevni izazov', channelDescription: 'Jutarnje obaveštenje za dnevni izazov'),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Obaveštenja: $e');
    }
  }

  static String _dan(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
