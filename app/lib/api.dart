// Veza sa serverom: HTTP za nalog, sobe i top listu, WebSocket za igru.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'uredjaj.dart';

const server = String.fromEnvironment('KVIZ_SERVER', defaultValue: 'https://kviz.dartchat.trade');

const avatari = [
  '🦊',
  '🐼',
  '🐯',
  '🦁',
  '🐸',
  '🐵',
  '🐨',
  '🐙',
  '🦄',
  '🐲',
  '🦉',
  '🐧',
  '🐢',
  '🦖',
  '🐝',
  '🐬',
  '🦀',
  '🐺',
  '🐮',
  '🐷',
  '🦋',
  '🐞',
  '🐻',
  '🐰',
  '🦒',
];

class GreskaServera implements Exception {
  GreskaServera(this.poruka);
  final String poruka;
  @override
  String toString() => poruka;
}

class Nalog {
  Nalog({required this.id, required this.token, required this.ime, required this.avatar});
  final String id;
  final String token;
  String ime;
  String avatar;
  String get auth => 'Bearer $id.$token';
}

class Api {
  Api._();
  static final Api i = Api._();

  Nalog? nalog;

  Future<Nalog?> ucitajNalog() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('id'), token = p.getString('token');
    if (id == null || token == null) return null;
    nalog = Nalog(id: id, token: token, ime: p.getString('ime') ?? '', avatar: p.getString('avatar') ?? avatari.first);
    return nalog;
  }

  Future<void> _sacuvaj(Nalog n) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('id', n.id);
    await p.setString('token', n.token);
    await p.setString('ime', n.ime);
    await p.setString('avatar', n.avatar);
  }

  Map<String, dynamic> _json(http.Response r) {
    final telo = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw GreskaServera(telo is Map && telo['greska'] is String ? telo['greska'] : 'Greška ${r.statusCode}');
    }
    return telo is Map<String, dynamic> ? telo : {'lista': telo};
  }

  Map<String, String> get _zaglavlja => {
    'content-type': 'application/json',
    if (nalog != null) 'authorization': nalog!.auth,
  };

  /// Pravi nalog ili menja ime/avatar postojećeg.
  Future<Nalog> postaviIgraca(String ime, String avatar) async {
    if (nalog == null) {
      final robot = await testUredjaj();
      final r = _json(
        await http.post(
          Uri.parse('$server/api/igraci'),
          headers: _zaglavlja,
          body: jsonEncode({'ime': ime, 'avatar': avatar, if (robot) 'robot': true}),
        ),
      );
      nalog = Nalog(id: r['id'], token: r['token'], ime: r['ime'], avatar: r['avatar']);
    } else {
      final r = _json(
        await http.put(
          Uri.parse('$server/api/igraci/ja'),
          headers: _zaglavlja,
          body: jsonEncode({'ime': ime, 'avatar': avatar}),
        ),
      );
      nalog!
        ..ime = r['ime']
        ..avatar = r['avatar'];
    }
    await _sacuvaj(nalog!);
    return nalog!;
  }

  Future<void> obrisiNalog() async {
    _json(await http.delete(Uri.parse('$server/api/igraci/ja'), headers: _zaglavlja));
    final p = await SharedPreferences.getInstance();
    await p.clear();
    nalog = null;
  }

  /// Ime iz Dart Chata, kao predlog pre pravljenja naloga.
  Future<String?> dartChatIme(String dc) async {
    final r = _json(await http.get(Uri.parse('$server/api/dartchat/ja'), headers: {'authorization': 'DartChat $dc'}));
    return r['ime_predlog'] as String?;
  }

  /// Povezuje ovaj Kviz nalog sa Dart Chat nalogom (pozivar tako postaje moderator svoje sobe).
  Future<void> poveziDartChat(String dc) async {
    _json(
      await http.post(
        Uri.parse('$server/api/dartchat/povezi'),
        headers: _zaglavlja,
        body: jsonEncode({'openid_token': dc}),
      ),
    );
  }

  Future<String> novaSoba() async {
    final r = _json(await http.post(Uri.parse('$server/api/sobe'), headers: _zaglavlja));
    return r['kod'];
  }

  /// Pregled sobe za "Moje sobe"; null ako je soba istekla.
  Future<Map<String, dynamic>?> pregledSobe(String kod) async {
    final r = await http.get(Uri.parse('$server/api/sobe/$kod'), headers: _zaglavlja);
    if (r.statusCode == 404) return null;
    return _json(r);
  }

  Future<List<Map<String, dynamic>>> oblasti() async {
    final r = _json(await http.get(Uri.parse('$server/api/oblasti')));
    return (r['lista'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> top(String period, String poredak) async {
    final r = _json(await http.get(Uri.parse('$server/api/top?period=$period&poredak=$poredak')));
    return (r['lista'] as List).cast<Map<String, dynamic>>();
  }

  /// Novi pokušaj dnevnog izazova; vraća kod sobe. Ako je već odigran, baca GreskaServera.
  Future<String> izazov() async {
    final r = _json(await http.post(Uri.parse('$server/api/izazov'), headers: _zaglavlja));
    return r['kod'];
  }

  /// Današnja top lista izazova i moj rezultat ("ja", ili null ako nisam igrao).
  Future<Map<String, dynamic>> izazovTop() async =>
      _json(await http.get(Uri.parse('$server/api/izazov/top'), headers: _zaglavlja));

  Future<Map<String, dynamic>> statistika() async =>
      _json(await http.get(Uri.parse('$server/api/igraci/ja/statistika'), headers: _zaglavlja));

  /// Prijava lošeg pitanja: razlog je netacan, nejasno, zastarelo ili drugo.
  Future<void> prijaviPitanje(int id, String razlog, String napomena) async {
    _json(
      await http.post(
        Uri.parse('$server/api/pitanja/$id/prijava'),
        headers: _zaglavlja,
        body: jsonEncode({'razlog': razlog, 'napomena': napomena}),
      ),
    );
  }

  Soba udji(String kod) => Soba(kod, nalog!);
}

/// Jedna otvorena soba: šalje poruke i prima stanje.
class Soba {
  Soba(this.kod, this.ja, {bool povezi = true}) {
    if (povezi) _povezi();
  }

  final String kod;
  final Nalog ja;
  final _stanja = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _kanal;
  bool _zatvoreno = false;
  int _pokusaj = 0;
  Map<String, dynamic>? poslednje;

  /// Razlika sat servera − lokalni sat, da tajmer bude tačan.
  int pomakSata = 0;

  Stream<Map<String, dynamic>> get stanja => _stanja.stream;

  void _povezi() {
    final ws = server.replaceFirst('http', 'ws');
    final k = WebSocketChannel.connect(Uri.parse('$ws/ws/$kod?id=${ja.id}&token=${ja.token}'));
    _kanal = k;
    k.stream.listen(
      (poruka) {
        _pokusaj = 0;
        final m = jsonDecode(poruka as String) as Map<String, dynamic>;
        if (m['t'] == 'stanje') {
          pomakSata = (m['sad'] as int) - DateTime.now().millisecondsSinceEpoch;
          poslednje = m;
        }
        _stanja.add(m);
      },
      onDone: _ponovo,
      onError: (_) => _ponovo(),
    );
  }

  void _ponovo() {
    if (_zatvoreno) return;
    final kod = _kanal?.closeCode;
    if (kod == 4000 || kod == 4001) {
      _stanja.add({'t': 'zatvoreno', 'kod': kod});
      return;
    }
    _pokusaj++;
    Future.delayed(Duration(milliseconds: 500 * _pokusaj.clamp(1, 10)), () {
      if (!_zatvoreno) _povezi();
    });
  }

  void posalji(Map<String, dynamic> m) => _kanal?.sink.add(jsonEncode(m));

  void zatvori() {
    _zatvoreno = true;
    _kanal?.sink.close();
    _stanja.close();
  }
}
