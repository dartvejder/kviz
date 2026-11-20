import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart' show server;
import 'model.dart';

/// Kratak opis teme iz spiska za Podešavanja.
class OpisTeme {
  OpisTeme(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get naziv => json['naziv'] as String? ?? id;
  String get opis => json['opis'] as String? ?? '';
  String get verzija => json['verzija'] as String? ?? '';
  List<Color> get uzorak => boje(json['uzorak']);
}

/// Izabrana tema: čuva se na telefonu, a sa servera se osvežava kad joj se
/// promeni verzija.
class Teme {
  Teme._();
  static final Teme i = Teme._();

  static const _kTema = 'tema_json';
  static const _kSpisak = 'teme_spisak';

  final ValueNotifier<KvizTema> tema = ValueNotifier(KvizTema(const {'id': 'studio'}));
  List<OpisTeme> spisak = [];
  KvizTema? _ugradjena;

  /// Učitava sačuvanu temu (ili ugrađenu Studio), pa u pozadini proverava server.
  Future<void> ucitaj() async {
    _ugradjena = KvizTema(jsonDecode(await rootBundle.loadString('assets/tema-studio.json')));
    KvizTema t = _ugradjena!;
    try {
      final p = await SharedPreferences.getInstance();
      final sacuvana = p.getString(_kTema);
      if (sacuvana != null) t = KvizTema(jsonDecode(sacuvana));
      final s = p.getString(_kSpisak);
      if (s != null) spisak = _spisakIz(jsonDecode(s));
    } catch (_) {
      // Oštećen zapis: ostaje ugrađena tema.
    }
    tema.value = t;
    unawaited(osvezi());
  }

  List<OpisTeme> _spisakIz(Object? j) =>
      j is Map && j['teme'] is List ? [for (final t in (j['teme'] as List).cast<Map>()) OpisTeme(t.cast())] : [];

  /// Preuzima spisak tema; ako je izabrana tema izmenjena na serveru, preuzima je ponovo.
  Future<List<OpisTeme>> osvezi() async {
    try {
      final r = await http.get(Uri.parse('$server/api/teme')).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return spisak;
      final novi = _spisakIz(jsonDecode(r.body));
      if (novi.isEmpty) return spisak;
      spisak = novi;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kSpisak, r.body);
      final moja = novi.where((x) => x.id == tema.value.id).firstOrNull;
      if (moja != null && moja.verzija != tema.value.verzija) await izaberi(moja.id);
    } catch (_) {
      // Bez interneta: radi sa onim što je sačuvano.
    }
    return spisak;
  }

  /// Preuzima temu sa servera, čuva je i primenjuje. Baca grešku ako ne uspe.
  Future<void> izaberi(String id) async {
    final r = await http.get(Uri.parse('$server/api/teme/$id')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Tema nije preuzeta (${r.statusCode}).');
    final t = KvizTema(jsonDecode(r.body));
    await _fontovi(t);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTema, r.body);
    tema.value = t;
  }

  /// Fontovi se preuzmu pre primene, da tema ne zatreperi; posle su sačuvani na telefonu.
  Future<void> _fontovi(KvizTema t) async {
    try {
      for (final w in [FontWeight.w400, FontWeight.w600, FontWeight.w700, FontWeight.w800, t.naslovTezina]) {
        t.naslov(tezina: w);
        t.tekstStil(tezina: w);
      }
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Font će stići kasnije ili ostaje sistemski.
    }
  }
}
