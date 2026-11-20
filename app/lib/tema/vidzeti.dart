import 'dart:math';

import 'package:flutter/material.dart';

import 'kontroler.dart';
import 'model.dart';

/// Trenutna tema.
KvizTema temaOd(BuildContext context) => _TemaScope.of(context);

/// Daje temu svim ekranima i obnavlja ih kad se tema promeni.
class TemaScope extends StatelessWidget {
  const TemaScope({super.key, required this.builder});
  final Widget Function(BuildContext, KvizTema) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: Teme.i.tema,
    builder: (context, t, _) => _TemaScope(
      tema: t,
      child: Builder(builder: (c) => builder(c, t)),
    ),
  );
}

class _TemaScope extends InheritedWidget {
  const _TemaScope({required this.tema, required super.child});
  final KvizTema tema;

  static KvizTema of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TemaScope>()?.tema ?? Teme.i.tema.value;

  @override
  bool updateShouldNotify(_TemaScope old) => old.tema != tema;
}

/// Dugme u stilu teme (početni ekran, odgovori, revanš).
class TemaDugme extends StatelessWidget {
  const TemaDugme({
    super.key,
    required this.child,
    this.onTap,
    this.glavno = false,
    this.pozadina,
    this.tekst,
    this.visina = 54,
    this.senka,
    this.obris,
    this.poravnanje = MainAxisAlignment.start,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool glavno;
  final Color? pozadina;
  final Color? tekst;
  final double visina;
  final List<BoxShadow>? senka;

  /// Debeo okvir oko izabranog polja (tema Bojanka).
  final Color? obris;
  final MainAxisAlignment poravnanje;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final r = BorderRadius.circular(t.zaobljenje);
    final ivicaBoja = glavno ? (t.ivicaPrimarna ?? t.ivica) : t.ivica;
    final punaIvica = ivicaBoja != null && t.debljinaIvice > 0 && !(t.isprekidana && !glavno);
    final bojaTeksta = tekst ?? (glavno ? t.naPrimarnoj : t.naPovrsini);
    Widget sadrzaj = Container(
      constraints: BoxConstraints(minHeight: visina),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: pozadina ?? (glavno ? t.primarna : t.povrsina),
        borderRadius: r,
        border: punaIvica ? Border.all(color: ivicaBoja, width: t.debljinaIvice) : null,
        boxShadow: senka ?? (glavno ? t.senkaPrimarna : t.senka),
      ),
      child: DefaultTextStyle.merge(
        style: t.tekstStil(velicina: 16, boja: bojaTeksta),
        child: IconTheme.merge(
          data: IconThemeData(color: bojaTeksta, size: 20),
          child: Row(
            mainAxisAlignment: poravnanje,
            children: [Flexible(child: child)],
          ),
        ),
      ),
    );
    if (t.isprekidana && !glavno && ivicaBoja != null) {
      sadrzaj = CustomPaint(foregroundPainter: _Isprekidano(ivicaBoja, t.debljinaIvice, t.zaobljenje), child: sadrzaj);
    }
    if (obris != null) {
      sadrzaj = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: obris!, width: 3),
          borderRadius: BorderRadius.circular(t.zaobljenje + 5),
        ),
        child: sadrzaj,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, borderRadius: r, child: sadrzaj),
    );
  }
}

class _Isprekidano extends CustomPainter {
  _Isprekidano(this.boja, this.debljina, this.zaobljenje);
  final Color boja;
  final double debljina, zaobljenje;

  @override
  void paint(Canvas c, Size v) {
    final p = Paint()
      ..color = boja
      ..style = PaintingStyle.stroke
      ..strokeWidth = debljina;
    final put = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & v).deflate(debljina / 2),
          Radius.circular(min(zaobljenje, v.shortestSide / 2)),
        ),
      );
    for (final m in put.computeMetrics()) {
      for (double d = 0; d < m.length; d += 13) {
        c.drawPath(m.extractPath(d, min(d + 7, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Isprekidano o) => o.boja != boja || o.debljina != debljina;
}

/// Natpis "Kviz / opšte kulture" u stilu teme.
class LogoTeme extends StatelessWidget {
  const LogoTeme({super.key});

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    var stil = t
        .naslov(velicina: t.logoVelicina / t.skala, boja: t.logoBoja, senke: t.logoSenke)
        .copyWith(letterSpacing: t.logoRazmak, fontStyle: t.logoKurziv ? FontStyle.italic : null, height: 1);
    Widget logo = Text(t.logoTekst, textAlign: TextAlign.center, style: stil);
    if (t.logoGradijent.length >= 2) {
      logo = ShaderMask(
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.logoGradijent,
        ).createShader(r),
        child: Text(
          t.logoTekst,
          textAlign: TextAlign.center,
          style: stil.copyWith(color: Colors.white),
        ),
      );
    }
    return Column(
      children: [
        logo,
        const SizedBox(height: 6),
        Text(
          'OPŠTE KULTURE',
          textAlign: TextAlign.center,
          style: t.tekstStil(velicina: 14, boja: t.podnaslov, tezina: FontWeight.w600).copyWith(letterSpacing: 4),
        ),
      ],
    );
  }
}

/// Kružni tajmer sa preostalim sekundama.
class TajmerTeme extends StatelessWidget {
  const TajmerTeme({super.key, required this.deo, required this.sekunde});
  final double deo;
  final int sekunde;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _Krug(t, deo.clamp(0, 1)),
        child: Center(
          child: Text('$sekunde', style: t.naslov(velicina: 16, tezina: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _Krug extends CustomPainter {
  _Krug(this.t, this.deo);
  final KvizTema t;
  final double deo;

  @override
  void paint(Canvas c, Size v) {
    final kv = t.zaobljenje == 0;
    final r = Offset.zero & v;
    if (kv) {
      c.drawRect(r, Paint()..color = t.povrsina);
      c.drawRect(Rect.fromLTWH(0, v.height * (1 - deo), v.width, v.height * deo), Paint()..color = t.traka.first);
      c.drawRect(
        r.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = t.ivica ?? t.tekst,
      );
      return;
    }
    c.drawCircle(r.center, v.width / 2, Paint()..color = t.tajmerPozadina);
    final luk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawArc(r.deflate(3), 0, 2 * pi, false, luk..color = t.povrsina);
    luk.shader = SweepGradient(colors: t.traka, transform: const GradientRotation(-pi / 2)).createShader(r);
    c.drawArc(r.deflate(3), -pi / 2, 2 * pi * deo, false, luk);
  }

  @override
  bool shouldRepaint(_Krug o) => o.deo != deo || o.t != t;
}

/// Traka preostalog vremena.
class TrakaTeme extends StatelessWidget {
  const TrakaTeme({super.key, required this.deo});
  final double deo;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final r = BorderRadius.circular(min(t.zaobljenje, 8));
    return Container(
      height: 8,
      decoration: BoxDecoration(color: t.povrsina, borderRadius: r),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: deo.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: t.traka),
            borderRadius: r,
          ),
        ),
      ),
    );
  }
}

/// Slovo odgovora (A, B, C, D).
class SlovoTeme extends StatelessWidget {
  const SlovoTeme(this.slovo, {super.key, this.boja, this.tekst});
  final String slovo;
  final Color? boja;
  final Color? tekst;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    final providno = t.slovoPozadina.a == 0;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: boja ?? t.slovoPozadina,
        borderRadius: BorderRadius.circular(min(t.slovoZaobljenje, 14)),
        border: providno && boja == null ? Border.all(color: t.slovoTekst, width: 1.5) : null,
      ),
      child: Text(
        slovo,
        style: t.naslov(velicina: 13, boja: tekst ?? t.slovoTekst, tezina: FontWeight.w800),
      ),
    );
  }
}

/// Red u tabeli igrača.
class RedTeme extends StatelessWidget {
  const RedTeme({super.key, required this.child, this.ja = false});
  final Widget child;
  final bool ja;

  @override
  Widget build(BuildContext context) {
    final t = temaOd(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.povrsina2,
        borderRadius: BorderRadius.circular(max(0, t.zaobljenje - 4)),
        border: ja
            ? Border.all(color: t.istaknut, width: 2)
            : (t.ivica != null && t.debljinaIvice >= 1.5 ? Border.all(color: t.ivica!, width: 1) : null),
      ),
      child: DefaultTextStyle.merge(
        style: t.tekstStil(velicina: 14, tezina: FontWeight.w600),
        child: child,
      ),
    );
  }
}
