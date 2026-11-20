// Prijava preko Google ili Apple naloga (opciona): daje ID token koji server proverava.
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'prijava_opcije.dart';

class Odustao implements Exception {}

class Prijava {
  Prijava._();

  static bool get google =>
      googleWebClientId.isNotEmpty && (Platform.isAndroid || (Platform.isIOS && googleIosClientId.isNotEmpty));

  /// Apple prijava postoji samo na iPhone-u.
  static Future<bool> apple() async {
    if (!Platform.isIOS) return false;
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Bar jedan način prijave je dostupan na ovom telefonu.
  static Future<bool> dostupna() async => google || await apple();

  static Future<void>? _init;

  /// ID token od Google-a; baca [Odustao] ako je korisnik zatvorio prozor.
  static Future<String> googleToken() async {
    _init ??= GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? googleIosClientId : null,
      serverClientId: googleWebClientId,
    );
    await _init;
    try {
      final nalog = await GoogleSignIn.instance.authenticate();
      final token = nalog.authentication.idToken;
      if (token == null) throw Exception('Google nije dao potvrdu prijave.');
      return token;
    } on GoogleSignInException catch (e) {
      final opis = e.description ?? '';
      // Android javlja i pogrešno podešen nalog (npr. "[16] Account reauth failed") kao "canceled",
      // pa tiho odustajemo samo kad nema opisa greške.
      if ((e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) &&
          (opis.isEmpty || opis.toLowerCase().contains('cancel'))) {
        throw Odustao();
      }
      throw Exception('Google prijava nije uspela (${e.code.name}${opis.isEmpty ? '' : ': $opis'}).');
    }
  }

  /// ID token od Apple-a; baca [Odustao] ako je korisnik odustao.
  static Future<String> appleToken() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(scopes: const []);
      final token = c.identityToken;
      if (token == null) throw Exception('Apple nije dao potvrdu prijave.');
      return token;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw Odustao();
      throw Exception('Apple prijava nije uspela.');
    }
  }

  /// Odjava iz Google-a u aplikaciji (da sledeći put ponudi izbor naloga).
  static Future<void> odjaviGoogle() async {
    if (_init == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
