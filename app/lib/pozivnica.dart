import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Link za pozivnicu u sobu.
String linkPozivnice(String kod) => 'https://kviz.dartchat.trade/i/$kod';

/// Sistemski "Podeli" meni: Viber, WhatsApp, Signal, Dart Chat i sve ostalo.
Future<void> podeliPozivnicu(BuildContext context, String kod) {
  final box = context.findRenderObject() as RenderBox?;
  return SharePlus.instance.share(ShareParams(
    text: 'Igraj Kviz opšte kulture sa mnom! Kod sobe: $kod\n${linkPozivnice(kod)}',
    subject: 'Poziv u kviz',
    // iPad traži mesto odakle meni iskače.
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}

/// Kod sobe iz linka https://kviz.dartchat.trade/i/KOD, ili null.
String? kodIzLinka(Uri uri) {
  if (uri.host != 'kviz.dartchat.trade') return null;
  final s = uri.pathSegments;
  if (s.length < 2 || s[0] != 'i') return null;
  final kod = s[1].toUpperCase();
  return RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(kod) ? kod : null;
}

/// Kodovi iz linkova kojima je aplikacija otvorena (i prvi, i kasniji).
Stream<String> kodoviIzLinkova() => AppLinks().uriLinkStream.map(kodIzLinka).where((k) => k != null).cast<String>();
