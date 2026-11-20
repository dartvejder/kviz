// Pregled tema u pregledaču (samo za razvoj, ne ide u aplikaciju):
// flutter build web -t tool/pregled.dart, pa otvori ?tema=neon&ekran=pitanje
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kviz/api.dart';
import 'package:kviz/ekrani/igra.dart';
import 'package:kviz/main.dart';
import 'package:kviz/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final r = await http.get(Uri.base.resolve('teme/${q['tema'] ?? 'studio'}.json'));
  Teme.i.tema.value = KvizTema(jsonDecode(utf8.decode(r.bodyBytes)));
  Api.i.nalog = Nalog(id: 'ja', token: 'x', ime: 'Marko', avatar: '🦊');
  runApp(
    TemaScope(
      builder: (c, t) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: t.themeData(),
        home: switch (q['ekran']) {
          'pitanje' || 'otkriveno' || 'kraj' => _Igra(q['ekran']!),
          _ => const PocetnaEkran(),
        },
      ),
    ),
  );
}

class _Igra extends StatelessWidget {
  const _Igra(this.ekran);
  final String ekran;

  @override
  Widget build(BuildContext context) {
    final otkriveno = ekran == 'otkriveno';
    final s = {
      'faza': ekran,
      'kod': 'K7QX2M',
      'moderatorId': 'ja',
      'opcije': {'vreme': 20, 'pauza': 5, 'brojPitanja': 10, 'oblasti': [], 'dzokeri': true},
      'dupli': ['b'],
      'igraci': [
        {'id': 'a', 'ime': 'Jelena', 'avatar': '🐼', 'poeni': 52, 'tacnih': 8, 'uIgri': true, 'odgovorio': true},
        {
          'id': 'ja',
          'ime': 'Marko',
          'avatar': '🦊',
          'poeni': 38,
          'tacnih': 6,
          'uIgri': true,
          'dzokeri': {'pola': true},
        },
        {'id': 'b', 'ime': 'Stefan', 'avatar': '🦉', 'poeni': 31, 'tacnih': 5, 'uIgri': true, 'odgovorio': true},
        {'id': 'c', 'ime': 'Ana', 'avatar': '🐢', 'poeni': 22, 'tacnih': 4, 'uIgri': true},
      ],
      'pitanje': {
        'n': 3,
        'ukupno': 10,
        'oblast': 'Književnost',
        'tekst': 'Ko je napisao roman „Na Drini ćuprija“?',
        'opcije': ['Ivo Andrić', 'Meša Selimović', 'Branko Ćopić', 'Miloš Crnjanski'],
        'krajU': DateTime.now().millisecondsSinceEpoch + 12400,
        if (otkriveno) ...{
          'tacan': 0,
          'poeni': {'a': 4, 'ja': -1, 'b': 6},
        },
      },
    };
    final soba = Soba('K7QX2M', Api.i.nalog!, povezi: false);
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      naslov: 'Soba K7QX2M',
      body: ekran == 'kraj'
          ? Kraj(s: s, soba: soba, moderator: true, solo: false)
          : PitanjeView(s: s, soba: soba, sakriveno: const {}),
    );
  }
}
