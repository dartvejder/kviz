import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../tema.dart';
import 'statistika.dart';

/// Ime i avatar; prvi put pravi nalog. Ovde je i "Obriši nalog".
class ProfilEkran extends StatefulWidget {
  const ProfilEkran({super.key, this.prvi = false});
  final bool prvi;
  @override
  State<ProfilEkran> createState() => _ProfilEkranState();
}

class _ProfilEkranState extends State<ProfilEkran> {
  late final _ime = TextEditingController(text: Api.i.nalog?.ime ?? '');
  late String _avatar = Api.i.nalog?.avatar ?? avatari.first;
  bool _radim = false;

  Future<void> _sacuvaj() async {
    if (_ime.text.trim().isEmpty) return;
    setState(() => _radim = true);
    try {
      await Api.i.postaviIgraca(_ime.text.trim(), _avatar);
      if (!mounted) return;
      if (widget.prvi) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PocetnaEkran()));
      } else {
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _radim = false);
    }
  }

  Future<void> _obrisi() async {
    final da = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Obriši nalog?'),
        content: const Text('Brišu se tvoje ime, rezultati i spisak odigranih pitanja. Ovo ne može da se vrati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Otkaži')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
        ],
      ),
    );
    if (da != true) return;
    await Api.i.obrisiNalog();
    if (!mounted) return;
    Navigator.of(context)
        .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfilEkran(prvi: true)), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return KvizEkran(
      tema: temaOd(context),
      naslov: widget.prvi ? 'Dobro došao' : 'Profil',
      nazad: !widget.prvi,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _ime,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tvoje ime', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Izaberi avatar'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in avatari)
                    ChoiceChip(
                      label: Text(a, style: const TextStyle(fontSize: 28)),
                      selected: a == _avatar,
                      onSelected: (_) => setState(() => _avatar = a),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _radim ? null : _sacuvaj, child: const Text('Sačuvaj')),
              if (!widget.prvi) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatistikaEkran())),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Moja statistika'),
                ),
                const SizedBox(height: 36),
                TextButton.icon(
                  onPressed: _obrisi,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Obriši nalog'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
