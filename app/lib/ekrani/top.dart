import 'package:flutter/material.dart';

import '../api.dart';

/// Top lista: dan, nedelja, sve vreme; poredak po ukupno ili prosek.
class TopEkran extends StatefulWidget {
  const TopEkran({super.key});
  @override
  State<TopEkran> createState() => _TopEkranState();
}

class _TopEkranState extends State<TopEkran> {
  String _period = 'nedelja';
  String _poredak = 'ukupno';
  late Future<List<Map<String, dynamic>>> _lista = _ucitaj();

  Future<List<Map<String, dynamic>>> _ucitaj() => Api.i.top(_period, _poredak);

  void _promeni({String? period, String? poredak}) => setState(() {
        _period = period ?? _period;
        _poredak = poredak ?? _poredak;
        _lista = _ucitaj();
      });

  @override
  Widget build(BuildContext context) {
    final ja = Api.i.nalog?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Top lista')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'dan', label: Text('Danas')),
              ButtonSegment(value: 'nedelja', label: Text('Nedelja')),
              ButtonSegment(value: 'sve', label: Text('Sve vreme')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _promeni(period: s.first),
          ),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ukupno', label: Text('Ukupno poena')),
            ButtonSegment(value: 'prosek', label: Text('Prosek')),
          ],
          selected: {_poredak},
          onSelectionChanged: (s) => _promeni(poredak: s.first),
        ),
        if (_poredak == 'prosek')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Prosek se računa posle 3 partije.', style: TextStyle(fontSize: 13)),
          ),
        Expanded(
          child: FutureBuilder(
            future: _lista,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final lista = snap.data!;
              if (lista.isEmpty) return const Center(child: Text('Još niko nije igrao u ovom periodu.'));
              return ListView.builder(
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final r = lista[i];
                  return ListTile(
                    selected: r['id'] == ja,
                    leading: SizedBox(
                      width: 72,
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('${i + 1}.', textAlign: TextAlign.right)),
                        const SizedBox(width: 8),
                        Text(r['avatar'], style: const TextStyle(fontSize: 26)),
                      ]),
                    ),
                    title: Text(r['ime']),
                    subtitle: Text(partija(r['partija'] as int) +
                        (r['prosek'] != null ? ' · prosek ${r['prosek']}' : '')),
                    trailing: Text(
                      _poredak == 'prosek' ? '${r['prosek']}' : '${r['ukupno']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// "1 partija", "2 partije", "5 partija", "21 partija", "22 partije".
String partija(int n) {
  final d = n % 10, s = n % 100;
  if (d >= 2 && d <= 4 && (s < 12 || s > 14)) return '$n partije';
  return '$n partija';
}
