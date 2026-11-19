import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/ekrani/top.dart';

void main() {
  test('množina za partije', () {
    expect(partija(1), '1 partija');
    expect(partija(2), '2 partije');
    expect(partija(5), '5 partija');
    expect(partija(12), '12 partija');
    expect(partija(21), '21 partija');
    expect(partija(22), '22 partije');
  });
}
