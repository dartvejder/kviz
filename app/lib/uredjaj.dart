// Podaci o uređaju koje Flutter ne daje sam.
import 'dart:io';

import 'package:flutter/services.dart';

const _kanal = MethodChannel('rs.kviz/uredjaj');

/// Da li aplikacija radi na Google-ovom test uređaju (Firebase Test Lab, pre-launch izveštaj).
/// Takav nalog server ne prikazuje na top listama.
Future<bool> testUredjaj() async {
  if (!Platform.isAndroid) return false;
  try {
    return await _kanal.invokeMethod<bool>('testLab') ?? false;
  } catch (_) {
    return false;
  }
}
