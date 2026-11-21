import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zvuci i vibracija u igri; oba mogu da se isključe u Podešavanjima.
class Zvuk {
  Zvuk._();
  static final Zvuk i = Zvuk._();

  bool zvuk = true;
  bool vibracija = true;

  /// Otkucavanje sata dok teče vreme za pitanje (posebno od ostalih zvukova).
  bool sat = true;
  final _plejeri = <String, AudioPlayer>{};

  Future<void> ucitaj() async {
    final p = await SharedPreferences.getInstance();
    zvuk = p.getBool('zvuk') ?? true;
    vibracija = p.getBool('vibracija') ?? true;
    sat = p.getBool('sat') ?? true;
  }

  Future<void> postavi({bool? zvuk, bool? vibracija, bool? sat}) async {
    final p = await SharedPreferences.getInstance();
    if (sat != null) await p.setBool('sat', this.sat = sat);
    if (zvuk != null) await p.setBool('zvuk', this.zvuk = zvuk);
    if (vibracija != null) await p.setBool('vibracija', this.vibracija = vibracija);
  }

  Future<void> _pusti(String ime) async {
    if (!zvuk) return;
    try {
      final pl = _plejeri.putIfAbsent(ime, () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
      await pl.stop();
      await pl.play(AssetSource('zvuci/$ime.wav'));
    } catch (_) {
      // Zvuk nije presudan.
    }
  }

  void tacno() {
    _pusti('tacno');
    if (vibracija) HapticFeedback.lightImpact();
  }

  void netacno() {
    _pusti('netacno');
    if (vibracija) HapticFeedback.heavyImpact();
  }

  /// Otkucaj sata. [nivo] -1 je dublji „tak”, 0 običan „tik”, a 1–10 sve
  /// viši i glasniji tik za poslednjih 10 sekundi. Vibrira samo pred sam kraj.
  void otkucaj(int nivo) {
    if (!sat) return;
    _pusti(nivo < 0 ? 'sat_tak' : 'sat_${nivo.clamp(0, 10)}');
    if (vibracija && nivo >= 6) HapticFeedback.selectionClick();
  }

  void klik() {
    _pusti('klik');
    if (vibracija) HapticFeedback.selectionClick();
  }

  void kraj() => _pusti('kraj');
}
