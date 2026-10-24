import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'die.dart';
import 'feel.dart';
import 'game.dart';
import 'palette.dart';
import 'shake.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final game = Game();
  List<int> dice = [6, 5];
  int rollId = 0;
  bool withCup = true;
  bool busy = false;
  bool shakeOn = false;
  bool verdictOn = false;
  Roll? shown;
  Timer? _reveal;

  late final ShakeDetector _shake = ShakeDetector(
    onRattle: (p) => Feel.I.tick(p),
    onRelease: () => _roll(fromShake: true),
  );

  @override
  void dispose() {
    _reveal?.cancel();
    _shake.stop();
    Feel.I.cancel();
    super.dispose();
  }

  void _syncShake() => _shake.enabled = shakeOn && !busy && !game.over;

  void _roll({required bool fromShake}) {
    if (busy || game.over) return;
    final r = game.draw();
    final ends = game.endsGame(r);
    setState(() {
      busy = true;
      rollId++;
      dice = [r.d1, r.d2];
      withCup = !fromShake;
      verdictOn = false;
    });
    _syncShake();
    Feel.I.playThrow(r, fromShake: fromShake, finalRoll: ends);
    _reveal?.cancel();
    _reveal = Timer(Duration(milliseconds: Feel.revealAt(fromShake)), () {
      if (!mounted) return;
      setState(() {
        game.apply(r);
        shown = r;
        busy = false;
        verdictOn = true;
      });
      _syncShake();
    });
  }

  void _rematch() {
    setState(() {
      game.reset();
      shown = null;
      verdictOn = false;
    });
    _syncShake();
  }

  void _toggleShake() {
    setState(() => shakeOn = !shakeOn);
    if (shakeOn) {
      _shake.start();
    } else {
      _shake.stop();
    }
    _syncShake();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _topBar(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _plaque(0)),
              const SizedBox(width: 10),
              Expanded(child: _plaque(1)),
            ]),
            const SizedBox(height: 16),
            _tray(context),
            const SizedBox(height: 20),
            _controls(),
            const SizedBox(height: 28),
            _title('Son atışlar'),
            ..._log(),
            const SizedBox(height: 28),
            _title('Atışlar'),
            const RulesLegend(),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(fontFamily: Palette.display, fontSize: 22, color: Palette.ink)),
      );

  Widget _topBar() => Row(children: [
        const Text('Barbut',
            style: TextStyle(
                fontFamily: Palette.display, fontSize: 28, color: Palette.gold, letterSpacing: 1)),
        const Spacer(),
        IconButton(
          tooltip: Feel.I.soundOn ? 'Sesi kapat' : 'Sesi aç',
          icon: Icon(Feel.I.soundOn ? Icons.volume_up : Icons.volume_off, color: Palette.ink),
          onPressed: () => setState(() => Feel.I.soundOn = !Feel.I.soundOn),
        ),
        IconButton(
          tooltip: Feel.I.hapticsOn ? 'Titreşimi kapat' : 'Titreşimi aç',
          icon: Icon(Feel.I.hapticsOn ? Icons.vibration : Icons.mobile_off, color: Palette.ink),
          onPressed: () => setState(() => Feel.I.hapticsOn = !Feel.I.hapticsOn),
        ),
      ]);

  Widget _plaque(int i) {
    final active = !game.over && game.turn == i;
    Color amountColor = Palette.ink;
    final s = shown;
    if (verdictOn && s != null && s.out != Outcome.pass) {
      final winnerSeat = s.out == Outcome.win ? s.by : 1 - s.by;
      amountColor = winnerSeat == i ? Palette.win : Palette.lose;
    }
    final tag = game.winner == i ? 'Masanın galibi' : (active ? 'Zar onda' : '');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? Palette.gold : Palette.line, width: active ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}. oyuncu',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${game.akce[i]}',
                style: TextStyle(fontFamily: Palette.display, fontSize: 28, color: amountColor)),
            const SizedBox(width: 6),
            const Text('akçe', style: TextStyle(color: Palette.muted, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(tag, style: const TextStyle(color: Palette.gold, fontSize: 13)),
      ]),
    );
  }

  Widget _tray(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dieSize = min(88.0, width * 0.2);
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: Palette.tray,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.trayEdge, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _GirihPainter())),
          Positioned.fill(
            bottom: 44,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TumblingDie(value: dice[0], rollId: rollId, withCup: withCup, side: 1, size: dieSize),
              const SizedBox(width: 48),
              TumblingDie(value: dice[1], rollId: rollId, withCup: withCup, side: -1, size: dieSize),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: AnimatedOpacity(
              opacity: verdictOn ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: _verdict(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _verdict() {
    final r = shown;
    if (r == null) return const SizedBox(height: 44);
    final who = '${r.by + 1}. oyuncu';
    final (String title, String sub, Color color) = switch (r.out) {
      Outcome.win => ('Barbut!', '$who ${r.amount} akçe kazandı', const Color(0xFF9FE0BE)),
      Outcome.lose => ('Kaybettiren atış', '$who ${r.amount} akçe kaybetti', const Color(0xFFF49AA8)),
      Outcome.pass => ('Sonuçsuz', 'Zar rakibe geçti', Palette.ink),
    };
    return Column(children: [
      Text(title, style: TextStyle(fontFamily: Palette.display, fontSize: 24, color: color)),
      Text(sub, style: const TextStyle(color: Color(0xBFE9E1CE), fontSize: 14)),
    ]);
  }

  Widget _controls() {
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: Palette.gold,
      foregroundColor: Palette.bg,
      disabledBackgroundColor: const Color(0x66D4B158),
      disabledForegroundColor: Palette.bg,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
    );
    const label = TextStyle(fontFamily: Palette.display, fontSize: 22);
    return Column(children: [
      if (!game.over)
        FilledButton(
          style: buttonStyle,
          onPressed: busy ? null : () => _roll(fromShake: false),
          child: Text('Zarı at (${game.turn + 1}. oyuncu)', style: label),
        )
      else ...[
        Text('${(game.winner ?? 0) + 1}. oyuncu masayı kazandı.',
            style: const TextStyle(color: Palette.ink, fontSize: 16)),
        const SizedBox(height: 10),
        FilledButton(
          style: buttonStyle,
          onPressed: _rematch,
          child: const Text('Yeniden oyna', style: label),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _toggleShake,
        style: OutlinedButton.styleFrom(
          foregroundColor: shakeOn ? Palette.gold : Palette.ink,
          side: BorderSide(color: shakeOn ? Palette.gold : Palette.line),
        ),
        icon: Icon(shakeOn ? Icons.vibration : Icons.back_hand_outlined),
        label: Text(shakeOn ? 'Sallama açık: salla, sonra dur' : 'Telefonu sallayarak at'),
      ),
    ]);
  }

  List<Widget> _log() {
    if (game.log.isEmpty) {
      return const [Text('Henüz zar atılmadı.', style: TextStyle(color: Palette.muted))];
    }
    return [
      for (final r in game.log)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.line))),
          child: Row(children: [
            DieFace(value: r.d1, size: 22, shadow: false),
            const SizedBox(width: 4),
            DieFace(value: r.d2, size: 22, shadow: false),
            const SizedBox(width: 12),
            Expanded(child: Text('${r.by + 1}. oyuncu', style: const TextStyle(color: Palette.ink))),
            Text(
              switch (r.out) {
                Outcome.win => '+${r.amount}',
                Outcome.lose => '−${r.amount}',
                Outcome.pass => 'sonuçsuz',
              },
              style: TextStyle(
                color: switch (r.out) {
                  Outcome.win => Palette.win,
                  Outcome.lose => Palette.lose,
                  Outcome.pass => Palette.muted,
                },
              ),
            ),
          ]),
        ),
    ];
  }
}

/// Tepsi zemininde silik sekiz köşeli yıldız (girih) deseni.
class _GirihPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x26B8933A);
    const step = 64.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final c = Offset(x + 32, y + 32);
        canvas.drawRect(Rect.fromCenter(center: c, width: 30, height: 30), p);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 30, height: 30), p);
        canvas.restore();
        final path = Path();
        for (var k = 0; k < 16; k++) {
          final a = k * pi / 8 - pi / 2;
          final r = k.isEven ? 26.0 : 11.0;
          final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
          if (k == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
