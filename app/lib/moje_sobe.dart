// Sobe u koje sam ulazio, da mogu da se vratim posle "Nazad" (soba traje 24 sata).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kljuc = 'moje_sobe';
const _najvise = 8;
const zivotSobe = Duration(hours: 24);

class MojaSoba {
  MojaSoba(this.kod, this.usao);
  final String kod;
  final DateTime usao;
}

/// Čista funkcija za spisak: najnovija prva, bez duplikata, bez starijih od 24 h, najviše 8.
List<MojaSoba> srediSobe(List<MojaSoba> sobe, DateTime sad) {
  final vidjeno = <String>{};
  final lista = [...sobe]..sort((a, b) => b.usao.compareTo(a.usao));
  return lista
      .where((s) => sad.difference(s.usao) < zivotSobe && vidjeno.add(s.kod))
      .take(_najvise)
      .toList();
}

class MojeSobe {
  static Future<List<MojaSoba>> lista() async {
    try {
      final p = await SharedPreferences.getInstance();
      final sirovo = jsonDecode(p.getString(_kljuc) ?? '[]') as List;
      final sobe = [
        for (final s in sirovo.whereType<Map>())
          if (s['kod'] is String && s['usao'] is int)
            MojaSoba(s['kod'] as String, DateTime.fromMillisecondsSinceEpoch(s['usao'] as int)),
      ];
      return srediSobe(sobe, DateTime.now());
    } catch (_) {
      return [];
    }
  }

  static Future<void> _sacuvaj(List<MojaSoba> sobe) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kljuc,
      jsonEncode([
        for (final s in sobe) {'kod': s.kod, 'usao': s.usao.millisecondsSinceEpoch},
      ]),
    );
  }

  static Future<void> zapamti(String kod) async {
    final sad = DateTime.now();
    await _sacuvaj(srediSobe([MojaSoba(kod, sad), ...await lista()], sad));
  }

  static Future<void> zaboravi(String kod) async {
    await _sacuvaj((await lista()).where((s) => s.kod != kod).toList());
  }
}
