import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// "#RRGGBB" ili "#RRGGBBAA" u boju.
Color boja(Object? x, [Color podrazumevana = const Color(0x00000000)]) {
  if (x is! String || !x.startsWith('#')) return podrazumevana;
  final h = x.substring(1);
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h.substring(6) + h.substring(0, 6), radix: 16));
  return podrazumevana;
}

List<Color> boje(Object? x) => x is List ? [for (final b in x) boja(b)] : const [];

double broj(Object? x, [double p = 0]) => x is num ? x.toDouble() : p;

List<BoxShadow> senke(Object? x) => x is List
    ? [
        for (final s in x.cast<Map>())
          BoxShadow(offset: Offset(broj(s['x']), broj(s['y'])), blurRadius: broj(s['blur']), color: boja(s['boja'])),
      ]
    : const [];

List<Shadow> tekstSenke(Object? x) => x is List
    ? [
        for (final s in x.cast<Map>())
          Shadow(offset: Offset(broj(s['x']), broj(s['y'])), blurRadius: broj(s['blur']), color: boja(s['boja'])),
      ]
    : const [];

FontWeight tezina(num t) => FontWeight.values[((t / 100).round() - 1).clamp(0, 8)];

/// Jedna tema izgleda, onako kako je opisana na serveru (server/src/teme.ts).
class KvizTema {
  KvizTema(this.json)
    : id = json['id'] as String,
      naziv = json['naziv'] as String? ?? json['id'] as String,
      verzija = json['verzija'] as String? ?? '',
      svetla = json['svetla'] == true {
    final b = (json['boje'] as Map?) ?? const {};
    tekst = boja(b['tekst'], svetla ? Colors.black : Colors.white);
    povrsina = boja(b['povrsina']);
    povrsina2 = boja(b['povrsina2'], povrsina);
    naPovrsini = boja(b['naPovrsini'], tekst);
    primarna = boja(b['primarna'], Colors.amber);
    naPrimarnoj = boja(b['naPrimarnoj'], Colors.black);
    tacno = boja(b['tacno'], Colors.green);
    netacno = boja(b['netacno'], Colors.red);
    logoBoja = boja(b['logo'], tekst);
    podnaslov = boja(b['podnaslov'], tekst.withValues(alpha: .8));
    slovoPozadina = boja(b['slovoPozadina'], primarna);
    slovoTekst = boja(b['slovoTekst'], naPrimarnoj);
    tajmerPozadina = boja(b['tajmerPozadina'], pozadinaBoja);
    ivica = b['ivica'] == null ? null : boja(b['ivica']);
    ivicaPrimarna = b['ivicaPrimarna'] == null ? null : boja(b['ivicaPrimarna']);
    istaknut = boja(b['istaknut'], primarna);

    final f = (json['font'] as Map?) ?? const {};
    fontNaslov = f['naslov'] as String? ?? 'Nunito Sans';
    fontTekst = f['tekst'] as String? ?? 'Nunito Sans';
    naslovTezina = tezina(broj(f['naslovTezina'], 800));
    skala = broj(f['skala'], 1);

    final d = (json['dugme'] as Map?) ?? const {};
    zaobljenje = broj(d['zaobljenje'], 14);
    debljinaIvice = broj(d['ivica']);
    isprekidana = d['isprekidana'] == true;
    senka = senke(d['senka']);
    senkaPrimarna = senke(d['senkaPrimarna']);
    slovoZaobljenje = broj(d['slovoZaobljenje'], 8);

    traka = boje(json['traka']);
    if (traka.isEmpty) traka = [primarna, primarna];
    if (traka.length == 1) traka = [traka.first, traka.first];
    mreza = json['odgovori'] == 'mreza';
    bojeOdgovora = boje(json['bojeOdgovora']);
    if (bojeOdgovora.length < 4) mreza = false;
    ukrasi = ((json['ukrasi'] as List?) ?? const []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
    uzorak = boje(json['uzorak']);
    if (uzorak.isEmpty) uzorak = [pozadinaBoja, primarna, tekst];
  }

  factory KvizTema.izJsona(Map<String, dynamic> j) => KvizTema(j);

  final Map<String, dynamic> json;
  final String id;
  final String naziv;
  final String verzija;
  final bool svetla;

  late final Color tekst, povrsina, povrsina2, naPovrsini, primarna, naPrimarnoj, tacno, netacno;
  late final Color logoBoja, podnaslov, slovoPozadina, slovoTekst, tajmerPozadina, istaknut;
  late final Color? ivica, ivicaPrimarna;
  late final String fontNaslov, fontTekst;
  late final FontWeight naslovTezina;
  late final double skala;
  late final double zaobljenje, debljinaIvice, slovoZaobljenje;
  late final bool isprekidana;
  late final List<BoxShadow> senka, senkaPrimarna;
  late List<Color> traka;
  late bool mreza;
  late final List<Color> bojeOdgovora;
  late final List<Map<String, dynamic>> ukrasi;
  late List<Color> uzorak;

  Map get _logo => (json['logo'] as Map?) ?? const {};
  String get logoTekst => _logo['tekst'] as String? ?? 'Kviz';
  double get logoVelicina => broj(_logo['velicina'], 56);
  double get logoRazmak => broj(_logo['razmak']);
  bool get logoKurziv => _logo['kurziv'] == true;
  List<Shadow> get logoSenke => tekstSenke(_logo['senke']);
  List<Color> get logoGradijent => boje(_logo['gradijent']);

  Map get _poz => (json['pozadina'] as Map?) ?? const {};
  Color get pozadinaBoja => boja(_poz['boja'], svetla ? Colors.white : const Color(0xFF0F1E6E));
  List<Map> get slojevi => ((_poz['slojevi'] as List?) ?? const []).cast<Map>();

  /// Neprovidna boja za dijaloge i donje panele.
  Color get panel => Color.alphaBlend(povrsina2.withValues(alpha: povrsina2.a * .6), pozadinaBoja);

  /// Prostor koji ukrasi zauzimaju na ivicama ekrana (ram, šara ćilima).
  EdgeInsets get okvir {
    var o = EdgeInsets.zero;
    for (final u in ukrasi) {
      if (u['tip'] == 'cilim') o += EdgeInsets.symmetric(vertical: broj(u['visina'], 34));
      if (u['tip'] == 'ram') o += EdgeInsets.all(broj(u['debljina'], 10) + 2);
    }
    return o;
  }

  TextStyle naslov({double velicina = 20, Color? boja, FontWeight? tezina, List<Shadow>? senke}) =>
      _font(fontNaslov, velicina * skala, tezina ?? naslovTezina, boja ?? tekst, senke);

  TextStyle tekstStil({double velicina = 15, Color? boja, FontWeight tezina = FontWeight.w700}) =>
      _font(fontTekst, velicina * skala, tezina, boja ?? tekst, null);

  static TextStyle _font(String ime, double v, FontWeight t, Color b, List<Shadow>? s) {
    try {
      return GoogleFonts.getFont(ime, fontSize: v, fontWeight: t, color: b, shadows: s);
    } catch (_) {
      // Nepoznat font: ostaje sistemski.
      return TextStyle(fontSize: v, fontWeight: t, color: b, shadows: s);
    }
  }

  TextTheme _textTema(TextTheme osnova) {
    TextStyle? f(String ime, TextStyle? st) {
      if (st == null) return null;
      try {
        final g = GoogleFonts.getFont(ime, fontWeight: st.fontWeight ?? FontWeight.w400);
        return st.copyWith(fontFamily: g.fontFamily, fontFamilyFallback: g.fontFamilyFallback);
      } catch (_) {
        return st;
      }
    }

    final o = osnova;
    return TextTheme(
      displayLarge: f(fontNaslov, o.displayLarge),
      displayMedium: f(fontNaslov, o.displayMedium),
      displaySmall: f(fontNaslov, o.displaySmall),
      headlineLarge: f(fontNaslov, o.headlineLarge),
      headlineMedium: f(fontNaslov, o.headlineMedium),
      headlineSmall: f(fontNaslov, o.headlineSmall),
      titleLarge: f(fontNaslov, o.titleLarge),
      titleMedium: f(fontTekst, o.titleMedium),
      titleSmall: f(fontTekst, o.titleSmall),
      bodyLarge: f(fontTekst, o.bodyLarge),
      bodyMedium: f(fontTekst, o.bodyMedium),
      bodySmall: f(fontTekst, o.bodySmall),
      labelLarge: f(fontTekst, o.labelLarge),
      labelMedium: f(fontTekst, o.labelMedium),
      labelSmall: f(fontTekst, o.labelSmall),
    ).apply(bodyColor: tekst, displayColor: tekst, fontSizeFactor: skala);
  }

  ThemeData themeData() {
    final osvetljenost = svetla ? Brightness.light : Brightness.dark;
    final sema = ColorScheme.fromSeed(
      seedColor: primarna,
      brightness: osvetljenost,
      primary: primarna,
      onPrimary: naPrimarnoj,
      surface: panel,
      onSurface: tekst,
    );
    final osnova = ThemeData(useMaterial3: true, brightness: osvetljenost, colorScheme: sema);
    final oblik = RoundedRectangleBorder(borderRadius: BorderRadius.circular(zaobljenje));
    return osnova.copyWith(
      scaffoldBackgroundColor: pozadinaBoja,
      textTheme: _textTema(osnova.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tekst,
        titleTextStyle: naslov(velicina: 18, tezina: FontWeight.w700),
        systemOverlayStyle: svetla ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      dialogTheme: DialogThemeData(backgroundColor: panel, shape: oblik),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: panel, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primarna,
        contentTextStyle: tekstStil(boja: naPrimarnoj, tezina: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(textColor: tekst, iconColor: tekst, selectedColor: istaknut),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primarna,
          foregroundColor: naPrimarnoj,
          minimumSize: const Size.fromHeight(52),
          textStyle: tekstStil(velicina: 17, boja: naPrimarnoj),
          shape: oblik,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tekst,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: ivica ?? tekst.withValues(alpha: .4), width: debljinaIvice.clamp(1, 3)),
          textStyle: tekstStil(velicina: 15),
          shape: oblik,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: svetla ? primarna : tekst)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primarna),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: povrsina2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(zaobljenje)),
      ),
    );
  }
}
