import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase projekat za push (FCM). Ovo nisu tajne: isti podaci su u svakoj aplikaciji.
/// Dok su prazni, push je isključen i rade samo lokalni podsetnici.
class PushOpcije {
  static const _projekat = '';
  static const _posiljalac = '';
  static const _androidKljuc = '';
  static const _androidApp = '';
  static const _iosKljuc = '';
  static const _iosApp = '';

  static FirebaseOptions? get trenutne {
    if (_projekat.isEmpty) return null;
    if (defaultTargetPlatform == TargetPlatform.android && _androidApp.isNotEmpty) {
      return const FirebaseOptions(
        apiKey: _androidKljuc,
        appId: _androidApp,
        messagingSenderId: _posiljalac,
        projectId: _projekat,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && _iosApp.isNotEmpty) {
      return const FirebaseOptions(
        apiKey: _iosKljuc,
        appId: _iosApp,
        messagingSenderId: _posiljalac,
        projectId: _projekat,
        iosBundleId: 'rs.kviz.app',
      );
    }
    return null;
  }
}
