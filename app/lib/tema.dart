import 'package:flutter/material.dart';

const plava = Color(0xFF0F1E6E);
const plavaSvetla = Color(0xFF2C3F9F);
const zuta = Color(0xFFFFD34D);
const zelena = Color(0xFF2ECC71);
const crvena = Color(0xFFE74C3C);

ThemeData kvizTema() {
  final sema = ColorScheme.fromSeed(
    seedColor: zuta,
    brightness: Brightness.dark,
    primary: zuta,
    onPrimary: plava,
    surface: plava,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: sema,
    scaffoldBackgroundColor: plava,
    cardTheme: const CardThemeData(color: plavaSvetla),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

class VelikoDugme extends StatelessWidget {
  const VelikoDugme({super.key, required this.ikona, required this.tekst, this.onTap});
  final IconData ikona;
  final String tekst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.icon(onPressed: onTap, icon: Icon(ikona), label: Text(tekst)),
      );
}
