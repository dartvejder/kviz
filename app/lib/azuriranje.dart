// Obavezno ažuriranje: Android ga sam nudi preko Google Play-a (immediate), a server zna najmanji
// dozvoljeni build po platformi pa starija aplikacija traži ažuriranje pre igre.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'tema.dart';

/// Adresa prodavnice ako je ovaj build stariji od najmanjeg dozvoljenog, inače null.
String? adresaZaAzuriranje(Map<String, dynamic> odgovor, String platforma, int build) {
  final p = odgovor[platforma];
  if (p is! Map) return null;
  final min = p['min'];
  final adresa = p['prodavnica'];
  if (min is! int || adresa is! String || build <= 0) return null;
  return build < min ? adresa : null;
}

/// Pita server da li ovaj build sme da igra. Bez interneta ili na grešku pušta dalje.
Future<String?> proveriVerziju() async {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    final r = await http.get(Uri.parse('$server/api/verzija')).timeout(const Duration(seconds: 4));
    if (r.statusCode != 200) return null;
    final telo = jsonDecode(r.body);
    if (telo is! Map<String, dynamic>) return null;
    return adresaZaAzuriranje(telo, Platform.isAndroid ? 'android' : 'ios', build);
  } catch (_) {
    return null;
  }
}

/// Android: kad Google Play ima noviju verziju, odmah je instalira (ekran preko cele aplikacije).
Future<void> androidAzuriranje() async {
  if (!Platform.isAndroid) return;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable && info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    }
  } catch (_) {
    // Aplikacija nije instalirana sa Google Play-a (npr. APK) ili Play nije dostupan.
  }
}

class AzurirajEkran extends StatelessWidget {
  const AzurirajEkran({super.key, required this.adresa});
  final String adresa;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return KvizEkran(
      tema: t,
      nazad: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const LogoTeme(),
              const SizedBox(height: 28),
              Text(
                'Stigla je nova verzija Kviza',
                textAlign: TextAlign.center,
                style: t.naslov(velicina: 22, tezina: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Ažuriraj aplikaciju da nastaviš da igraš.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.tekst),
              ),
              const SizedBox(height: 28),
              VelikoDugme(
                ikona: Icons.system_update,
                tekst: Platform.isIOS ? 'Ažuriraj u TestFlight-u' : 'Ažuriraj na Google Play-u',
                glavno: true,
                onTap: () => launchUrl(Uri.parse(adresa), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
