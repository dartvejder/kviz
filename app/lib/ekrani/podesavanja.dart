import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api.dart';
import '../obavestenja.dart';
import 'profil.dart';
import 'sacuvaj.dart';
import '../prijava.dart';
import '../push.dart';
import '../tema.dart';
import '../zvuk.dart';

/// Podešavanja: izbor teme. Spisak tema dolazi sa servera.
class PodesavanjaEkran extends StatefulWidget {
  const PodesavanjaEkran({super.key});
  @override
  State<PodesavanjaEkran> createState() => _PodesavanjaEkranState();
}

class _PodesavanjaEkranState extends State<PodesavanjaEkran> {
  List<OpisTeme> _teme = Teme.i.spisak;
  bool _ucitava = true;
  String? _preuzima;

  @override
  void initState() {
    super.initState();
    Teme.i.osvezi().then((s) {
      if (mounted) {
        setState(() {
          _teme = s;
          _ucitava = false;
        });
      }
    });
  }

  /// Menja postojeće vreme podsetnika ili dodaje novo ([staro] == null).
  Future<void> _promeniVreme(String? staro) async {
    final hm = (staro ?? '19:00').split(':');
    final izbor = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])),
      helpText: 'Vreme podsetnika',
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
    );
    if (izbor == null) return;
    final novo = '${izbor.hour.toString().padLeft(2, '0')}:${izbor.minute.toString().padLeft(2, '0')}';
    final lista = [...Obavestenja.i.vremena];
    if (staro != null) lista.remove(staro);
    await Obavestenja.i.postaviVremena([...lista, novo]);
    if (mounted) setState(() {});
  }

  Future<void> _izaberi(OpisTeme o) async {
    if (_preuzima != null) return;
    setState(() => _preuzima = o.id);
    try {
      await Teme.i.izaberi(o.id);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tema nije preuzeta. Proveri internet i pokušaj ponovo.')));
      }
    } finally {
      if (mounted) setState(() => _preuzima = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      naslov: 'Podešavanja',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Naslov('NALOG'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(Api.i.nalog?.avatar ?? '', style: const TextStyle(fontSize: 26)),
            title: Text(Api.i.nalog?.ime ?? ''),
            subtitle: Text(
              (Api.i.nalog?.prijave ?? const []).isEmpty
                  ? 'Napredak je samo na ovom telefonu'
                  : 'Sačuvan preko ${(Api.i.nalog!.prijave).map((p) => p == 'google' ? 'Google' : 'Apple').join(' i ')} naloga',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilEkran()));
              if (mounted) setState(() {});
            },
          ),
          FutureBuilder(
            future: Prijava.dostupna(),
            builder: (context, snap) => snap.data == true && (Api.i.nalog?.prijave ?? const []).isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SacuvajEkran()));
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Sačuvaj napredak'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          _Naslov('ZVUK'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Zvuci u igri'),
            value: Zvuk.i.zvuk,
            onChanged: (v) async {
              await Zvuk.i.postavi(zvuk: v);
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Otkucavanje sata'),
            subtitle: const Text('Tik-tak dok teče vreme, sve brže i više pred kraj'),
            value: Zvuk.i.sat,
            onChanged: Zvuk.i.zvuk
                ? (v) async {
                    await Zvuk.i.postavi(sat: v);
                    setState(() {});
                  }
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibracija'),
            value: Zvuk.i.vibracija,
            onChanged: (v) async {
              await Zvuk.i.postavi(vibracija: v);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _Naslov('PODSETNIK ZA DNEVNI IZAZOV'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Podseti me'),
            subtitle: const Text('Ne javlja se kad je izazov taj dan već odigran. Jutro posle izazova stiže tvoj rezultat.'),
            value: Obavestenja.i.ukljuceno,
            onChanged: (v) async {
              final poruke = ScaffoldMessenger.of(context);
              final ok = await Obavestenja.i.postavi(v);
              await Push.i.uskladi();
              if (!ok) {
                poruke.showSnackBar(
                  const SnackBar(content: Text('Obaveštenja nisu dozvoljena. Uključi ih u podešavanjima telefona.')),
                );
              }
              setState(() {});
            },
          ),
          if (Obavestenja.i.ukljuceno)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final v in Obavestenja.i.vremena)
                  InputChip(
                    label: Text(v, style: t.tekstStil(velicina: 15)),
                    onPressed: () => _promeniVreme(v),
                    onDeleted: Obavestenja.i.vremena.length > 1
                        ? () async {
                            await Obavestenja.i.postaviVremena([...Obavestenja.i.vremena]..remove(v));
                            setState(() {});
                          }
                        : null,
                  ),
                if (Obavestenja.i.vremena.length < Obavestenja.najvise)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Dodaj'),
                    onPressed: () => _promeniVreme(null),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text('TEMA', style: t.naslov(velicina: 13, tezina: FontWeight.w800).copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 10),
          if (_teme.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _ucitava
                    ? const CircularProgressIndicator()
                    : const Text('Teme nisu stigle. Proveri internet.', textAlign: TextAlign.center),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final o in _teme)
                _Kartica(o: o, izabrana: o.id == t.id, preuzima: _preuzima == o.id, onTap: () => _izaberi(o)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Izabrana tema se čuva na telefonu. Kad je izmenimo, telefon preuzme novu verziju.',
            textAlign: TextAlign.center,
            style: t.tekstStil(velicina: 12.5, tezina: FontWeight.w500, boja: t.tekst.withValues(alpha: .75)),
          ),
          const SizedBox(height: 28),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => Text(
              snap.hasData ? 'Verzija ${snap.data!.version} (build ${snap.data!.buildNumber})' : ' ',
              textAlign: TextAlign.center,
              style: t.tekstStil(velicina: 12.5, tezina: FontWeight.w500, boja: t.tekst.withValues(alpha: .6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kartica extends StatelessWidget {
  const _Kartica({required this.o, required this.izabrana, required this.preuzima, required this.onTap});
  final OpisTeme o;
  final bool izabrana, preuzima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final u = o.uzorak.length >= 3 ? o.uzorak : [Colors.grey, Colors.white, Colors.black];
    return Material(
      color: t.povrsina2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: izabrana ? BorderSide(color: t.istaknut, width: 2.5) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [u[0], u[0], u[1], u[1], u[2]], stops: const [0, .5, .5, .8, .8]),
                ),
                alignment: Alignment.center,
                child: preuzima
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : izabrana
                    ? const CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check, size: 18, color: Colors.black),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                o.naziv,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.tekstStil(velicina: 14, boja: t.tekst),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Naslov extends StatelessWidget {
  const _Naslov(this.tekst);
  final String tekst;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      tekst,
      style: temaOd(context).naslov(velicina: 13, tezina: FontWeight.w800).copyWith(letterSpacing: 1.5),
    ),
  );
}
