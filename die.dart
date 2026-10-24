import 'dart:math';

import 'package:flutter/material.dart';

import 'palette.dart';

const _pips = {
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

/// Kemik renkli zar yüzü; 1 ve 4 noktaları kırmızı.
class DieFace extends StatelessWidget {
  const DieFace({super.key, required this.value, required this.size, this.shadow = true});
  final int value;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _DiePainter(value, shadow),
      );
}

class _DiePainter extends CustomPainter {
  _DiePainter(this.value, this.shadow);
  final int value;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.18));
    if (shadow) {
      canvas.drawRRect(
        rr.shift(Offset(0, w * 0.08)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
      );
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [Palette.boneLight, Palette.bone, Palette.boneShade],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1F000000),
    );
    final red = value == 1 || value == 4;
    final r = w * (value == 1 ? 0.11 : 0.082);
    const f = [0.26, 0.5, 0.74];
    for (final i in _pips[value] ?? const <int>[]) {
      final c = Offset(w * f[i % 3], w * f[i ~/ 3]);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.25, -0.3),
            colors: red
                ? const [Color(0xFFD8455A), Palette.pipRed]
                : const [Color(0xFF4A4036), Palette.pip],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter old) => old.value != value || old.shadow != shadow;
}

/// Atış animasyonu: kupada çalkalanma, savruluş, tepside sekmeler.
/// Zamanlama [Feel] ile birebir aynı (çarpmalar 220/460/660/800/900 ms).
class TumblingDie extends StatefulWidget {
  const TumblingDie({
    super.key,
    required this.value,
    required this.rollId,
    required this.withCup,
    required this.side,
    required this.size,
  });

  final int value;
  final int rollId;
  final bool withCup;
  final double side; // +1 sol zar, -1 sağ zar
  final double size;

  @override
  State<TumblingDie> createState() => _TumblingDieState();
}

class _TumblingDieState extends State<TumblingDie> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1620));

  @override
  void didUpdateWidget(covariant TumblingDie old) {
    super.didUpdateWidget(old);
    if (widget.rollId != old.rollId) {
      final reduce = MediaQuery.of(context).disableAnimations;
      _c.duration = Duration(milliseconds: reduce ? 300 : (widget.withCup ? 1620 : 980));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _flicker(double ms) =>
      (((ms ~/ 70) * 7 + (widget.side > 0 ? 3 : 5) + widget.rollId) % 6) + 1;

  static double _bounceY(double t) {
    const hits = [220.0, 460.0, 660.0, 800.0, 900.0];
    const heights = [30.0, 12.0, 5.0, 2.0];
    if (t < hits[0]) {
      final p = t / hits[0];
      return -70 * (1 - p) - 160 * p * (1 - p);
    }
    for (var k = 0; k < hits.length - 1; k++) {
      if (t < hits[k + 1]) {
        final p = (t - hits[k]) / (hits[k + 1] - hits[k]);
        return -4 * heights[k] * p * (1 - p);
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (!_c.isAnimating) return DieFace(value: widget.value, size: widget.size);
        final total = _c.duration!.inMilliseconds.toDouble();
        final ms = _c.value * total;
        final cup = widget.withCup && total > 900 ? 640.0 : 0.0;
        final sx = widget.side * 52;
        double x, y, scale, spin, tiltX = 0, tiltY = 0;
        int face;
        if (ms < cup) {
          x = sx + sin(ms * 0.09 + widget.side) * 6;
          y = -70 + cos(ms * 0.11) * 6;
          scale = 0.8;
          spin = sin(ms * 0.05) * 0.15;
          face = _flicker(ms);
        } else {
          final u = ((ms - cup) / (total - cup)).clamp(0.0, 1.0);
          final settle = Curves.easeOutCubic.transform(u);
          x = sx * (1 - settle);
          y = _bounceY(u * 980);
          scale = 1 + 0.12 * (-y / 110).clamp(0.0, 1.0);
          spin = widget.side * 4 * pi * (1 - settle);
          tiltX = sin(u * 20) * (1 - settle) * 0.9;
          tiltY = cos(u * 17) * (1 - settle) * 0.9;
          face = u < 0.82 ? _flicker(ms) : widget.value;
        }
        return Transform.translate(
          offset: Offset(x, y),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateZ(spin)
              ..rotateX(tiltX)
              ..rotateY(tiltY),
            child: Transform.scale(
              scale: scale,
              child: DieFace(value: face, size: widget.size),
            ),
          ),
        );
      },
    );
  }
}

/// Kurallar tablosu: hangi çiftler kazandırır, hangileri kaybettirir.
class RulesLegend extends StatelessWidget {
  const RulesLegend({super.key});

  Widget _pair(int a, int b) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0x24D4B158),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          DieFace(value: a, size: 26, shadow: false),
          const SizedBox(width: 4),
          DieFace(value: b, size: 26, shadow: false),
        ]),
      );

  Widget _group(String title, Color color, List<List<int>> pairs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [for (final p in pairs) _pair(p[0], p[1])]),
        ],
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _group('Atana kazandırır', Palette.win, const [[6, 6], [5, 5], [3, 3], [6, 5]]),
          const SizedBox(height: 18),
          _group('Atana kaybettirir', Palette.lose, const [[1, 1], [2, 2], [4, 4], [1, 2]]),
          const SizedBox(height: 14),
          const Text(
            'Her oyuncu 100 akçeyle başlar, her karar 10 akçedir. Diğer atışlar sonuçsuzdur. '
            'Zar her atıştan sonra rakibe geçer. Akçesi biten masadan kalkar.',
            style: TextStyle(color: Palette.muted, height: 1.45),
          ),
        ],
      );
}
