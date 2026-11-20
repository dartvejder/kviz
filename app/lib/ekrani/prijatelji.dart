import 'package:flutter/material.dart';

import '../api.dart';
import '../tema.dart';
import 'igra.dart';
import 'top.dart' show partija;

/// Prijatelji: ljudi sa kojima si igrao. Dodir na prijatelja pravi novu sobu i šalje mu poziv.
class PrijateljiEkran extends StatefulWidget {
  const PrijateljiEkran({super.key});
  @override
  State<PrijateljiEkran> createState() => _PrijateljiEkranState();
}

class _PrijateljiEkranState extends State<PrijateljiEkran> {
  late final Future<List<Map<String, dynamic>>> _lista = Api.i.prijatelji();
  final Set<String> _izabrani = {};
  bool _radim = false;

  Future<void> _pozovi() async {
    if (_izabrani.isEmpty) return;
    setState(() => _radim = true);
    final poruke = ScaffoldMessenger.of(context);
    try {
      final kod = await Api.i.novaSoba();
      // Prvo uđi u sobu (server proverava da si u njoj), pa pošalji pozive.
      final soba = Api.i.udji(kod);
      await soba.stanja.first.timeout(const Duration(seconds: 8));
      final n = await Api.i.pozovi(kod, _izabrani.toList());
      soba.zatvori();
      poruke.showSnackBar(SnackBar(content: Text(n == 1 ? 'Poziv je poslat.' : 'Poslato poziva: $n')));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => IgraEkran(kod: kod, nova: true)));
    } on Exception catch (e) {
      poruke.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _radim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      naslov: 'Prijatelji',
      body: FutureBuilder(
        future: _lista,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ovde će biti svi sa kojima odigraš partiju. Pozovi nekog linkom, a sledeći put ga zoveš odavde.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Izaberi koga zoveš. Poziv vide na početnom ekranu kad otvore Kviz.',
                  textAlign: TextAlign.center,
                  style: t.tekstStil(velicina: 13.5, tezina: FontWeight.w500),
                ),
              ),
              Expanded(
                child: ListaPrijatelja(lista: lista, izabrani: _izabrani, promena: () => setState(() {})),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TemaDugme(
                  glavno: true,
                  poravnanje: MainAxisAlignment.center,
                  onTap: _izabrani.isEmpty || _radim ? null : _pozovi,
                  child: Text(_izabrani.isEmpty ? 'Izaberi prijatelje' : 'Nova igra i pozovi (${_izabrani.length})'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Spisak prijatelja sa kvačicama.
class ListaPrijatelja extends StatelessWidget {
  const ListaPrijatelja({super.key, required this.lista, required this.izabrani, required this.promena, this.vecTu});
  final List<Map<String, dynamic>> lista;
  final Set<String> izabrani;
  final VoidCallback promena;

  /// Ko je već u sobi (ne nudi se).
  final Set<String>? vecTu;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final ponudi = lista.where((p) => !(vecTu?.contains(p['id']) ?? false)).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: ponudi.length,
      itemBuilder: (context, k) {
        final p = ponudi[k];
        final id = p['id'] as String;
        return CheckboxListTile(
          value: izabrani.contains(id),
          onChanged: (da) {
            da == true ? izabrani.add(id) : izabrani.remove(id);
            promena();
          },
          secondary: Text(p['avatar'], style: const TextStyle(fontSize: 28)),
          title: Text(p['ime']),
          subtitle: Text('Zajedno: ${partija(p['partija'] as int)}', style: t.tekstStil(velicina: 12.5)),
        );
      },
    );
  }
}

/// Iz čekaonice: pozovi prijatelje iz Kviza u ovu sobu.
Future<void> pozoviUSobu(BuildContext context, String kod, Set<String> vecTu) async {
  final poruke = ScaffoldMessenger.of(context);
  final izabrani = <String>{};
  final posalji = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SizedBox(
      height: MediaQuery.of(c).size.height * .7,
      child: FutureBuilder(
        future: Api.i.prijatelji(),
        builder: (c, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.where((p) => !vecTu.contains(p['id'])).isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nema koga da pozoveš odavde. Ovde su oni sa kojima si već igrao.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return StatefulBuilder(
            builder: (c, postavi) => Column(
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('Pozovi prijatelje iz Kviza')),
                Expanded(
                  child: ListaPrijatelja(
                    lista: snap.data!,
                    izabrani: izabrani,
                    vecTu: vecTu,
                    promena: () => postavi(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: izabrani.isEmpty ? null : () => Navigator.pop(c, true),
                    child: Text('Pošalji poziv (${izabrani.length})'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  if (posalji != true) return;
  try {
    final n = await Api.i.pozovi(kod, izabrani.toList());
    poruke.showSnackBar(SnackBar(content: Text(n == 1 ? 'Poziv je poslat.' : 'Poslato poziva: $n')));
  } on Exception catch (e) {
    poruke.showSnackBar(SnackBar(content: Text('$e')));
  }
}
