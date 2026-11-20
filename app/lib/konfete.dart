import 'dart:math';

import 'package:flutter/material.dart';

/// Konfete koje padaju preko ekrana, jednom, oko 4 sekunde.
class Konfete extends StatefulWidget {
  const Konfete({super.key, this.boje = const [], this.komada = 140});
  final List<Color> boje;
  final int komada;
  @override
  State<Konfete> createState() => _KonfeteState();
}

class _KonfeteState extends State<Konfete> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
    ..forward();
  late final List<_Komad> _komadi = () {
    final r = Random();
    final boje = widget.boje.isNotEmpty
        ? widget.boje
        : const [Color(0xFFFFC107), Color(0xFFE91E63), Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF5722)];
    return List.generate(
      widget.komada,
      (_) => _Komad(
        x: r.nextDouble(),
        kasni: r.nextDouble() * .35,
        brzina: .7 + r.nextDouble() * .6,
        njihanje: r.nextDouble() * 2 * pi,
        okret: (r.nextDouble() - .5) * 14,
        boja: boje[r.nextInt(boje.length)],
        sirina: 6 + r.nextDouble() * 6,
      ),
    );
  }();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _a,
      builder: (context, _) => CustomPaint(painter: _Slikar(_komadi, _a.value), size: Size.infinite),
    ),
  );
}

class _Komad {
  _Komad({
    required this.x,
    required this.kasni,
    required this.brzina,
    required this.njihanje,
    required this.okret,
    required this.boja,
    required this.sirina,
  });
  final double x, kasni, brzina, njihanje, okret, sirina;
  final Color boja;
}

class _Slikar extends CustomPainter {
  _Slikar(this.komadi, this.t);
  final List<_Komad> komadi;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final boja = Paint();
    for (final k in komadi) {
      final v = ((t - k.kasni) / (1 - k.kasni)).clamp(0.0, 1.0);
      if (v <= 0) continue;
      final y = -20 + v * k.brzina * (size.height + 60);
      final x = k.x * size.width + sin(v * 9 + k.njihanje) * 24;
      boja.color = k.boja.withValues(alpha: v > .85 ? (1 - v) / .15 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(v * k.okret);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: k.sirina, height: k.sirina * .55), boja);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Slikar old) => old.t != t;
}
