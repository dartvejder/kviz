import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/pozivnica.dart';

void main() {
  test('kod iz linka pozivnice', () {
    expect(kodIzLinka(Uri.parse('https://kviz.dartchat.trade/i/k7qx2m')), 'K7QX2M');
    expect(kodIzLinka(Uri.parse('https://kviz.dartchat.trade/i/K7QX2M/')), 'K7QX2M');
    expect(kodIzLinka(Uri.parse('https://drugo.rs/i/K7QX2M')), isNull);
    expect(kodIzLinka(Uri.parse('https://kviz.dartchat.trade/i/IIIIII')), isNull);
  });
  test('link pozivnice', () => expect(linkPozivnice('K7QX2M'), 'https://kviz.dartchat.trade/i/K7QX2M'));
}
