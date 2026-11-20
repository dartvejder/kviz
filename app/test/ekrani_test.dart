import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kviz/api.dart';
import 'package:kviz/ekrani/igra.dart';
import 'package:kviz/ekrani/pregled.dart';

Map<String, dynamic> igrac(String id, int tim, int poeni, {List<String>? znacke}) => {
  'id': id,
  'ime': 'Igrač $id',
  'avatar': '🦊',
  'spreman': true,
  'uIgri': true,
  'poeni': poeni,
  'tacnih': 2,
  'tim': tim,
  'povezan': true,
  'zaredom': 0,
  'noveZnacke': ?znacke,
};

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => Api.i.nalog = Nalog(id: 'a', token: 't', ime: 'A', avatar: '🦊'));

  testWidgets('kraj timske partije: pobednički tim i nova značka', (tester) async {
    final s = {
      'faza': 'kraj',
      'moderatorId': 'a',
      'opcije': {'vreme': 20, 'brojPitanja': 10, 'oblasti': [], 'timovi': true},
      'igraci': [igrac('a', 0, 12, znacke: ['tim']), igrac('b', 1, 4)],
      'timovi': [
        {'tim': 0, 'naziv': 'Plavi', 'igraca': 1, 'ukupno': 12, 'prosek': 12},
        {'tim': 1, 'naziv': 'Crveni', 'igraca': 1, 'ukupno': 4, 'prosek': 4.5},
      ],
      'pregled': [
        {
          'id': 1,
          'oblast': 'Istorija',
          'tekst': 'Pitanje?',
          'opcije': ['A', 'B', 'C', 'D'],
          'tacan': 1,
          'odgovori': {'a': 1, 'b': null},
        },
      ],
    };
    final soba = Soba('ABCDEF', Api.i.nalog!, povezi: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Kraj(s: s, soba: soba, moderator: true, solo: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Pobedili su Plavi!'), findsOneWidget);
    expect(find.text('Nova značka!'), findsOneWidget);
    expect(find.text('4,5'), findsWidgets);
    expect(find.text('Igraj ponovo'), findsOneWidget);
    await tester.tap(find.text('Pregled pitanja'));
    await tester.pumpAndSettle();
    expect(find.byType(PregledEkran), findsOneWidget);
    expect(find.text('Tačno: 1 od 1'), findsOneWidget);
  });

  testWidgets('čekaonica u timskom modu', (tester) async {
    final s = {
      'kod': 'ABCDEF',
      'faza': 'cekaonica',
      'moderatorId': 'a',
      'prozivkaDo': 0,
      'opcije': {'vreme': 20, 'pauza': 5, 'brojPitanja': 10, 'oblasti': [], 'timovi': true, 'tezina': 'tesko'},
      'igraci': [igrac('a', 0, 0), igrac('b', 1, 0)],
    };
    final soba = Soba('ABCDEF', Api.i.nalog!, povezi: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Cekaonica(s: s, soba: soba, moderator: true)),
      ),
    );
    expect(find.text('Plavi'), findsOneWidget);
    expect(find.text('Pređi u Crvene'), findsOneWidget);
    expect(find.text('Izmešaj timove', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('teža pitanja', skipOffstage: false), findsOneWidget);
  });
}
