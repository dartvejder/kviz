import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';

/// Pregled posle partije: sva pitanja, tačan odgovor i tvoj odgovor, uz prijavu lošeg pitanja.
class PregledEkran extends StatelessWidget {
  const PregledEkran({super.key, required this.pregled});
  final List<Map<String, dynamic>> pregled;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final ja = Api.i.nalog?.id;
    final mojih = pregled.where((p) => (p['odgovori'] as Map).containsKey(ja)).toList();
    final tacnih = mojih.where((p) => (p['odgovori'] as Map)[ja] == p['tacan']).length;
    return KvizEkran(
      tema: t,
      naslov: 'Pregled pitanja',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: pregled.length + 1,
            itemBuilder: (context, k) {
              if (k == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    mojih.isEmpty ? 'Gledao si ovu partiju.' : 'Tačno: $tacnih od ${mojih.length}',
                    textAlign: TextAlign.center,
                    style: t.naslov(velicina: 18, tezina: FontWeight.w800),
                  ),
                );
              }
              return _PitanjeKartica(n: k, p: pregled[k - 1], ja: ja);
            },
          ),
        ),
      ),
    );
  }
}

class _PitanjeKartica extends StatelessWidget {
  const _PitanjeKartica({required this.n, required this.p, required this.ja});
  final int n;
  final Map<String, dynamic> p;
  final String? ja;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final opcije = (p['opcije'] as List).cast<String>();
    final odgovori = (p['odgovori'] as Map).cast<String, dynamic>();
    final tacan = p['tacan'] as int;
    final moj = odgovori[ja] as int?;
    final igrao = odgovori.containsKey(ja);
    final tacnoIh = odgovori.values.where((v) => v == tacan).length;
    final slabo = t.tekst.withValues(alpha: .7);
    final status = !igrao
        ? null
        : moj == null
        ? ('Nisi odgovorio', slabo)
        : moj == tacan
        ? ('Tačno', t.tacno)
        : ('Netačno', t.netacno);
    return Card(
      color: t.povrsina2,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.zaobljenje + 2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$n. ${p['oblast']}${status != null ? ' · ${status.$1}' : ''}',
                    style: t.tekstStil(velicina: 13, tezina: FontWeight.w700, boja: status?.$2 ?? slabo),
                  ),
                ),
                IconButton(
                  tooltip: 'Prijavi loše pitanje',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.flag_outlined, size: 20, color: slabo),
                  onPressed: () => prijaviPitanje(context, p['id'] as int, p['tekst'] as String),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(p['tekst'], style: t.naslov(velicina: 16, tezina: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            for (var k = 0; k < opcije.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 8),
                child: Row(
                  children: [
                    Icon(
                      k == tacan
                          ? Icons.check_circle
                          : k == moj
                          ? Icons.cancel
                          : Icons.circle_outlined,
                      size: 18,
                      color: k == tacan
                          ? t.tacno
                          : k == moj
                          ? t.netacno
                          : slabo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opcije[k] + (k == moj ? '  (tvoj odgovor)' : ''),
                        style: t.tekstStil(velicina: 14.5, tezina: k == tacan ? FontWeight.w800 : FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            if (odgovori.length > 1)
              Text(
                'Tačno odgovorilo: $tacnoIh od ${odgovori.length}',
                style: t.tekstStil(velicina: 12.5, tezina: FontWeight.w500, boja: slabo),
              ),
          ],
        ),
      ),
    );
  }
}

const _razlozi = {
  'netacan': 'Tačan odgovor nije tačan',
  'nejasno': 'Pitanje je nejasno',
  'zastarelo': 'Podatak je zastareo',
  'drugo': 'Nešto drugo',
};

/// Dijalog za prijavu lošeg pitanja (razlog i kratka napomena).
Future<void> prijaviPitanje(BuildContext context, int id, String tekst) async {
  final poruke = ScaffoldMessenger.of(context);
  final napomena = TextEditingController();
  String razlog = 'netacan';
  final posalji = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, postavi) => AlertDialog(
        title: const Text('Prijavi pitanje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tekst, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: razlog,
                onChanged: (v) => postavi(() => razlog = v ?? razlog),
                child: Column(
                  children: [
                    for (final e in _razlozi.entries)
                      RadioListTile<String>(
                        value: e.key,
                        title: Text(e.value),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: napomena,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Šta nije u redu? (nije obavezno)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Otkaži')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pošalji')),
        ],
      ),
    ),
  );
  if (posalji != true) return;
  try {
    await Api.i.prijaviPitanje(id, razlog, napomena.text.trim());
    poruke.showSnackBar(const SnackBar(content: Text('Hvala! Proverićemo ovo pitanje.')));
  } on Exception catch (e) {
    poruke.showSnackBar(SnackBar(content: Text('Prijava nije poslata: $e')));
  }
}
