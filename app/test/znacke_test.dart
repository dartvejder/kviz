import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/main.dart' show dana;
import 'package:kviz/znacke.dart';

void main() {
  test('poruka za tačne zaredom', () {
    expect(porukaZaredom(2), isNull);
    expect(porukaZaredom(3), '3 tačna zaredom');
    expect(porukaZaredom(4), isNull);
    expect(porukaZaredom(5), '5 tačnih zaredom!');
    expect(porukaZaredom(10), '10 tačnih zaredom!');
  });
  test('dani', () {
    expect(dana(1), '1 dan');
    expect(dana(3), '3 dana');
    expect(dana(11), '11 dana');
    expect(dana(21), '21 dan');
  });
}
