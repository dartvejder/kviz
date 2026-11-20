import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Link za pozivnicu u sobu.
String linkPozivnice(String kod) => 'https://kviz.dartchat.trade/i/$kod';

/// Sistemski "Podeli" meni: Viber, WhatsApp, Signal, Dart Chat i sve ostalo.
Future<void> podeliPozivnicu(BuildContext context, String kod) {
  final box = context.findRenderObject() as RenderBox?;
  return SharePlus.instance.share(
    ShareParams(
      text: 'Igraj Kviz opšte kulture sa mnom! Kod sobe: $kod\n${linkPozivnice(kod)}',
      subject: 'Poziv u kviz',
      // iPad traži mesto odakle meni iskače.
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// Kod sobe iz linka https://kviz.dartchat.trade/i/KOD, ili null.
String? kodIzLinka(Uri uri) {
  if (uri.host != 'kviz.dartchat.trade') return null;
  final s = uri.pathSegments;
  if (s.length < 2 || s[0] != 'i') return null;
  final kod = s[1].toUpperCase();
  return RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(kod) ? kod : null;
}

/// Dart Chat token iz linka .../i/KOD#dc=TOKEN (Dart Chat ga dodaje kad se pritisne Pridruži se), ili null.
/// Token je u fragmentu, pa nikad ne ide na server kao deo adrese.
String? dartChatIzLinka(Uri uri) {
  if (!uri.hasFragment || uri.fragment.isEmpty) return null;
  // Ručno, ne splitQueryString: on bi "+" iz tokena pretvorio u razmak.
  for (final deo in uri.fragment.split('&')) {
    if (!deo.startsWith('dc=')) continue;
    try {
      final dc = Uri.decodeComponent(deo.substring(3)).trim();
      return dc.isEmpty || dc.length > 512 ? null : dc;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Poziv iz linka: kod sobe i, ako je link došao iz Dart Chata, njegov token.
class Pozivnica {
  const Pozivnica(this.kod, [this.dartChat]);
  final String kod;
  final String? dartChat;
}

Pozivnica? pozivnicaIzLinka(Uri uri) {
  final kod = kodIzLinka(uri);
  return kod == null ? null : Pozivnica(kod, dartChatIzLinka(uri));
}

/// Pozivnice iz linkova kojima je aplikacija otvorena (i prvi, i kasniji).
Stream<Pozivnica> pozivniceIzLinkova() =>
    AppLinks().uriLinkStream.map(pozivnicaIzLinka).where((p) => p != null).cast<Pozivnica>();

/// Link kojim je aplikacija pokrenuta, ako je to pozivnica.
Future<Pozivnica?> prvaPozivnica() async {
  try {
    final uri = await AppLinks().getInitialLink();
    return uri == null ? null : pozivnicaIzLinka(uri);
  } catch (_) {
    return null;
  }
}
