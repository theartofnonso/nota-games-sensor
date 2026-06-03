import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'motion_payload.dart';
import 'motion_player_id_store.dart';
import 'motion_publisher.dart';

enum MotionTrackingStatus { idle, tracking, stopped }

/// Tuning knobs for NOTA motion scoring — adjust without touching UI.
///
/// Uses [userAccelerometerEventStream] (linear acceleration, gravity removed).
/// Values are in m/s²; magnitude ≈ 0 at rest.
const double kMotionSmoothingAlpha = 0.15;
const double kMotionScoreThreshold = 0.3;
const double kMotionScoreMultiplier = 0.4;
const Duration kMotionSampleInterval = Duration(milliseconds: 50);

class MotionTrackingController extends ChangeNotifier {
  MotionTrackingController();

  String? _playerId;
  MotionTrackingStatus _status = MotionTrackingStatus.idle;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  Timer? _sampleTimer;
  bool _hasPendingSample = false;
  double _pendingX = 0;
  double _pendingY = 0;
  double _pendingZ = 0;
  String? _sensorError;

  double _x = 0;
  double _y = 0;
  double _z = 0;
  double _magnitude = 0;
  double _smoothedMagnitude = 0;
  double _sessionScore = 0;
  bool _hasSmoothedSample = false;

  String get playerId => _playerId ?? '…';
  MotionTrackingStatus get status => _status;
  String? get sensorError => _sensorError;

  double get x => _x;
  double get y => _y;
  double get z => _z;
  double get magnitude => _magnitude;
  double get smoothedMagnitude => _smoothedMagnitude;
  double get sessionScore => _sessionScore;

  bool get isTracking => _status == MotionTrackingStatus.tracking;

  String get statusLabel => switch (_status) {
        MotionTrackingStatus.idle => 'Idle',
        MotionTrackingStatus.tracking => 'Tracking',
        MotionTrackingStatus.stopped => 'Stopped',
      };

  Future<void> initialize() async {
    _playerId = await MotionPlayerIdStore.loadOrCreate();
    notifyListeners();
  }

  Future<void> startTracking() async {
    if (_status == MotionTrackingStatus.tracking) return;
    _sensorError = null;

    try {
      await _tearDownSensor();

      _subscription = userAccelerometerEventStream().listen(
        (event) {
          _pendingX = event.x;
          _pendingY = event.y;
          _pendingZ = event.z;
          _hasPendingSample = true;
        },
        onError: (Object e) {
          _sensorError = 'Motion sensor unavailable: $e';
          stopTracking();
        },
      );

      _sampleTimer = Timer.periodic(kMotionSampleInterval, (_) => _onSampleTick());

      _status = MotionTrackingStatus.tracking;
      notifyListeners();
    } catch (e) {
      _sensorError = 'Could not start motion sensor: $e';
      await _tearDownSensor();
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    if (_status != MotionTrackingStatus.tracking) return;
    await _tearDownSensor();
    _status = MotionTrackingStatus.stopped;
    _publishCurrentSample(isTracking: false);
    notifyListeners();
  }

  /// Stops tracking (if active) and clears session metrics back to idle.
  Future<void> resetSession() async {
    if (_status == MotionTrackingStatus.tracking) {
      await _tearDownSensor();
    }
    _clearSessionMetrics();
    _status = MotionTrackingStatus.idle;
    _sensorError = null;
    final id = _playerId;
    if (id != null) {
      MotionPublisher.latestByPlayerId.remove(id);
    }
    notifyListeners();
  }

  void _clearSessionMetrics() {
    _x = 0;
    _y = 0;
    _z = 0;
    _magnitude = 0;
    _smoothedMagnitude = 0;
    _sessionScore = 0;
    _hasSmoothedSample = false;
    _hasPendingSample = false;
  }

  Future<void> _tearDownSensor() async {
    await _subscription?.cancel();
    _subscription = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _hasPendingSample = false;
  }

  void _onSampleTick() {
    if (!_hasPendingSample || _status != MotionTrackingStatus.tracking) return;

    _x = _pendingX;
    _y = _pendingY;
    _z = _pendingZ;
    _magnitude = _computeMagnitude(_x, _y, _z);

    if (!_hasSmoothedSample) {
      _smoothedMagnitude = _magnitude;
      _hasSmoothedSample = true;
    } else {
      _smoothedMagnitude = kMotionSmoothingAlpha * _magnitude +
          (1 - kMotionSmoothingAlpha) * _smoothedMagnitude;
    }

    if (_smoothedMagnitude > kMotionScoreThreshold) {
      _sessionScore +=
          (_smoothedMagnitude - kMotionScoreThreshold) * kMotionScoreMultiplier;
    }

    _publishCurrentSample(isTracking: true);
    notifyListeners();
  }

  static double _computeMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  void _publishCurrentSample({required bool isTracking}) {
    final id = _playerId;
    if (id == null) return;

    // Real-time backend hook — dashboard subscribers listen on the same channel.
    MotionPublisher.publishMotionData(
      MotionPayload(
        playerId: id,
        timestamp: DateTime.now(),
        acceleration: MotionAccelerationPayload(
          x: _x,
          y: _y,
          z: _z,
          magnitude: _magnitude,
          smoothedMagnitude: _smoothedMagnitude,
        ),
        session: MotionSessionPayload(
          score: _sessionScore,
          isTracking: isTracking,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sampleTimer?.cancel();
    super.dispose();
  }
}
