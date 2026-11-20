import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../prijava.dart';
import '../tema.dart';

/// Prednosti prijave, isti tekst na kartici početnog ekrana i ovde.
const prednostiPrijave = [
  (Icons.emoji_events, 'Rezultati, značke i statistika prate tvoj nalog, ne telefon.'),
  (Icons.phone_android, 'Nov telefon ili ponovna instalacija: prijaviš se i sve je tu.'),
  (Icons.sync, 'Prelaziš sa Androida na iPhone i nazad bez gubitka.'),
  (Icons.local_fire_department, 'Niz dana dnevnog izazova i prijatelji ostaju.'),
  (Icons.visibility_off, 'Ime i avatar biraš ti. Mejl se ne čuva i niko ga ne vidi.'),
];

/// "Sačuvaj napredak": opciona prijava preko Google ili Apple naloga.
/// [prvi]: sa prvog ekrana, kad na telefonu još nema naloga ("Već si igrao?").
class SacuvajEkran extends StatefulWidget {
  const SacuvajEkran({super.key, this.prvi = false});
  final bool prvi;
  @override
  State<SacuvajEkran> createState() => _SacuvajEkranState();
}

class _SacuvajEkranState extends State<SacuvajEkran> {
  late final Future<bool> _apple = Prijava.apple();
  bool _radim = false;

  Future<void> _prijavi(String provajder) async {
    final poruke = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _radim = true);
    try {
      final token = provajder == 'google' ? await Prijava.googleToken() : await Prijava.appleToken();
      final (stanje, novi) = await Api.i.prijava(provajder, token);
      if (!mounted) return;
      final ime = provajder == 'google' ? 'Google' : 'Apple';
      switch (stanje) {
        case 'povezan' || 'vec':
          poruke.showSnackBar(SnackBar(content: Text('Napredak je sačuvan na $ime nalogu.')));
          nav.pop(true);
        case 'nov':
          poruke.showSnackBar(SnackBar(content: Text('Nalog je napravljen i sačuvan na $ime nalogu.')));
          nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PocetnaEkran()), (_) => false);
        case 'vracen':
          final trenutni = Api.i.nalog;
          final da =
              trenutni == null ||
              await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Vrati sačuvani nalog?'),
                      content: Text(
                        'Ovaj $ime nalog već čuva igrača ${novi!.avatar} ${novi.ime}. '
                        'Ako pređeš na njega, igrač ${trenutni.avatar} ${trenutni.ime} sa ovog telefona '
                        'ostaje poseban nalog i njegovi rezultati se ne spajaju.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ostani ovde')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('Pređi na ${novi.ime}')),
                      ],
                    ),
                  ) ==
                  true;
          if (!da) {
            await Prijava.odjaviGoogle();
            return;
          }
          await Api.i.predjiNa(novi!);
          poruke.showSnackBar(SnackBar(content: Text('Dobro došao nazad, ${novi.ime}!')));
          nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PocetnaEkran()), (_) => false);
      }
    } on Odustao {
      // Korisnik je zatvorio prozor za prijavu.
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
      naslov: widget.prvi ? 'Vrati svoj nalog' : 'Sačuvaj napredak',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.prvi
                    ? 'Ako si već sačuvao napredak na drugom telefonu, prijavi se istim nalogom.'
                    : 'Prijava nije obavezna, ali sa njom ništa ne gubiš:',
                style: t.naslov(velicina: 17, tezina: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (final (ikona, tekst) in prednostiPrijave)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(ikona, color: t.istaknut),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tekst, style: t.tekstStil(velicina: 15))),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (Prijava.google)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: _radim ? null : () => _prijavi('google'),
                    icon: const Icon(Icons.g_mobiledata, size: 30),
                    label: const Text('Nastavi sa Google-om'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ),
              FutureBuilder(
                future: _apple,
                builder: (context, snap) => snap.data == true
                    ? FilledButton.icon(
                        onPressed: _radim ? null : () => _prijavi('apple'),
                        icon: const Icon(Icons.apple),
                        label: const Text('Nastavi sa Apple-om'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (_radim)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 16),
              Text(
                'Kviz od Google-a ili Apple-a dobija samo potvrdu da si to ti. '
                'Nalog i sve podatke brišeš u Profilu, kad god hoćeš.',
                textAlign: TextAlign.center,
                style: t.tekstStil(velicina: 12.5, tezina: FontWeight.w500, boja: t.tekst.withValues(alpha: .7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartica na početnom ekranu dok nalog nije sačuvan.
class SacuvajKartica extends StatelessWidget {
  const SacuvajKartica({super.key, required this.otvori, required this.skloni});
  final VoidCallback otvori;
  final VoidCallback skloni;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return Card(
      color: t.povrsina2,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.zaobljenje + 4),
        side: BorderSide(color: t.istaknut, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.zaobljenje + 4),
        onTap: otvori,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Icon(Icons.cloud_upload, color: t.istaknut, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sačuvaj napredak', style: t.naslov(velicina: 16, tezina: FontWeight.w800)),
                    Text(
                      'Rezultati, značke i niz ostaju i na novom telefonu. Mejl niko ne vidi.',
                      style: t.tekstStil(velicina: 13, tezina: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: 'Ne sada', icon: const Icon(Icons.close), onPressed: skloni),
            ],
          ),
        ),
      ),
    );
  }
}
