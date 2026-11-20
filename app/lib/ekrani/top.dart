import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';

/// Top lista: dnevni izazov, dan, nedelja, sve vreme; poredak po ukupno ili prosek.
class TopEkran extends StatefulWidget {
  const TopEkran({super.key, this.period = 'nedelja'});
  final String period;
  @override
  State<TopEkran> createState() => _TopEkranState();
}

class _TopEkranState extends State<TopEkran> {
  late String _period = widget.period;
  String _poredak = 'ukupno';
  late Future<List<Map<String, dynamic>>> _lista = _ucitaj();

  Future<List<Map<String, dynamic>>> _ucitaj() async {
    if (_period == 'izazov') {
      final r = await Api.i.izazovTop();
      return (r['lista'] as List).cast<Map<String, dynamic>>();
    }
    return Api.i.top(_period, _poredak);
  }

  void _promeni({String? period, String? poredak}) => setState(() {
    _period = period ?? _period;
    _poredak = poredak ?? _poredak;
    _lista = _ucitaj();
  });

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final ja = Api.i.nalog?.id;
    final izazov = _period == 'izazov';
    return KvizEkran(
      tema: t,
      naslov: 'Top lista',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'izazov', label: Text('Izazov')),
                ButtonSegment(value: 'dan', label: Text('Danas')),
                ButtonSegment(value: 'nedelja', label: Text('Nedelja')),
                ButtonSegment(value: 'sve', label: Text('Sve')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _promeni(period: s.first),
            ),
          ),
          if (!izazov)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'ukupno', label: Text('Ukupno poena')),
                ButtonSegment(value: 'prosek', label: Text('Prosek')),
              ],
              selected: {_poredak},
              onSelectionChanged: (s) => _promeni(poredak: s.first),
            ),
          if (izazov || _poredak == 'prosek')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                izazov
                    ? 'Današnji dnevni izazov. Isto poena: ispred je ko je pre završio.'
                    : 'Prosek se računa posle 3 partije.',
                style: t.tekstStil(velicina: 13, tezina: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder(
              future: _lista,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return Center(
                    child: Text(izazov ? 'Danas još niko nije završio izazov.' : 'Još niko nije igrao u ovom periodu.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final r = lista[i];
                    final desno = izazov
                        ? '${r['poeni']}'
                        : _poredak == 'prosek'
                        ? '${r['prosek']}'
                        : '${r['ukupno']}';
                    final ispod = izazov
                        ? '${r['tacnih']} tačnih'
                        : partija(r['partija'] as int) + (r['prosek'] != null ? ' · prosek ${r['prosek']}' : '');
                    return RedTeme(
                      ja: r['id'] == ja,
                      child: Row(
                        children: [
                          SizedBox(width: 30, child: Text('${i + 1}.', textAlign: TextAlign.right)),
                          const SizedBox(width: 8),
                          Text(r['avatar'], style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['ime'], overflow: TextOverflow.ellipsis),
                                Text(ispod, style: t.tekstStil(velicina: 12, tezina: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Text(desno, style: t.naslov(velicina: 18, tezina: FontWeight.w800)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "1 partija", "2 partije", "5 partija", "21 partija", "22 partije".
String partija(int n) {
  final d = n % 10, s = n % 100;
  if (d >= 2 && d <= 4 && (s < 12 || s > 14)) return '$n partije';
  return '$n partija';
}
