import 'package:flutter_test/flutter_test.dart';
import 'package:siber/core/moderation.dart';

void main() {
  test('küfürlü adlar yakalanır', () {
    for (final n in [
      'Orospu',
      'or0spu çocuğu',
      's.i.k.t.i.r',
      'YARRRAK',
      'amk',
      'Aq Oyuncu',
      'FUCKER',
      'b1tch',
      'İbne',
      'pussy cat',
      'sikim',
    ]) {
      expect(Moderation.isOffensive(n), isTrue, reason: n);
    }
  });
  test('masum adlar geçer', () {
    for (final n in [
      'Murat Baba',
      'Klasik',
      'Kayarak',
      'Sıkı Pilot',
      'Müzik',
      'Dgd',
      'Ahmet',
      'Pickle',
      'Ambulans',
      'Mustafa',
      'Gökhan',
      'Sikke',
    ]) {
      expect(Moderation.isOffensive(n), isFalse, reason: n);
    }
  });
}
