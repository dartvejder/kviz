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
  test('Dart Chat token iz fragmenta linka', () {
    final p = pozivnicaIzLinka(Uri.parse('https://kviz.dartchat.trade/i/k7qx2m#dc=abc.DEF-123'))!;
    expect(p.kod, 'K7QX2M');
    expect(p.dartChat, 'abc.DEF-123');
    expect(pozivnicaIzLinka(Uri.parse('https://kviz.dartchat.trade/i/K7QX2M'))!.dartChat, isNull);
    expect(dartChatIzLinka(Uri.parse('https://kviz.dartchat.trade/i/K7QX2M#dc=')), isNull);
    expect(dartChatIzLinka(Uri.parse('https://kviz.dartchat.trade/i/K7QX2M#nesto')), isNull);
    expect(pozivnicaIzLinka(Uri.parse('https://drugo.rs/i/K7QX2M#dc=x')), isNull);
    expect(dartChatIzLinka(Uri.parse('https://kviz.dartchat.trade/i/K7QX2M#a=1&dc=ab+c%2Fd')), 'ab+c/d');
  });
}
