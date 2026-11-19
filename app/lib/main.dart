import 'package:flutter/material.dart';

import 'api.dart';
import 'ekrani/igra.dart';
import 'ekrani/profil.dart';
import 'ekrani/top.dart';
import 'tema.dart';

void main() => runApp(const KvizApp());

class KvizApp extends StatelessWidget {
  const KvizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kviz opšte kulture',
      debugShowCheckedModeBanner: false,
      theme: kvizTema(),
      home: const Pokretanje(),
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
  late final Future<Nalog?> _nalog = Api.i.ucitajNalog();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _nalog,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const ProfilEkran(prvi: true) : const PocetnaEkran();
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

  Future<void> _novaIgra({bool solo = false}) async {
    setState(() => _radim = true);
    try {
      final kod = await Api.i.novaSoba();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => IgraEkran(kod: kod, solo: solo)));
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => IgraEkran(kod: k)));
  }

  @override
  Widget build(BuildContext context) {
    final ja = Api.i.nalog!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Text('Kviz', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayMedium),
                Text('opšte kulture', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 32),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilEkran()));
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(ja.avatar, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 12),
                      Text(ja.ime, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
                VelikoDugme(ikona: Icons.group_add, tekst: 'Nova igra', onTap: _radim ? null : () => _novaIgra()),
                VelikoDugme(ikona: Icons.login, tekst: 'Uđi kodom', onTap: _radim ? null : _udjiKodom),
                VelikoDugme(ikona: Icons.person, tekst: 'Vežbaj sam', onTap: _radim ? null : () => _novaIgra(solo: true)),
                VelikoDugme(
                  ikona: Icons.emoji_events,
                  tekst: 'Top lista',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopEkran())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
