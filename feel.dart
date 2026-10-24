import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'game.dart';

typedef _IosHaptic = Future<void> Function();

/// Ses + titreşim. Tüm zamanlamalar ekrandaki zar animasyonuyla aynı.
///
/// Düğmeyle atış:   0 ms def + kupada çalkalama, 640 ms savruluş,
///                  860/1100/1300/1440/1540 ms tepsiye çarpmalar, 1720 ms sonuç.
/// Sallayarak atış: kupa kısmı atlanır (onu zaten elinde hissettin),
///                  savruluş 0 ms'de, sonuç 1080 ms'de.
class Feel {
  Feel._();
  static final Feel I = Feel._();

  static const cupMs = 640;
  static int revealAt(bool fromShake) => (fromShake ? 0 : cupMs) + 1080;

  bool soundOn = true;
  bool hapticsOn = true;

  final _rng = Random();
  final List<AudioPlayer> _ticks = List.generate(4, (_) => AudioPlayer());
  int _tickIndex = 0;
  final _cup = AudioPlayer();
  final _throw = AudioPlayer();
  final _result = AudioPlayer();
  final _final = AudioPlayer();
  final List<Timer> _timers = [];

  bool _canVibrate = false;
  bool _amplitude = false;

  Future<void> init() async {
    try {
      _canVibrate = (await Vibration.hasVibrator()) == true;
      _amplitude = (await Vibration.hasAmplitudeControl()) == true;
    } catch (_) {}
  }

  void cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _at(int ms, void Function() fn) =>
      _timers.add(Timer(Duration(milliseconds: ms), fn));

  Future<void> _play(AudioPlayer p, String asset,
      {double volume = 1, PlayerMode mode = PlayerMode.mediaPlayer}) async {
    if (!soundOn) return;
    try {
      await p.stop();
      await p.play(AssetSource(asset), volume: volume, mode: mode);
    } catch (_) {}
  }

  /// Tek bir titreşim darbesi. Android'de süre + güç (1-255),
  /// iPhone'da Taptic Engine darbesi.
  void _hit(int ms, int amplitude, _IosHaptic ios) {
    if (!hapticsOn) return;
    if (Platform.isIOS || !_canVibrate) {
      ios();
      return;
    }
    if (_amplitude) {
      Vibration.vibrate(duration: ms, amplitude: amplitude.clamp(1, 255));
    } else {
      Vibration.vibrate(duration: ms);
    }
  }

  /// Telefon sallanırken zarın kupada çarpması.
  void tick(double power) {
    final p = _ticks[_tickIndex++ % _ticks.length];
    _play(p, 'sounds/tick_${1 + _rng.nextInt(4)}.wav',
        volume: (0.45 + power / 40).clamp(0.4, 1.0), mode: PlayerMode.lowLatency);
    _hit(14, (70 + power * 5).round().clamp(60, 200), HapticFeedback.selectionClick);
  }

  void playThrow(Roll r, {required bool fromShake, required bool finalRoll}) {
    cancel();
    final t0 = fromShake ? 0 : cupMs;

    if (!fromShake) {
      _play(_cup, 'sounds/cup_${1 + _rng.nextInt(2)}.wav');
      _at(0, () => _hit(55, 255, HapticFeedback.heavyImpact));
      for (final t in const [90, 160, 215, 300, 355, 430, 490, 570, 625]) {
        _at(t, () => _hit(16, 110, HapticFeedback.selectionClick));
      }
    }

    _at(t0, () => _play(_throw, 'sounds/throw_${1 + _rng.nextInt(3)}.wav'));

    // tepsiye çarpmalar: [zaman, süre, güç]
    const bounces = [
      [220, 55, 255],
      [460, 34, 190],
      [660, 22, 140],
      [800, 13, 100],
      [900, 8, 70],
    ];
    for (var i = 0; i < bounces.length; i++) {
      final b = bounces[i];
      final _IosHaptic ios = i == 0
          ? HapticFeedback.heavyImpact
          : i < 3
              ? HapticFeedback.mediumImpact
              : HapticFeedback.lightImpact;
      _at(t0 + b[0], () => _hit(b[1], b[2], ios));
    }

    final tr = t0 + 1080;
    _at(tr, () {
      _play(_result, switch (r.out) {
        Outcome.win => 'sounds/win.wav',
        Outcome.lose => 'sounds/lose.wav',
        Outcome.pass => 'sounds/pass.wav',
      });
    });
    switch (r.out) {
      case Outcome.win: // üç kısa, sonuncusu dolgun
        _at(tr, () => _hit(28, 200, HapticFeedback.mediumImpact));
        _at(tr + 80, () => _hit(28, 200, HapticFeedback.mediumImpact));
        _at(tr + 170, () => _hit(90, 255, HapticFeedback.heavyImpact));
      case Outcome.lose: // uzun, ağır bir gong titreşimi
        _at(tr, () => _hit(240, 255, HapticFeedback.heavyImpact));
        _at(tr + 110, () { if (Platform.isIOS) HapticFeedback.heavyImpact(); });
        _at(tr + 230, () { if (Platform.isIOS) HapticFeedback.mediumImpact(); });
      case Outcome.pass:
        _at(tr, () => _hit(18, 90, HapticFeedback.lightImpact));
    }

    if (finalRoll) {
      _at(tr + 2400, () => _play(_final, 'sounds/final.wav'));
      for (final d in const [0, 90, 180, 270, 900]) {
        _at(tr + 2400 + d, () => _hit(d == 900 ? 200 : 25, 255, HapticFeedback.heavyImpact));
      }
    }
  }
}
