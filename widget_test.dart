import 'package:flutter_test/flutter_test.dart';
import 'package:barbut/game.dart';

void main() {
  test('kazandıran atışlar', () {
    for (final p in [[6, 6], [5, 5], [3, 3], [6, 5], [5, 6]]) {
      expect(judge(p[0], p[1]), Outcome.win);
    }
  });
  test('kaybettiren atışlar', () {
    for (final p in [[1, 1], [2, 2], [4, 4], [1, 2], [2, 1]]) {
      expect(judge(p[0], p[1]), Outcome.lose);
    }
  });
  test('sonuçsuz atışlar', () {
    for (final p in [[6, 1], [3, 4], [5, 2], [6, 4]]) {
      expect(judge(p[0], p[1]), Outcome.pass);
    }
  });
  test('akçe el değiştirir, zar rakibe geçer', () {
    final g = Game();
    g.apply(const Roll(6, 6, 0, Outcome.win, 10));
    expect(g.akce, [110, 90]);
    expect(g.turn, 1);
  });
}
