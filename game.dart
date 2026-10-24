import 'dart:math';

enum Outcome { win, lose, pass }

/// Bir zar atışı. [by] atan oyuncu (0 ya da 1), [amount] el değiştiren akçe.
class Roll {
  const Roll(this.d1, this.d2, this.by, this.out, this.amount);
  final int d1, d2, by, amount;
  final Outcome out;
}

const _winning = {'6-6', '5-5', '3-3', '6-5'};
const _losing = {'1-1', '2-2', '4-4', '2-1'};

Outcome judge(int a, int b) {
  final key = '${max(a, b)}-${min(a, b)}';
  if (_winning.contains(key)) return Outcome.win;
  if (_losing.contains(key)) return Outcome.lose;
  return Outcome.pass;
}

class Game {
  static const start = 100;
  static const stake = 10;

  final List<int> akce = [start, start];
  final List<Roll> log = [];
  int turn = 0;
  int? winner;
  final Random _rng = Random.secure();

  bool get over => winner != null;

  /// Zarı atar ama sonucu henüz uygulamaz: animasyon bitince [apply] çağrılır.
  Roll draw() {
    final d1 = _rng.nextInt(6) + 1, d2 = _rng.nextInt(6) + 1;
    final s = turn, o = 1 - turn, out = judge(d1, d2);
    final amount = switch (out) {
      Outcome.win => min(stake, akce[o]),
      Outcome.lose => min(stake, akce[s]),
      Outcome.pass => 0,
    };
    return Roll(d1, d2, s, out, amount);
  }

  bool endsGame(Roll r) {
    if (r.out == Outcome.pass) return false;
    final loser = r.out == Outcome.win ? 1 - r.by : r.by;
    return akce[loser] - r.amount <= 0;
  }

  void apply(Roll r) {
    final o = 1 - r.by;
    if (r.out == Outcome.win) {
      akce[o] -= r.amount;
      akce[r.by] += r.amount;
    } else if (r.out == Outcome.lose) {
      akce[r.by] -= r.amount;
      akce[o] += r.amount;
    }
    log.insert(0, r);
    if (log.length > 12) log.removeLast();
    turn = o; // zar her atıştan sonra rakibe geçer
    if (akce[0] <= 0) winner = 1;
    if (akce[1] <= 0) winner = 0;
  }

  void reset() {
    final w = winner;
    akce[0] = start;
    akce[1] = start;
    turn = w == null ? 0 : 1 - w; // kaybeden başlar
    winner = null;
    log.clear();
  }
}
