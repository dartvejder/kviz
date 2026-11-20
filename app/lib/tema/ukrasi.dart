import 'dart:math';

import 'package:flutter/material.dart';

import 'model.dart';

/// Pozadina teme: osnovna boja, slojevi gradijenata i ukrasi.
class PozadinaTeme extends StatelessWidget {
  const PozadinaTeme({super.key, required this.tema, this.child});
  final KvizTema tema;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tema.pozadinaBoja),
        for (final s in tema.slojevi) DecoratedBox(decoration: BoxDecoration(gradient: _gradijent(s))),
        RepaintBoundary(child: CustomPaint(painter: _Ukrasi(tema))),
        if (child != null) Padding(padding: tema.okvir, child: child),
      ],
    );
  }

  static Gradient? _gradijent(Map s) {
    final b = boje(s['boje']);
    if (b.length < 2) return null;
    final st = s['stopovi'] is List ? [for (final x in s['stopovi'] as List) broj(x)] : null;
    final stopovi = st != null && st.length == b.length ? st : null;
    if (s['tip'] == 'radial') {
      final c = s['centar'] is List ? s['centar'] as List : const [0, 0];
      return RadialGradient(
        center: Alignment(broj(c[0]), broj(c[1])),
        radius: broj(s['radijus'], .7),
        colors: b,
        stops: stopovi,
      );
    }
    // ugao kao u CSS-u: 180 = odozgo nadole, 90 = sleva nadesno.
    final u = (broj(s['ugao'], 180) - 90) * pi / 180;
    final kraj = Alignment(cos(u), sin(u));
    return LinearGradient(begin: -kraj, end: kraj, colors: b, stops: stopovi);
  }
}

class _Ukrasi extends CustomPainter {
  _Ukrasi(this.t);
  final KvizTema t;

  @override
  void paint(Canvas c, Size v) {
    for (final u in t.ukrasi) {
      switch (u['tip']) {
        case 'reflektori':
          _reflektori(c, v, boja(u['boja']));
        case 'neonMreza':
          _neonMreza(c, v, boja(u['boja']));
        case 'krugovi':
          for (final k in ((u['krugovi'] as List?) ?? const []).cast<Map>()) {
            c.drawCircle(
              Offset(broj(k['x']) * v.width, broj(k['y']) * v.height),
              broj(k['r']) * v.width,
              Paint()..color = boja(k['boja']),
            );
          }
        case 'cilim':
          _cilim(c, v, boje(u['boje']), broj(u['visina'], 34));
        case 'ram':
          _ram(c, v, boja(u['boja']), boja(u['boja2']), broj(u['debljina'], 10));
        case 'mehurici':
          _mehurici(c, v, boja(u['boja']));
        case 'zvezde':
          _zvezde(c, v, boja(u['boja']), broj(u['broj'], 60).round());
        case 'planeta':
          _planeta(c, v, boje(u['boje']), boja(u['prsten']));
        case 'pikselOblaci':
          _pikselOblaci(c, v, boja(u['boja']));
      }
    }
  }

  void _reflektori(Canvas c, Size v, Color b) {
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [b, b.withValues(alpha: 0)],
        stops: const [0, .8],
      ).createShader(Rect.fromLTWH(0, 0, 180, v.height * .7))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (final (x, ugao) in [(-50.0, -.42), (v.width + 50 - 180, .42)]) {
      c.save();
      c.translate(x + 90, -40);
      c.rotate(ugao);
      c.translate(-90, 0);
      c.drawRect(Rect.fromLTWH(0, 0, 180, v.height * .7), p);
      c.restore();
    }
  }

  void _neonMreza(Canvas c, Size v, Color b) {
    final visina = v.height * .3;
    final vrh = v.height - visina;
    final horizont = Offset(v.width / 2, vrh - visina * 1.2);
    final p = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    c.save();
    c.clipRect(Rect.fromLTWH(0, vrh, v.width, visina));
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [b.withValues(alpha: 0), b],
    ).createShader(Rect.fromLTWH(0, vrh, v.width, visina));
    for (var i = 0; i < 12; i++) {
      final y = vrh + visina * pow(i / 11, 1.8);
      c.drawLine(Offset(0, y), Offset(v.width, y), p);
    }
    for (var i = -10; i <= 10; i++) {
      final dole = Offset(v.width / 2 + i * v.width / 7, v.height);
      c.drawLine(horizont, dole, p);
    }
    c.restore();
  }

  void _cilim(Canvas c, Size v, List<Color> b, double h) {
    if (b.length < 3) return;
    for (final y0 in [0.0, v.height - h]) {
      c.drawRect(Rect.fromLTWH(0, y0, v.width, h), Paint()..color = b[0]);
      final s = h / 2;
      var k = 0;
      for (double x = -s; x < v.width + s; x += s, k++) {
        // Romb sa naizmeničnim bojama, kao šara pirotskog ćilima.
        final romb = Path()
          ..moveTo(x + s / 2, y0 + 2)
          ..lineTo(x + s, y0 + h / 2)
          ..lineTo(x + s / 2, y0 + h - 2)
          ..lineTo(x, y0 + h / 2)
          ..close();
        c.drawPath(romb, Paint()..color = k.isEven ? b[1] : b[2]);
        c.drawCircle(Offset(x + s / 2, y0 + h / 2), s / 7, Paint()..color = b[0]);
      }
      final ivica = Paint()..color = b[2];
      c.drawRect(Rect.fromLTWH(0, y0 == 0 ? h - 2 : y0, v.width, 2), ivica);
    }
  }

  void _ram(Canvas c, Size v, Color b, Color b2, double d) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = d
      ..color = b;
    c.drawRect(Rect.fromLTWH(d / 2, d / 2, v.width - d, v.height - d), p);
    c.drawRect(
      Rect.fromLTWH(d + 1, d + 1, v.width - 2 * d - 2, v.height - 2 * d - 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = b2,
    );
    // Kreda na donjoj letvici.
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(30, v.height - d - 12, 46, 8), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(88, v.height - d - 12, 46, 8), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFE27A),
    );
  }

  void _mehurici(Canvas c, Size v, Color b) {
    final r = Random(7);
    for (var i = 0; i < 16; i++) {
      final o = Offset(r.nextDouble() * v.width, v.height * (.25 + r.nextDouble() * .75));
      final rad = 3 + r.nextDouble() * 10;
      c.drawCircle(o, rad, Paint()..color = b);
      c.drawCircle(
        o,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = b.withValues(alpha: min(1, b.a * 2)),
      );
    }
  }

  void _zvezde(Canvas c, Size v, Color b, int n) {
    final r = Random(3);
    for (var i = 0; i < n; i++) {
      c.drawCircle(
        Offset(r.nextDouble() * v.width, r.nextDouble() * v.height),
        .5 + r.nextDouble() * 1.1,
        Paint()..color = b.withValues(alpha: .35 + r.nextDouble() * .65),
      );
    }
  }

  void _planeta(Canvas c, Size v, List<Color> b, Color prsten) {
    if (b.length < 3) return;
    final centar = Offset(v.width + 2, v.height * .74);
    const r = 62.0;
    c.drawCircle(
      centar,
      r + 10,
      Paint()
        ..color = b[1].withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    c.drawCircle(
      centar,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: b,
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: centar, radius: r)),
    );
    c.save();
    c.translate(centar.dx, centar.dy);
    c.rotate(-.32);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 3.3, height: r * .66),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = prsten,
    );
    c.restore();
  }

  void _pikselOblaci(Canvas c, Size v, Color b) {
    const k = 12.0;
    final p = Paint()..color = b;
    void oblak(double x, double y, List<String> oblik) {
      for (var red = 0; red < oblik.length; red++) {
        for (var kol = 0; kol < oblik[red].length; kol++) {
          if (oblik[red][kol] == '#') c.drawRect(Rect.fromLTWH(x + kol * k, y + red * k, k, k), p);
        }
      }
    }

    oblak(24, 50, const ['.###.', '#####']);
    oblak(v.width - 90, 34, const ['.##.', '####']);
    oblak(v.width * .45, v.height * .52, const ['..##..', '######']);
  }

  @override
  bool shouldRepaint(_Ukrasi o) => o.t != t;
}

/// Ekran sa pozadinom teme i providnom trakom na vrhu.
class KvizEkran extends StatelessWidget {
  const KvizEkran({super.key, required this.tema, required this.body, this.naslov, this.akcije, this.nazad = true});
  final KvizTema tema;
  final Widget body;
  final String? naslov;
  final List<Widget>? akcije;
  final bool nazad;

  @override
  Widget build(BuildContext context) {
    return PozadinaTeme(
      tema: tema,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: naslov == null && akcije == null && !nazad
            ? null
            : AppBar(title: naslov == null ? null : Text(naslov!), actions: akcije, automaticallyImplyLeading: nazad),
        body: SafeArea(top: naslov == null && akcije == null && !nazad, child: body),
      ),
    );
  }
}
