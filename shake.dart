import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Telefonu kupa gibi sallamayı algılar. Sallarken [onRattle],
/// sallama bitince (kısa bir duraksama) [onRelease] çağrılır: zar atılır.
class ShakeDetector {
  ShakeDetector({required this.onRattle, required this.onRelease, this.threshold = 12});

  final void Function(double power) onRattle;
  final void Function() onRelease;
  final double threshold; // m/s², yerçekimi hariç

  bool enabled = true;
  StreamSubscription<UserAccelerometerEvent>? _sub;
  bool _shaking = false;
  DateTime _start = DateTime(0), _last = DateTime(0), _lastTick = DateTime(0);

  void start() {
    _sub ??= userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_onEvent, onError: (Object _) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _shaking = false;
  }

  void _onEvent(UserAccelerometerEvent e) {
    if (!enabled) {
      _shaking = false;
      return;
    }
    final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (m > threshold) {
      if (!_shaking) {
        _shaking = true;
        _start = now;
      }
      _last = now;
      if (now.difference(_lastTick).inMilliseconds > 70) {
        _lastTick = now;
        onRattle(m);
      }
    } else if (_shaking && now.difference(_last).inMilliseconds > 320) {
      _shaking = false;
      if (_last.difference(_start).inMilliseconds > 250) onRelease();
    }
  }
}
