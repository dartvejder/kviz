import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'top.dart' show partija;

/// Moja statistika: partije, poeni i uspeh po oblastima.
class StatistikaEkran extends StatefulWidget {
  const StatistikaEkran({super.key});
  @override
  State<StatistikaEkran> createState() => _StatistikaEkranState();
}

class _StatistikaEkranState extends State<StatistikaEkran> {
  final _podaci = Api.i.statistika();

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      naslov: 'Moja statistika',
      body: FutureBuilder(
        future: _podaci,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final oblasti = (d['oblasti'] as List).cast<Map<String, dynamic>>();
          final tacnih = oblasti.fold<int>(0, (a, o) => a + (o['tacnih'] as int));
          final ukupno = oblasti.fold<int>(0, (a, o) => a + (o['ukupno'] as int));
          double proc(Map o) => (o['ukupno'] as int) == 0 ? 0 : (o['tacnih'] as int) / (o['ukupno'] as int);
          // Najbolja i najslabija oblast se računaju tek posle 5 pitanja iz nje.
          final ozbiljne = oblasti.where((o) => (o['ukupno'] as int) >= 5).toList()
            ..sort((a, b) => proc(b).compareTo(proc(a)));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _Broj(
                    naslov: partija(d['partija'] as int).replaceFirst(RegExp(r'^\d+ '), ''),
                    vrednost: '${d['partija']}',
                  ),
                  _Broj(naslov: 'tačnih', vrednost: ukupno == 0 ? '–' : '${(tacnih * 100 / ukupno).round()}%'),
                  _Broj(naslov: 'najviše poena', vrednost: '${d['najvise']}'),
                ],
              ),
              const SizedBox(height: 12),
              if (ozbiljne.length >= 2) ...[
                RedTeme(
                  child: Text(
                    'Najbolja oblast: ${ozbiljne.first['oblast']} (${(proc(ozbiljne.first) * 100).round()}%)',
                  ),
                ),
                RedTeme(
                  child: Text(
                    'Najslabija oblast: ${ozbiljne.last['oblast']} (${(proc(ozbiljne.last) * 100).round()}%)',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (oblasti.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Odigraj partiju i ovde će se pojaviti tvoj uspeh po oblastima.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final o in oblasti)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(o['oblast'], style: t.tekstStil(velicina: 14))),
                          Text(
                            '${o['tacnih']}/${o['ukupno']} · ${(proc(o) * 100).round()}%',
                            style: t.tekstStil(velicina: 13, tezina: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TrakaTeme(deo: proc(o)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Broj extends StatelessWidget {
  const _Broj({required this.naslov, required this.vrednost});
  final String naslov, vrednost;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: t.povrsina2, borderRadius: BorderRadius.circular(t.zaobljenje)),
        child: Column(
          children: [
            Text(vrednost, style: t.naslov(velicina: 24, boja: t.istaknut)),
            Text(
              naslov,
              style: t.tekstStil(velicina: 12, tezina: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
