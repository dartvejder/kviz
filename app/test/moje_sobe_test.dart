import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/moje_sobe.dart';

void main() {
  test('Moje sobe: najnovija prva, bez duplikata i starijih od 24 h, najviše 8', () {
    final sad = DateTime(2026, 11, 20, 12);
    final sobe = srediSobe([
      MojaSoba('AAAAAA', sad.subtract(const Duration(hours: 2))),
      MojaSoba('BBBBBB', sad.subtract(const Duration(hours: 25))),
      MojaSoba('AAAAAA', sad.subtract(const Duration(minutes: 5))),
      MojaSoba('CCCCCC', sad.subtract(const Duration(hours: 1))),
      for (var i = 0; i < 10; i++) MojaSoba('D$i', sad.subtract(Duration(hours: 3, minutes: i))),
    ], sad);
    expect(sobe.first.kod, 'AAAAAA');
    expect(sobe.first.usao, sad.subtract(const Duration(minutes: 5)));
    expect(sobe.map((s) => s.kod), isNot(contains('BBBBBB')));
    expect(sobe.where((s) => s.kod == 'AAAAAA'), hasLength(1));
    expect(sobe, hasLength(8));
  });
}
