import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase projekat za push (FCM). Ovo nisu tajne: isti podaci su u svakoj aplikaciji.
/// Dok su prazni, push je isključen i rade samo lokalni podsetnici.
class PushOpcije {
  static const _projekat = 'kviz-push';
  static const _posiljalac = '259335491883';
  static const _androidKljuc = 'AIzaSyBqqECKBT2XIqgEZDvRW8AETTidhtwb4fY';
  static const _androidApp = '1:259335491883:android:a0b86992317f79f27cb56e';
  static const _iosKljuc = 'AIzaSyBKhndKkh_4eJOyz_Jk4V4HJQEcjY2lpKo';
  static const _iosApp = '1:259335491883:ios:68f7f1501d42a5527cb56e';

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
