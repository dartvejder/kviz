import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'azuriranje.dart';
import 'ekrani/igra.dart';
import 'ekrani/podesavanja.dart';
import 'ekrani/profil.dart';
import 'ekrani/statistika.dart';
import 'ekrani/top.dart';
import 'moje_sobe.dart';
import 'pozivnica.dart';
import 'obavestenja.dart';
import 'tema.dart';
import 'zvuk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Teme.i.ucitaj();
  await Zvuk.i.ucitaj();
  await Obavestenja.i.ucitaj();
  runApp(const KvizApp());
}

class KvizApp extends StatelessWidget {
  const KvizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TemaScope(
      builder: (context, t) => MaterialApp(
        title: 'Kviz opšte kulture',
        debugShowCheckedModeBanner: false,
        theme: t.themeData(),
        home: const Pokretanje(),
      ),
    );
  }
}

/// Učitava nalog; bez naloga prvo traži ime i avatar.
class Pokretanje extends StatefulWidget {
  const Pokretanje({super.key});
  @override
  State<Pokretanje> createState() => _PokretanjeState();
}

class _PokretanjeState extends State<Pokretanje> {
  late final Future<(Nalog?, String?)> _nalog = _ucitaj();

  /// Adresa prodavnice ako je ova verzija prestara za igru.
  late final Future<String?> _azuriranje = proveriVerziju();

  @override
  void initState() {
    super.initState();
    androidAzuriranje();
  }

  /// Nalog, a ako ga nema i aplikacija je otvorena linkom iz Dart Chata, predlog imena odande.
  Future<(Nalog?, String?)> _ucitaj() async {
    final nalog = await Api.i.ucitajNalog();
    if (nalog != null) return (nalog, null);
    final dc = (await prvaPozivnica())?.dartChat;
    if (dc == null) return (null, null);
    try {
      return (null, await Api.i.dartChatIme(dc).timeout(const Duration(seconds: 5)));
    } catch (_) {
      return (null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_nalog, _azuriranje]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return KvizEkran(
            tema: temaOd(context),
            nazad: false,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final adresa = snap.data?[1] as String?;
        if (adresa != null) return AzurirajEkran(adresa: adresa);
        final (nalog, predlogImena) = (snap.data?[0] as (Nalog?, String?)?) ?? (null, null);
        return nalog == null ? ProfilEkran(prvi: true, predlogImena: predlogImena) : const PocetnaEkran();
      },
    );
  }
}

class PocetnaEkran extends StatefulWidget {
  const PocetnaEkran({super.key});
  @override
  State<PocetnaEkran> createState() => _PocetnaEkranState();
}

class _PocetnaEkranState extends State<PocetnaEkran> {
  bool _radim = false;
  StreamSubscription<Pozivnica>? _linkovi;

  /// Moj današnji izazov: null dok se ne učita ili ako nije igran.
  Map<String, dynamic>? _izazov;

  /// Niz dana dnevnog izazova: {niz, danas}.
  Map<String, dynamic>? _niz;

  Future<void> _ucitajIzazov() async {
    try {
      final r = await Api.i.izazovTop();
      final ja = r['ja'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _izazov = ja;
          _niz = r['niz'] as Map<String, dynamic>?;
        });
      }
      // Podsetnici: preskače se dan kad je izazov već odigran (i telefon traži dozvolu prvi put).
      await Obavestenja.i.zakazi(odigranDan: ja != null ? r['dan'] as String? : null, traziDozvolu: true);
    } catch (_) {
      // Bez interneta: dugme ostaje "Dnevni izazov".
    }
  }

  /// Sobe u koje sam ulazio, sa stanjem sa servera (null dok se ne učita ili bez interneta).
  List<(MojaSoba, Map<String, dynamic>?)> _sobe = [];

  Future<void> _ucitajSobe() async {
    final lista = await MojeSobe.lista();
    final sobe = <(MojaSoba, Map<String, dynamic>?)>[];
    await Future.wait([
      for (final s in lista)
        () async {
          try {
            final p = await Api.i.pregledSobe(s.kod).timeout(const Duration(seconds: 6));
            // Istekla ili sam izašao iz nje: nema je više u spisku.
            if (p == null || p['ja'] == false) {
              await MojeSobe.zaboravi(s.kod);
              return;
            }
            sobe.add((s, p));
          } catch (_) {
            sobe.add((s, null));
          }
        }(),
    ]);
    sobe.sort((a, b) => b.$1.usao.compareTo(a.$1.usao));
    if (mounted) setState(() => _sobe = sobe);
  }

  String _opisSobe(MojaSoba s, Map<String, dynamic>? p) {
    if (p == null) return 'Soba ${s.kod}';
    final faza = switch (p['faza']) {
      'cekaonica' => 'čeka igrače',
      'igra' => 'igra u toku',
      _ => 'kraj partije',
    };
    final n = p['igraca'] as int? ?? 0;
    return 'Soba ${s.kod} · $faza · $n ${n % 10 == 1 && n % 100 != 11 ? 'igrač' : 'igrača'}';
  }

  Future<void> _uSobu(String kod) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => IgraEkran(kod: kod)));
    await _ucitajSobe();
  }

  Future<void> _dnevniIzazov() async {
    if (_izazov != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopEkran(period: 'izazov')));
      return;
    }
    setState(() => _radim = true);
    try {
      final kod = await Api.i.izazov();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => IgraEkran(kod: kod, izazov: true)));
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _radim = false);
      await _ucitajIzazov();
    }
  }

  String get _izazovTekst {
    final z = _izazov;
    final niz = _niz?['niz'] as int? ?? 0;
    if (z == null) return niz > 0 ? 'Dnevni izazov · 🔥 ${dana(niz)} zaredom' : 'Dnevni izazov';
    if (z['zavrsen'] != true) return 'Izazov: prekinut danas';
    return 'Izazov: ${z['poeni']} poena${z['mesto'] != null ? ' · ${z['mesto']}. mesto' : ''}'
        '${niz > 1 ? ' · 🔥 $niz' : ''}';
  }

  @override
  void initState() {
    super.initState();
    _ucitajIzazov();
    _ucitajSobe();
    // Link pozivnice (Viber, WhatsApp...) vodi pravo u sobu.
    _linkovi = pozivniceIzLinkova().listen(_otvoriPozivnicu);
  }

  /// Link iz Dart Chata prvo poveže nalog (pre ulaska, da pozivar dobije ulogu moderatora), pa ulazi u sobu.
  Future<void> _otvoriPozivnicu(Pozivnica p) async {
    final dc = p.dartChat;
    if (dc != null) {
      try {
        await Api.i.poveziDartChat(dc).timeout(const Duration(seconds: 8));
      } catch (e) {
        // Igra radi i bez veze sa Dart Chatom.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dart Chat nalog nije povezan: $e')));
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await _uSobu(p.kod);
  }

  @override
  void dispose() {
    _linkovi?.cancel();
    super.dispose();
  }

  Future<void> _novaIgra({bool solo = false}) async {
    setState(() => _radim = true);
    try {
      final kod = await Api.i.novaSoba();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IgraEkran(kod: kod, solo: solo),
        ),
      );
      await _ucitajSobe();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _radim = false);
    }
  }

  Future<void> _udjiKodom() async {
    final kontroler = TextEditingController();
    final kod = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Uđi u igru'),
        content: TextField(
          controller: kontroler,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Kod sobe, npr. K7QX2M'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Otkaži')),
          FilledButton(onPressed: () => Navigator.pop(c, kontroler.text), child: const Text('Uđi')),
        ],
      ),
    );
    final k = kod?.trim().toUpperCase() ?? '';
    if (k.length != 6 || !mounted) return;
    await _uSobu(k);
  }

  @override
  Widget build(BuildContext context) {
    final ja = Api.i.nalog!;
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      nazad: false,
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 28),
                  const LogoTeme(),
                  const SizedBox(height: 28),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilEkran()));
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.povrsina2,
                              shape: t.zaobljenje == 0 ? BoxShape.rectangle : BoxShape.circle,
                              border: Border.all(color: t.istaknut, width: 2),
                            ),
                            child: Text(ja.avatar, style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(ja.ime, style: t.naslov(velicina: 19, tezina: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit, size: 18, color: t.tekst.withValues(alpha: .6)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_sobe.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Tvoje sobe', style: t.naslov(velicina: 15, tezina: FontWeight.w700)),
                    ),
                    for (final (soba, p) in _sobe)
                      VelikoDugme(
                        ikona: Icons.meeting_room,
                        tekst: _opisSobe(soba, p),
                        glavno: p?['faza'] == 'igra',
                        onTap: _radim ? null : () => _uSobu(soba.kod),
                      ),
                    const SizedBox(height: 12),
                  ],
                  VelikoDugme(
                    ikona: Icons.add,
                    tekst: 'Nova igra',
                    glavno: true,
                    onTap: _radim ? null : () => _novaIgra(),
                  ),
                  VelikoDugme(
                    ikona: _izazov == null ? Icons.today : Icons.check_circle,
                    tekst: _izazovTekst,
                    onTap: _radim ? null : _dnevniIzazov,
                  ),
                  VelikoDugme(ikona: Icons.login, tekst: 'Uđi kodom', onTap: _radim ? null : _udjiKodom),
                  VelikoDugme(
                    ikona: Icons.person,
                    tekst: 'Vežbaj sam',
                    onTap: _radim ? null : () => _novaIgra(solo: true),
                  ),
                  VelikoDugme(
                    ikona: Icons.emoji_events,
                    tekst: 'Top lista',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopEkran())),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              tooltip: 'Moja statistika',
              icon: Icon(Icons.bar_chart, color: t.tekst.withValues(alpha: .85)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatistikaEkran())),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Podešavanja',
              icon: Icon(Icons.settings, color: t.tekst.withValues(alpha: .85)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PodesavanjaEkran())),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1 dan", "2 dana", "5 dana", "21 dan".
String dana(int n) => n % 10 == 1 && n % 100 != 11 ? '$n dan' : '$n dana';
