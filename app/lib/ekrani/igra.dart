import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../tema.dart';

/// Soba: čekaonica, pitanja, otkrivanje i kraj, sve iz stanja sa servera.
class IgraEkran extends StatefulWidget {
  const IgraEkran({super.key, required this.kod, this.solo = false});
  final String kod;
  final bool solo;
  @override
  State<IgraEkran> createState() => _IgraEkranState();
}

class _IgraEkranState extends State<IgraEkran> {
  late final Soba _soba = Api.i.udji(widget.kod);
  StreamSubscription? _sub;
  Map<String, dynamic>? _s;
  String? _greska;
  bool _soloPokrenut = false;

  @override
  void initState() {
    super.initState();
    _sub = _soba.stanja.listen((m) {
      if (!mounted) return;
      if (m['t'] == 'greska') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m['poruka'])));
      } else if (m['t'] == 'zatvoreno') {
        setState(() => _greska = m['kod'] == 4001 ? 'Soba je istekla.' : 'Ušao si u ovu sobu sa drugog uređaja.');
      } else {
        setState(() => _s = m);
        // "Vežbaj sam": soba se odmah pokreće.
        if (widget.solo && !_soloPokrenut && m['faza'] == 'cekaonica') {
          _soloPokrenut = true;
          _soba.posalji({'t': 'pokreni'});
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _soba.zatvori();
    super.dispose();
  }

  bool get _moderator => _s?['moderatorId'] == Api.i.nalog!.id;

  @override
  Widget build(BuildContext context) {
    final s = _s;
    Widget telo;
    if (_greska != null) {
      telo = Center(child: Text(_greska!));
    } else if (s == null) {
      telo = const Center(child: CircularProgressIndicator());
    } else {
      telo = switch (s['faza']) {
        'cekaonica' => Cekaonica(s: s, soba: _soba, moderator: _moderator),
        'pitanje' || 'otkriveno' => PitanjeView(s: s, soba: _soba),
        _ => Kraj(s: s, soba: _soba, moderator: _moderator, solo: widget.solo),
      };
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.solo ? 'Vežbaj sam' : 'Soba ${widget.kod}'),
        actions: [
          if (!widget.solo)
            IconButton(
              tooltip: 'Kopiraj pozivnicu',
              icon: const Icon(Icons.share),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Igraj kviz sa mnom: https://kviz.dartchat.trade/i/${widget.kod}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pozivnica je kopirana.')));
              },
            ),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: telo))),
    );
  }
}

List<Map<String, dynamic>> _igraci(Map<String, dynamic> s) => (s['igraci'] as List).cast<Map<String, dynamic>>();

class Cekaonica extends StatelessWidget {
  const Cekaonica({super.key, required this.s, required this.soba, required this.moderator});
  final Map<String, dynamic> s;
  final Soba soba;
  final bool moderator;

  @override
  Widget build(BuildContext context) {
    final igraci = _igraci(s);
    final ja = igraci.firstWhere((i) => i['id'] == Api.i.nalog!.id, orElse: () => {});
    final opcije = s['opcije'] as Map<String, dynamic>;
    final spremni = igraci.where((i) => i['spreman'] == true || i['id'] == s['moderatorId']).length;
    final prozivka = (s['prozivkaDo'] as int) > 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Kod sobe'),
            SelectableText(s['kod'], style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 6)),
            const Text('Pošalji pozivnicu (dugme gore desno). Soba čeka do 24 sata.', textAlign: TextAlign.center),
          ]),
        ),
      ),
      if (prozivka)
        const Card(
          color: zuta,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('Moderator proziva: svi da potvrde da su spremni!',
                style: TextStyle(color: plava, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ),
        ),
      const SizedBox(height: 8),
      Text('Igrači ($spremni/${igraci.length} spremno)', style: Theme.of(context).textTheme.titleMedium),
      for (final i in igraci)
        ListTile(
          leading: Text(i['avatar'], style: const TextStyle(fontSize: 28)),
          title: Text(i['ime'] + (i['id'] == s['moderatorId'] ? '  (moderator)' : '')),
          subtitle: Text(i['povezan'] == true ? 'u sobi' : 'nije tu'),
          trailing: Icon(
            i['spreman'] == true || i['id'] == s['moderatorId'] ? Icons.check_circle : Icons.hourglass_empty,
            color: i['spreman'] == true || i['id'] == s['moderatorId'] ? zelena : null,
          ),
        ),
      const Divider(),
      Text(
        'Opcije: ${opcije['vreme']} s po pitanju, ${opcije['brojPitanja']} pitanja, '
        '${(opcije['oblasti'] as List).isEmpty ? 'sve oblasti' : (opcije['oblasti'] as List).join(', ')}',
      ),
      const SizedBox(height: 16),
      if (moderator) ...[
        OutlinedButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => OpcijeSheet(opcije: opcije, soba: soba),
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Promeni opcije'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => soba.posalji({'t': 'prozovi'}),
          icon: const Icon(Icons.campaign),
          label: const Text('Prozovi sve'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => soba.posalji({'t': 'pokreni'}),
          child: Text(spremni < igraci.length ? 'Počni bez njih ($spremni)' : 'Pokreni'),
        ),
      ] else
        FilledButton(
          onPressed: () => soba.posalji({'t': 'spreman', 'da': ja['spreman'] != true}),
          child: Text(ja['spreman'] == true ? 'Nisam spreman' : 'Spreman sam'),
        ),
    ]);
  }
}

class OpcijeSheet extends StatefulWidget {
  const OpcijeSheet({super.key, required this.opcije, required this.soba});
  final Map<String, dynamic> opcije;
  final Soba soba;
  @override
  State<OpcijeSheet> createState() => _OpcijeSheetState();
}

class _OpcijeSheetState extends State<OpcijeSheet> {
  late double _vreme = (widget.opcije['vreme'] as int).toDouble();
  late double _broj = (widget.opcije['brojPitanja'] as int).toDouble();
  late final Set<String> _oblasti = {...(widget.opcije['oblasti'] as List).cast<String>()};
  late final Future<List<Map<String, dynamic>>> _sve = Api.i.oblasti();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: ListView(shrinkWrap: true, children: [
        Text('Vreme po pitanju: ${_vreme.round()} s'),
        Slider(value: _vreme, min: 10, max: 60, divisions: 10, onChanged: (v) => setState(() => _vreme = v)),
        Text('Broj pitanja: ${_broj.round()}'),
        Slider(value: _broj, min: 5, max: 50, divisions: 9, onChanged: (v) => setState(() => _broj = v)),
        const Text('Oblasti (ništa izabrano = sve)'),
        FutureBuilder(
          future: _sve,
          builder: (context, snap) => Wrap(spacing: 6, runSpacing: 6, children: [
            for (final o in snap.data ?? const <Map<String, dynamic>>[])
              FilterChip(
                label: Text(o['oblast']),
                selected: _oblasti.contains(o['oblast']),
                onSelected: (da) => setState(() => da ? _oblasti.add(o['oblast']) : _oblasti.remove(o['oblast'])),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            widget.soba.posalji({
              't': 'opcije',
              'vreme': _vreme.round(),
              'brojPitanja': _broj.round(),
              'oblasti': _oblasti.toList(),
            });
            Navigator.pop(context);
          },
          child: const Text('Sačuvaj'),
        ),
      ]),
    );
  }
}

class PitanjeView extends StatefulWidget {
  const PitanjeView({super.key, required this.s, required this.soba});
  final Map<String, dynamic> s;
  final Soba soba;
  @override
  State<PitanjeView> createState() => _PitanjeViewState();
}

class _PitanjeViewState extends State<PitanjeView> {
  Timer? _tik;
  int? _mojIzbor;
  int _n = -1;

  @override
  void initState() {
    super.initState();
    _tik = Timer.periodic(const Duration(milliseconds: 200), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tik?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.s['pitanje'] as Map<String, dynamic>;
    if (p['n'] != _n) {
      _n = p['n'];
      _mojIzbor = null;
    }
    final otkriveno = widget.s['faza'] == 'otkriveno';
    final ja = Api.i.nalog!.id;
    final opcije = (p['opcije'] as List).cast<String>();
    final sad = DateTime.now().millisecondsSinceEpoch + widget.soba.pomakSata;
    final ostalo = ((p['krajU'] as int) - sad).clamp(0, 600000);
    final ukupno = ((widget.s['opcije'] as Map)['vreme'] as int) * 1000;
    final uIgri = _igraci(widget.s).any((i) => i['id'] == ja && i['uIgri'] == true);
    final poeni = (p['poeni'] as Map?)?.cast<String, int>() ?? {};

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('${p['n'] + 1}/${p['ukupno']} · ${p['oblast']}'),
        const Spacer(),
        if (!otkriveno) Text('${(ostalo / 1000).ceil()} s', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: otkriveno ? 0 : ostalo / ukupno, minHeight: 6),
      const SizedBox(height: 24),
      Text(p['tekst'], style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      for (var k = 0; k < opcije.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: otkriveno
                  ? (k == p['tacan']
                      ? zelena
                      : k == _mojIzbor
                          ? crvena
                          : plavaSvetla)
                  : (k == _mojIzbor ? zuta : plavaSvetla),
              foregroundColor: (!otkriveno && k == _mojIzbor) ? plava : Colors.white,
              disabledBackgroundColor: null,
            ),
            onPressed: (!otkriveno && uIgri && _mojIzbor == null)
                ? () {
                    setState(() => _mojIzbor = k);
                    widget.soba.posalji({'t': 'odgovor', 'pitanje': p['n'], 'izbor': k});
                  }
                : () {},
            child: Text(opcije[k], textAlign: TextAlign.center),
          ),
        ),
      if (!uIgri) const Text('Gledaš ovu partiju. Igraš od revanša.', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Tabela(s: widget.s, poeni: otkriveno ? poeni : null),
    ]);
  }
}

class Tabela extends StatelessWidget {
  const Tabela({super.key, required this.s, this.poeni});
  final Map<String, dynamic> s;
  final Map<String, int>? poeni;

  @override
  Widget build(BuildContext context) {
    final igraci = _igraci(s).where((i) => i['uIgri'] == true).toList()
      ..sort((a, b) => (b['poeni'] as int).compareTo(a['poeni'] as int));
    return Column(children: [
      for (final i in igraci)
        ListTile(
          dense: true,
          leading: Text(i['avatar'], style: const TextStyle(fontSize: 22)),
          title: Text(i['ime']),
          subtitle: poeni == null ? (i['odgovorio'] == true ? const Text('odgovorio') : null) : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (poeni != null && poeni!.containsKey(i['id']))
              Text(
                '${poeni![i['id']]! > 0 ? '+' : ''}${poeni![i['id']]}  ',
                style: TextStyle(color: poeni![i['id']]! > 0 ? zelena : crvena, fontWeight: FontWeight.w700),
              ),
            Text('${i['poeni']}', style: Theme.of(context).textTheme.titleMedium),
          ]),
        ),
    ]);
  }
}

class Kraj extends StatelessWidget {
  const Kraj({super.key, required this.s, required this.soba, required this.moderator, required this.solo});
  final Map<String, dynamic> s;
  final Soba soba;
  final bool moderator;
  final bool solo;

  @override
  Widget build(BuildContext context) {
    final igraci = _igraci(s).where((i) => i['uIgri'] == true).toList()
      ..sort((a, b) => (b['poeni'] as int).compareTo(a['poeni'] as int));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Kraj!', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
      if (igraci.isNotEmpty && !solo)
        Text('Pobednik: ${igraci.first['avatar']} ${igraci.first['ime']}',
            style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      for (final (r, i) in igraci.indexed)
        ListTile(
          leading: Text('${r + 1}. ${i['avatar']}', style: const TextStyle(fontSize: 22)),
          title: Text(i['ime']),
          subtitle: Text('${i['tacnih']} tačnih'),
          trailing: Text('${i['poeni']}', style: Theme.of(context).textTheme.headlineSmall),
        ),
      const SizedBox(height: 24),
      if (moderator)
        FilledButton(
          onPressed: () => soba.posalji(solo ? {'t': 'pokreni'} : {'t': 'revans'}),
          child: Text(solo ? 'Još jednom' : 'Revanš'),
        )
      else
        const Text('Čeka se da moderator pokrene revanš.', textAlign: TextAlign.center),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Izađi')),
    ]);
  }
}
