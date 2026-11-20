import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/azuriranje.dart';

void main() {
  test('Ažuriranje se traži samo kad je build stariji od najmanjeg', () {
    final odgovor = {
      'android': {'min': 2030, 'prodavnica': 'https://play.google.com/store/apps/details?id=rs.kviz.app'},
      'ios': {'min': 0, 'prodavnica': 'https://testflight.apple.com/join/x'},
    };
    expect(adresaZaAzuriranje(odgovor, 'android', 2024), contains('play.google.com'));
    expect(adresaZaAzuriranje(odgovor, 'android', 2030), isNull);
    expect(adresaZaAzuriranje(odgovor, 'ios', 3), isNull);
    expect(adresaZaAzuriranje(odgovor, 'android', 0), isNull);
    expect(adresaZaAzuriranje({}, 'android', 5), isNull);
  });
}
