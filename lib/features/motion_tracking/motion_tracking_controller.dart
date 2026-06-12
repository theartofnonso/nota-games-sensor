import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'motion_payload.dart';
import 'motion_player_id_store.dart';
import 'motion_publisher.dart';

/// Device sample interval — 50 ms → 20 Hz batches per schema.
const Duration kMotionSampleInterval = Duration(milliseconds: 50);
const double kMotionSampleRateHz = 20;

/// How often raw samples are batched and posted to the backend.
const Duration kMotionBatchInterval = Duration(seconds: 1);

class MotionTrackingController extends ChangeNotifier {
  MotionTrackingController();

  String? _playerId;
  String _playerName = 'Player';
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  Timer? _sampleTimer;
  Timer? _batchTimer;
  bool _hasPendingSample = false;
  double _pendingX = 0;
  double _pendingY = 0;
  double _pendingZ = 0;
  String? _sensorError;
  bool _isRunning = false;

  final List<PlayerMotionSample> _batchSamples = [];
  int? _batchStartedAtMs;

  String get playerId => _playerId ?? '…';
  String get playerName => _playerName;
  String? get sensorError => _sensorError;
  bool get isRunning => _isRunning;

  Future<void> initialize() async {
    _playerId = await MotionPlayerIdStore.loadOrCreate();
    _playerName = await MotionPlayerIdStore.loadOrCreateName();
    notifyListeners();
    await _startSensor();
  }

  Future<void> _startSensor() async {
    if (_isRunning) return;
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
          _stopSensor();
        },
      );

      _sampleTimer = Timer.periodic(
        kMotionSampleInterval,
        (_) => _onSampleTick(),
      );
      _batchTimer = Timer.periodic(
        kMotionBatchInterval,
        (_) => _flushBatch(),
      );

      _isRunning = true;
      notifyListeners();
    } catch (e) {
      _sensorError = 'Could not start motion sensor: $e';
      await _tearDownSensor();
      notifyListeners();
    }
  }

  void _stopSensor() {
    _flushBatch();
    _tearDownSensor();
    _isRunning = false;
    notifyListeners();
  }

  Future<void> _tearDownSensor() async {
    await _subscription?.cancel();
    _subscription = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _hasPendingSample = false;
    _batchSamples.clear();
    _batchStartedAtMs = null;
  }

  void _onSampleTick() {
    if (!_hasPendingSample || !_isRunning) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _batchStartedAtMs ??= timestamp;

    _batchSamples.add(
      PlayerMotionSample(
        timestamp: timestamp,
        x: _pendingX,
        y: _pendingY,
        z: _pendingZ,
      ),
    );
  }

  void _flushBatch() {
    final id = _playerId;
    if (id == null || _batchSamples.isEmpty) {
      _batchSamples.clear();
      _batchStartedAtMs = null;
      return;
    }

    final batchStartedAt = _batchStartedAtMs ?? _batchSamples.first.timestamp;
    final batchEndedAt = DateTime.now().millisecondsSinceEpoch;

    MotionPublisher.publishMotionBatch(
      PlayerMotionBatch(
        playerId: id,
        playerName: _playerName,
        batchStartedAt: batchStartedAt,
        batchEndedAt: batchEndedAt,
        sampleRateHz: kMotionSampleRateHz,
        samples: List<PlayerMotionSample>.from(_batchSamples),
      ),
    );

    _batchSamples.clear();
    _batchStartedAtMs = null;
  }

  @override
  void dispose() {
    _flushBatch();
    _subscription?.cancel();
    _sampleTimer?.cancel();
    _batchTimer?.cancel();
    super.dispose();
  }
}
