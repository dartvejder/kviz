import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../pozivnica.dart';
import '../tema.dart';
import '../obavestenja.dart';
import '../zvuk.dart';

/// Soba: čekaonica, pitanja, otkrivanje i kraj, sve iz stanja sa servera.
class IgraEkran extends StatefulWidget {
  const IgraEkran({super.key, required this.kod, this.solo = false, this.izazov = false});
  final String kod;
  final bool solo;

  /// Dnevni izazov: igra se sam, jednom.
  final bool izazov;
  @override
  State<IgraEkran> createState() => _IgraEkranState();
}

class _IgraEkranState extends State<IgraEkran> {
  late final Soba _soba = Api.i.udji(widget.kod);
  StreamSubscription? _sub;
  Map<String, dynamic>? _s;
  String? _greska;
  bool _soloPokrenut = false;
  final _reakcije = <_Reakcija>[];
  int _rid = 0;

  /// 50:50: koje odgovore ne prikazujem, po broju pitanja.
  final Map<int, List<int>> _sakriveno = {};
  String? _faza;
  int? _pitanje;

  @override
  void initState() {
    super.initState();
    _sub = _soba.stanja.listen((m) {
      if (!mounted) return;
      if (m['t'] == 'greska') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m['poruka'])));
      } else if (m['t'] == 'reakcija') {
        final id = ++_rid;
        final igrac = _igraci(_s ?? const {'igraci': []}).where((i) => i['id'] == m['id']).firstOrNull;
        setState(() => _reakcije.add(_Reakcija(id, m['e'], igrac?['ime'] ?? '')));
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _reakcije.removeWhere((r) => r.id == id));
        });
      } else if (m['t'] == 'pola') {
        setState(() => _sakriveno[m['pitanje'] as int] = (m['sakrij'] as List).cast<int>());
      } else if (m['t'] == 'zatvoreno') {
        setState(() => _greska = m['kod'] == 4001 ? 'Soba je istekla.' : 'Ušao si u ovu sobu sa drugog uređaja.');
      } else {
        _zvukZa(m);
        setState(() => _s = m);
        // "Vežbaj sam" i izazov: soba se odmah pokreće.
        if ((widget.solo || widget.izazov) && !_soloPokrenut && m['faza'] == 'cekaonica') {
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

  /// Zvuk i vibracija kad se odgovor otkrije i na kraju partije.
  void _zvukZa(Map<String, dynamic> m) {
    final faza = m['faza'] as String?;
    final p = m['pitanje'] as Map<String, dynamic>?;
    final n = p?['n'] as int?;
    if (faza == 'otkriveno' && (_faza != 'otkriveno' || _pitanje != n)) {
      final moj = (p?['odgovori'] as Map?)?[Api.i.nalog!.id];
      if (moj != null) moj == p!['tacan'] ? Zvuk.i.tacno() : Zvuk.i.netacno();
    }
    if (faza == 'kraj' && _faza != null && _faza != 'kraj') Zvuk.i.kraj();
    _faza = faza;
    _pitanje = n;
  }

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
        'pitanje' ||
        'otkriveno' => PitanjeView(s: s, soba: _soba, sakriveno: _sakriveno, solo: widget.solo || widget.izazov),
        _ => Kraj(s: s, soba: _soba, moderator: _moderator, solo: widget.solo, izazov: widget.izazov),
      };
      if (!widget.solo && !widget.izazov) {
        telo = Stack(
          children: [
            Positioned.fill(child: telo),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(
                child: Column(
                  children: [for (final r in _reakcije) _LetecaReakcija(key: ValueKey(r.id), r: r)],
                ),
              ),
            ),
          ],
        );
      }
    }
    return KvizEkran(
      tema: temaOd(context),
      naslov: widget.izazov
          ? 'Dnevni izazov'
          : widget.solo
          ? 'Vežbaj sam'
          : 'Soba ${widget.kod}',
      akcije: [
        if (!widget.solo && !widget.izazov)
          Builder(
            builder: (c) => IconButton(
              tooltip: 'Pozovi prijatelje',
              icon: const Icon(Icons.share),
              onPressed: () => podeliPozivnicu(c, widget.kod),
            ),
          ),
      ],
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: telo),
      ),
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
    final t = temaOd(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: t.povrsina2,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.zaobljenje + 4)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Kod sobe'),
                SelectableText(
                  s['kod'],
                  style: t.naslov(velicina: 36, boja: t.istaknut, tezina: FontWeight.w800).copyWith(letterSpacing: 6),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (c) => FilledButton.icon(
                    onPressed: () => podeliPozivnicu(c, s['kod']),
                    icon: const Icon(Icons.share),
                    label: const Text('Pozovi prijatelje'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: linkPozivnice(s['kod'])));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link je kopiran.')));
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Kopiraj link'),
                ),
                const Text('Viber, WhatsApp, Signal, Dart Chat... Soba čeka do 24 sata.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        if (prozivka)
          Card(
            color: t.primarna,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Moderator proziva: svi da potvrde da su spremni!',
                style: t.tekstStil(boja: t.naPrimarnoj),
                textAlign: TextAlign.center,
              ),
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
              color: i['spreman'] == true || i['id'] == s['moderatorId'] ? t.tacno : null,
            ),
          ),
        const SizedBox(height: 8),
        ReakcijeTraka(soba: soba),
        const Divider(),
        Text(
          'Opcije: ${opcije['vreme']} s po pitanju, pauza ${opcije['pauza'] ?? 5} s, ${opcije['brojPitanja']} pitanja, '
          '${opcije['dzokeri'] == false ? 'bez džokera' : 'sa džokerima'}, '
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
      ],
    );
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
  late double _vreme = ((widget.opcije['vreme'] as int).clamp(5, 30)).toDouble();
  late double _pauza = ((widget.opcije['pauza'] as int? ?? 5).clamp(1, 20)).toDouble();
  late bool _dzokeri = widget.opcije['dzokeri'] != false;
  late double _broj = (widget.opcije['brojPitanja'] as int).toDouble();
  late final Set<String> _oblasti = {...(widget.opcije['oblasti'] as List).cast<String>()};
  late final Future<List<Map<String, dynamic>>> _sve = Api.i.oblasti();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Vreme po pitanju: ${_vreme.round()} s'),
          Slider(value: _vreme, min: 5, max: 30, divisions: 25, onChanged: (v) => setState(() => _vreme = v)),
          Text('Pauza između pitanja: ${_pauza.round()} s'),
          Slider(value: _pauza, min: 1, max: 20, divisions: 19, onChanged: (v) => setState(() => _pauza = v)),
          Text('Broj pitanja: ${_broj.round()}'),
          Slider(value: _broj, min: 5, max: 50, divisions: 9, onChanged: (v) => setState(() => _broj = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Džokeri (50:50 i Dupli poeni)'),
            value: _dzokeri,
            onChanged: (v) => setState(() => _dzokeri = v),
          ),
          const Text('Oblasti (ništa izabrano = sve)'),
          FutureBuilder(
            future: _sve,
            builder: (context, snap) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in snap.data ?? const <Map<String, dynamic>>[])
                  FilterChip(
                    label: Text(o['oblast']),
                    selected: _oblasti.contains(o['oblast']),
                    onSelected: (da) => setState(() => da ? _oblasti.add(o['oblast']) : _oblasti.remove(o['oblast'])),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              widget.soba.posalji({
                't': 'opcije',
                'vreme': _vreme.round(),
                'pauza': _pauza.round(),
                'dzokeri': _dzokeri,
                'brojPitanja': _broj.round(),
                'oblasti': _oblasti.toList(),
              });
              Navigator.pop(context);
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }
}

class PitanjeView extends StatefulWidget {
  const PitanjeView({super.key, required this.s, required this.soba, required this.sakriveno, this.solo = false});
  final Map<String, dynamic> s;
  final Soba soba;
  final Map<int, List<int>> sakriveno;
  final bool solo;
  @override
  State<PitanjeView> createState() => _PitanjeViewState();
}

class _PitanjeViewState extends State<PitanjeView> {
  Timer? _tik;
  int? _mojIzbor;
  int _n = -1;
  int _poslednjiTik = -1;

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

  void _odgovori(int k, int n) {
    setState(() => _mojIzbor = k);
    Zvuk.i.klik();
    widget.soba.posalji({'t': 'odgovor', 'pitanje': n, 'izbor': k});
  }

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final p = widget.s['pitanje'] as Map<String, dynamic>;
    final n = p['n'] as int;
    if (n != _n) {
      _n = n;
      _mojIzbor = null;
      _poslednjiTik = -1;
    }
    final otkriveno = widget.s['faza'] == 'otkriveno';
    final ja = Api.i.nalog!.id;
    final opcije = (p['opcije'] as List).cast<String>();
    final sad = DateTime.now().millisecondsSinceEpoch + widget.soba.pomakSata;
    final ostalo = ((p['krajU'] as int) - sad).clamp(0, 600000);
    final ukupno = ((widget.s['opcije'] as Map)['vreme'] as int) * 1000;
    final sekunde = (ostalo / 1000).ceil();
    final igraci = _igraci(widget.s);
    final mene = igraci.where((i) => i['id'] == ja).firstOrNull;
    final uIgri = mene?['uIgri'] == true;
    final poeni = (p['poeni'] as Map?)?.cast<String, int>() ?? {};
    final sakrij = widget.sakriveno[n] ?? const <int>[];
    final dupli = (widget.s['dupli'] as List?)?.contains(ja) == true;
    final dzokeri = (widget.s['opcije'] as Map)['dzokeri'] != false && widget.s['izazov'] == null;
    final iskorisceno = (mene?['dzokeri'] as Map?) ?? const {};
    final mogu = !otkriveno && uIgri && _mojIzbor == null;

    // Otkucaji u poslednjih 5 sekundi, dok nisi odgovorio.
    if (!otkriveno && mogu && sekunde <= 5 && sekunde > 0 && sekunde != _poslednjiTik) {
      _poslednjiTik = sekunde;
      Zvuk.i.tik();
    }

    Widget odgovor(int k) {
      final tacan = otkriveno && k == p['tacan'];
      final pogresan = otkriveno && k == _mojIzbor && !tacan;
      final izabran = !otkriveno && k == _mojIzbor;
      final skriven = sakrij.contains(k) && !otkriveno;
      Color? poz;
      Color? tekst;
      if (t.mreza) {
        poz = tacan
            ? t.tacno
            : pogresan
            ? t.netacno
            : t.bojeOdgovora[k];
        tekst = Colors.white;
      } else if (tacan) {
        poz = t.tacno;
        tekst = Colors.white;
      } else if (pogresan) {
        poz = t.netacno;
        tekst = Colors.white;
      } else if (izabran) {
        poz = t.primarna;
        tekst = t.naPrimarnoj;
      }
      final prigusen =
          skriven ||
          (t.mreza && otkriveno && !tacan && !pogresan) ||
          (t.mreza && !otkriveno && _mojIzbor != null && !izabran);
      final slovo = 'ABCD'[k];
      final dugme = TemaDugme(
        onTap: mogu && !skriven ? () => _odgovori(k, n) : null,
        pozadina: poz,
        tekst: tekst,
        visina: t.mreza ? 96 : 54,
        senka: t.mreza
            ? [BoxShadow(offset: const Offset(0, 5), color: Colors.black.withValues(alpha: .18))]
            : (poz != null && (tacan || pogresan) ? const [] : null),
        obris: t.mreza && izabran ? t.tekst : null,
        poravnanje: t.mreza ? MainAxisAlignment.center : MainAxisAlignment.start,
        child: t.mreza
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SlovoTeme(slovo, boja: Colors.white.withValues(alpha: .3), tekst: Colors.white),
                  const SizedBox(height: 6),
                  Text(skriven ? '' : opcije[k], textAlign: TextAlign.center),
                ],
              )
            : Row(
                children: [
                  SlovoTeme(
                    slovo,
                    boja: poz != null ? Colors.white.withValues(alpha: .25) : null,
                    tekst: poz != null ? tekst : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(skriven ? '' : opcije[k])),
                ],
              ),
      );
      return AnimatedOpacity(duration: const Duration(milliseconds: 250), opacity: prigusen ? .35 : 1, child: dugme);
    }

    final stil = t.tekstStil(velicina: 13, tezina: FontWeight.w700, boja: t.tekst.withValues(alpha: .85));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(child: Text('${n + 1} / ${p['ukupno']} · ${p['oblast']}', style: stil)),
            if (dupli) _Znacka(tekst: '×2', boja: t.primarna, naBoji: t.naPrimarnoj),
            const SizedBox(width: 8),
            TajmerTeme(deo: otkriveno ? 0 : ostalo / ukupno, sekunde: otkriveno ? 0 : sekunde),
          ],
        ),
        const SizedBox(height: 10),
        TrakaTeme(deo: otkriveno ? 0 : ostalo / ukupno),
        const SizedBox(height: 22),
        Text(
          p['tekst'],
          style: t.naslov(velicina: 21, tezina: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        if (t.mreza)
          Column(
            children: [
              for (final red in const [
                [0, 1],
                [2, 3],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: odgovor(red[0])),
                      const SizedBox(width: 10),
                      Expanded(child: odgovor(red[1])),
                    ],
                  ),
                ),
            ],
          )
        else
          for (var k = 0; k < opcije.length; k++)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: odgovor(k)),
        if (dzokeri && uIgri && !otkriveno)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _Dzoker(
                    tekst: '50:50',
                    iskoriscen: iskorisceno['pola'] == true,
                    onTap: mogu ? () => widget.soba.posalji({'t': 'dzoker', 'vrsta': 'pola', 'pitanje': n}) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dzoker(
                    tekst: 'Dupli poeni',
                    iskoriscen: iskorisceno['dupli'] == true,
                    onTap: mogu ? () => widget.soba.posalji({'t': 'dzoker', 'vrsta': 'dupli', 'pitanje': n}) : null,
                  ),
                ),
              ],
            ),
          ),
        if (!uIgri) Text('Gledaš ovu partiju. Igraš od revanša.', textAlign: TextAlign.center, style: stil),
        if (otkriveno && !widget.solo) ...[const SizedBox(height: 4), ReakcijeTraka(soba: widget.soba)],
        const SizedBox(height: 12),
        if (!widget.solo || otkriveno) Tabela(s: widget.s, poeni: otkriveno ? poeni : null),
      ],
    );
  }
}

class _Dzoker extends StatelessWidget {
  const _Dzoker({required this.tekst, required this.iskoriscen, this.onTap});
  final String tekst;
  final bool iskoriscen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return Opacity(
      opacity: iskoriscen ? .35 : 1,
      child: OutlinedButton(
        onPressed: iskoriscen ? null : onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
        child: Text(iskoriscen ? '$tekst ✓' : tekst, style: t.tekstStil(velicina: 14)),
      ),
    );
  }
}

class _Znacka extends StatelessWidget {
  const _Znacka({required this.tekst, required this.boja, required this.naBoji});
  final String tekst;
  final Color boja, naBoji;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: boja, borderRadius: BorderRadius.circular(8)),
    child: Text(
      tekst,
      style: temaOd(context).naslov(velicina: 13, boja: naBoji, tezina: FontWeight.w800),
    ),
  );
}

class Tabela extends StatelessWidget {
  const Tabela({super.key, required this.s, this.poeni});
  final Map<String, dynamic> s;
  final Map<String, int>? poeni;

  /// Ispod pitanja se vidi samo prvih [vidljivo] i tvoj red, da i sa 30
  /// igrača odgovori ostanu na vrhu ekrana.
  static const vidljivo = 5;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final svi = _igraci(s).where((i) => i['uIgri'] == true).toList()
      ..sort((a, b) => (b['poeni'] as int).compareTo(a['poeni'] as int));
    final ja = Api.i.nalog?.id;
    final dupli = ((s['dupli'] as List?) ?? const []).toSet();
    final igraci = [
      for (final (r, i) in svi.indexed)
        if (r < vidljivo || i['id'] == ja) (r, i),
    ];
    final odgovorilo = svi.where((i) => i['odgovorio'] == true).length;
    final slabo = t.tekst.withValues(alpha: .7);
    return Column(
      children: [
        if (poeni == null && svi.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Odgovorilo $odgovorilo od ${svi.length}', style: t.tekstStil(velicina: 13, boja: slabo)),
          ),
        for (final (r, i) in igraci)
          RedTeme(
            ja: i['id'] == ja,
            child: Row(
              children: [
                SizedBox(width: 26, child: Text('${r + 1}.')),
                Text(i['avatar'], style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(child: Text(i['ime'], overflow: TextOverflow.ellipsis)),
                if (dupli.contains(i['id'])) Text('×2  ', style: t.tekstStil(velicina: 12, boja: t.istaknut)),
                if (poeni == null && i['odgovorio'] == true) Icon(Icons.check, size: 16, color: slabo),
                if (poeni != null && poeni!.containsKey(i['id']))
                  Text(
                    '${poeni![i['id']]! > 0 ? '+' : ''}${poeni![i['id']]}  ',
                    style: t.tekstStil(
                      velicina: 14,
                      tezina: FontWeight.w800,
                      boja: poeni![i['id']]! > 0 ? t.tacno : t.netacno,
                    ),
                  ),
                const SizedBox(width: 6),
                Text('${i['poeni']}', style: t.naslov(velicina: 15, tezina: FontWeight.w800)),
              ],
            ),
          ),
        if (svi.length > igraci.length)
          Text('i još ${svi.length - igraci.length}', style: t.tekstStil(velicina: 13, boja: slabo)),
      ],
    );
  }
}

class Kraj extends StatefulWidget {
  const Kraj({
    super.key,
    required this.s,
    required this.soba,
    required this.moderator,
    required this.solo,
    this.izazov = false,
  });
  final Map<String, dynamic> s;
  final Soba soba;
  final bool moderator;
  final bool solo;
  final bool izazov;

  @override
  State<Kraj> createState() => _KrajState();
}

class _KrajState extends State<Kraj> {
  Future<Map<String, dynamic>>? _izazov;

  @override
  void initState() {
    super.initState();
    if (widget.izazov) {
      // Mesto na današnjoj listi; rezultat se upisuje na kraju partije.
      _izazov = Future.delayed(const Duration(milliseconds: 600), Api.i.izazovTop).then((r) {
        Obavestenja.i.zakazi(odigranDan: r['dan'] as String?);
        return r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final igraci = _igraci(widget.s).where((i) => i['uIgri'] == true).toList()
      ..sort((a, b) => (b['poeni'] as int).compareTo(a['poeni'] as int));
    final viseIgraca = igraci.length > 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Text(
          'Kraj!',
          style: t.naslov(velicina: 40, boja: t.logoBoja, senke: t.logoSenke),
          textAlign: TextAlign.center,
        ),
        if (igraci.isNotEmpty && viseIgraca)
          Text(
            'Pobednik: ${igraci.first['avatar']} ${igraci.first['ime']}',
            style: t.naslov(velicina: 18, tezina: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        if (!viseIgraca && igraci.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${igraci.first['poeni']} poena',
            style: t.naslov(velicina: 32, boja: t.istaknut),
            textAlign: TextAlign.center,
          ),
          Text(
            '${igraci.first['tacnih']} tačnih od ${(widget.s['pitanje'] as Map?)?['ukupno'] ?? ''}'.trim(),
            style: t.tekstStil(velicina: 15),
            textAlign: TextAlign.center,
          ),
        ],
        if (_izazov != null)
          FutureBuilder(
            future: _izazov,
            builder: (context, snap) {
              final mesto = (snap.data?['ja'] as Map?)?['mesto'];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  mesto == null ? ' ' : 'Danas si $mesto. na listi izazova',
                  style: t.naslov(velicina: 17, tezina: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        if (viseIgraca) _Postolje(igraci: igraci.take(3).toList()),
        const SizedBox(height: 8),
        for (final (r, i) in igraci.indexed)
          if (!viseIgraca || r >= 3)
            RedTeme(
              ja: i['id'] == Api.i.nalog?.id,
              child: Row(
                children: [
                  SizedBox(width: 26, child: Text('${r + 1}.')),
                  Text(i['avatar'], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${i['ime']} · ${i['tacnih']} tačnih', overflow: TextOverflow.ellipsis)),
                  Text('${i['poeni']}', style: t.naslov(velicina: 16, tezina: FontWeight.w800)),
                ],
              ),
            ),
        const SizedBox(height: 20),
        if (widget.izazov)
          Text('Sledeći izazov stiže u ponoć.', textAlign: TextAlign.center, style: t.tekstStil(velicina: 14))
        else if (widget.moderator)
          TemaDugme(
            glavno: true,
            poravnanje: MainAxisAlignment.center,
            onTap: () => widget.soba.posalji(widget.solo ? {'t': 'pokreni'} : {'t': 'revans'}),
            child: Text(widget.solo ? 'Još jednom' : 'Revanš'),
          )
        else
          Text('Čeka se da moderator pokrene revanš.', textAlign: TextAlign.center, style: t.tekstStil(velicina: 14)),
        if (!widget.solo && !widget.izazov) ...[const SizedBox(height: 12), ReakcijeTraka(soba: widget.soba)],
        const SizedBox(height: 10),
        TemaDugme(
          poravnanje: MainAxisAlignment.center,
          onTap: () => Navigator.of(context).pop(),
          child: const Text('Izađi'),
        ),
      ],
    );
  }
}

class _Postolje extends StatelessWidget {
  const _Postolje({required this.igraci});
  final List<Map<String, dynamic>> igraci;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    Widget stub(int mesto, double visina) {
      if (mesto >= igraci.length) return const SizedBox(width: 92);
      final i = igraci[mesto];
      final prvi = mesto == 0;
      return Container(
        width: 92,
        height: visina,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: prvi ? t.primarna : t.povrsina,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(min(t.zaobljenje, 14)),
            bottom: const Radius.circular(4),
          ),
          border: t.ivica != null && t.debljinaIvice > 0 ? Border.all(color: t.ivica!, width: t.debljinaIvice) : null,
          boxShadow: prvi ? t.senkaPrimarna : t.senka,
        ),
        child: DefaultTextStyle.merge(
          style: t.tekstStil(velicina: 13, boja: prvi ? t.naPrimarnoj : t.naPovrsini, tezina: FontWeight.w800),
          child: Column(
            children: [
              Text(i['avatar'], style: const TextStyle(fontSize: 28)),
              Text(i['ime'], maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${i['poeni']}'),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [stub(1, 112), stub(0, 140), stub(2, 92)],
      ),
    );
  }
}

/// Dugmići za reakcije koje vide svi u sobi.
class ReakcijeTraka extends StatelessWidget {
  const ReakcijeTraka({super.key, required this.soba});
  final Soba soba;
  static const emodziji = ['👏', '😂', '😮', '🔥', '😅', '👍'];

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final e in emodziji)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Zvuk.i.klik();
              soba.posalji({'t': 'reakcija', 'e': e});
            },
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.povrsina2, shape: BoxShape.circle),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}

class _Reakcija {
  _Reakcija(this.id, this.e, this.ime);
  final int id;
  final String e;
  final String ime;
}

/// Reakcija koja se podigne i nestane.
class _LetecaReakcija extends StatelessWidget {
  const _LetecaReakcija({super.key, required this.r});
  final _Reakcija r;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2500),
      builder: (context, v, child) => Opacity(
        opacity: v < .75 ? 1 : (1 - v) * 4,
        child: Transform.translate(offset: Offset(0, -60 * v), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: t.panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(20)),
        child: Text('${r.e}  ${r.ime}', style: t.tekstStil(velicina: 15)),
      ),
    );
  }
}
